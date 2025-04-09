#!/bin/bash

# Script to get detailed information about an application
# Usage: ./get_app_details.sh <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <APPLICATION_ID>

set -e

# Check if required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <APPLICATION_ID>"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"env-id-123\" \"app-id-456\""
    exit 1
fi

API_ENDPOINT=$1
API_TOKEN=$2
ENV_ID=$3
APP_ID=$4

echo "Getting details for application ID: $APP_ID in environment ID: $ENV_ID"

# Get application details
APP_DETAILS=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments/$ENV_ID/applications/$APP_ID" \
    -H "Authorization: NIRMATA-API $API_TOKEN" \
    -H "Accept: application/json")

# Extract basic information
APP_NAME=$(echo "$APP_DETAILS" | jq -r '.name // empty')
echo "Application Name: $APP_NAME"

# Extract Git repository details
GIT_REPO=$(echo "$APP_DETAILS" | jq -r '.gitRepository.url // empty')
GIT_BRANCH=$(echo "$APP_DETAILS" | jq -r '.gitRepository.branch // empty')
GIT_PATH=$(echo "$APP_DETAILS" | jq -r '.gitRepository.path // empty')

echo "Git Repository: $GIT_REPO"
echo "Git Branch: $GIT_BRANCH"
echo "Git Path: $GIT_PATH"

# Save application details to a file
echo "$APP_DETAILS" > "${APP_NAME}_details.json"
echo "Application details saved to ${APP_NAME}_details.json"

# Print a summary of the application
echo "-----------------------------------"
echo "Application Summary:"
echo "Name: $APP_NAME"
echo "ID: $APP_ID"
echo "Git Repository: $GIT_REPO"
echo "Git Branch: $GIT_BRANCH"
echo "Git Path: $GIT_PATH"
echo "-----------------------------------" 