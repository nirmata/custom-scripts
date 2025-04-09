#!/bin/bash

# Script to deploy an application from the catalog
# Usage: ./deploy_from_catalog.sh <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <CATALOG_ID> <APP_NAME>

set -e

# Check if required parameters are provided
if [ "$#" -ne 5 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <CATALOG_ID> <APP_NAME>"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"env-id-123\" \"catalog-id-456\" \"my-app\""
    exit 1
fi

API_ENDPOINT=$1
API_TOKEN=$2
ENV_ID=$3
CATALOG_ID=$4
APP_NAME=$5

echo "Deploying application $APP_NAME from catalog $CATALOG_ID to environment $ENV_ID"

# Create the deployment payload
DEPLOY_PAYLOAD=$(jq -n \
    --arg env_id "$ENV_ID" \
    --arg catalog_id "$CATALOG_ID" \
    --arg name "$APP_NAME" \
    '{
        "environmentId": $env_id,
        "catalogEntryId": $catalog_id,
        "name": $name
    }')

echo "Deployment payload:"
echo "$DEPLOY_PAYLOAD" | jq '.'

# Deploy the application
DEPLOY_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$ENV_ID/applications" \
    -H "Authorization: NIRMATA-API $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$DEPLOY_PAYLOAD")

DEPLOY_ID=$(echo "$DEPLOY_RESPONSE" | jq -r '.id')

if [ -z "$DEPLOY_ID" ] || [ "$DEPLOY_ID" = "null" ]; then
    echo "Error: Failed to deploy application $APP_NAME"
    echo "Response: $DEPLOY_RESPONSE"
    exit 1
fi

echo "Application deployed successfully with ID: $DEPLOY_ID"
echo "Deployment details:"
echo "$DEPLOY_RESPONSE" | jq '.' 