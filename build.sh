# Create time stamp
TAG=deploy-`date "+%Y-%m-%d-%HT%M-%S"`

# Step 1. Authenticate to Astronomer's Docker registry with your Deployment API key ID and secret. This is equivalent to running `$ astrocloud auth login` via the Astro CLI.
docker login images.astronomer.cloud -u $ASTRONOMER_KEY_ID -p $ASTRONOMER_KEY_SECRET

# Step 2. Build your Astronomer project into a tagged Docker image.
docker build . -t images.astronomer.cloud/$ORGANIZATION_ID/$DEPLOYMENT_ID:$TAG

# Step 3. Push that Docker image to Astronomer's Docker registry.
docker push images.astronomer.cloud/$ORGANIZATION_ID/$DEPLOYMENT_ID:$TAG

# Step 4. Fetch an API access token with your Deployment API key ID and secret.
echo "get token"
TOKEN=$( curl --location --request POST "https://auth.astronomer.io/oauth/token" \
        --header "content-type: application/json" \
        --data-raw "{
            \"client_id\": \"$ASTRONOMER_KEY_ID\",
            \"client_secret\": \"$ASTRONOMER_KEY_SECRET\",
            \"audience\": \"astronomer-ee\",
            \"grant_type\": \"client_credentials\"}" | jq -r '.access_token' )
# Step 5. Make a request to the Astronomer API that passes metadata from your new Docker image and creates a record for it.
echo "get image id"
IMAGE=$( curl --location --request POST "https://api.astronomer.io/hub/v1" \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data-raw "{
            \"query\" : \"mutation imageCreate(\n    \$input: ImageCreateInput!\n) {\n    imageCreate (\n    input: \$input\n) {\n    id\n    tag\n    repository\n    digest\n    env\n    labels\n    deploymentId\n  }\n}\",
            \"variables\" : {
                \"input\" : {
                    \"deploymentId\" : \"$DEPLOYMENT_ID\",
                    \"tag\" : \"$TAG\"
                    }
                }
            }" | jq -r '.data.imageCreate.id')

# Step 6. Pass the repository URL for the Docker image to your Astronomer Deployment. This completes the deploy process and triggers your Scheduler and Workers to restart.
echo "deploy image"
curl --location --request POST "https://api.astronomer.io/hub/v1" \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data-raw "{
            \"query\" : \"mutation imageDeploy(\n    \$input: ImageDeployInput!\n  ) {\n    imageDeploy(\n      input: \$input\n    ) {\n      id\n      deploymentId\n      digest\n      env\n      labels\n      name\n      tag\n      repository\n    }\n}\",
            \"variables\" : {
                \"input\" : {
                    \"id\" : \"$IMAGE\",
                    \"tag\" : \"$TAG\",
                    \"repository\" : \"images.astronomer.cloud/$ORGANIZATION_ID/$DEPLOYMENT_ID\"
                    }
                }
            }"
