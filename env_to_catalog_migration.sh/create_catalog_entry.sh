#!/bin/bash

# Script to create a catalog entry
# Usage: ./create_catalog_entry.sh <API_ENDPOINT> <API_TOKEN> <APP_NAME> <GIT_REPO> <GIT_BRANCH> <GIT_PATH>

set -e

# Check if required parameters are provided
if [ "$#" -lt 4 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <APP_NAME> <GIT_REPO> [GIT_BRANCH] [GIT_PATH]"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"my-app\" \"https://github.com/org/repo.git\" \"main\" \"path/to/manifests\""
    exit 1
fi

API_ENDPOINT=$1
API_TOKEN=$2
APP_NAME=$3
GIT_REPO=$4
GIT_BRANCH=${5:-"main"}  # Default to "main" if not provided
GIT_PATH=${6:-""}         # Default to empty if not provided

echo "Creating catalog entry for application: $APP_NAME"

# Create a unique catalog name based on the application name
CATALOG_NAME="${APP_NAME}-catalog"

echo "Catalog Name: $CATALOG_NAME"
echo "Git Repository: $GIT_REPO"
echo "Git Branch: $GIT_BRANCH"
echo "Git Path: $GIT_PATH"

# Create the catalog entry
CATALOG_PAYLOAD=$(jq -n \
    --arg name "$CATALOG_NAME" \
    --arg repo "$GIT_REPO" \
    --arg branch "$GIT_BRANCH" \
    --arg path "$GIT_PATH" \
    '{
        "name": $name,
        "description": "Migrated from environment-based application",
        "gitRepository": {
            "url": $repo,
            "branch": $branch,
            "path": $path
        }
    }')

echo "Creating catalog entry with payload:"
echo "$CATALOG_PAYLOAD" | jq '.'

CATALOG_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/catalog/api/catalogEntries" \
    -H "Authorization: NIRMATA-API $API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CATALOG_PAYLOAD")

CATALOG_ID=$(echo "$CATALOG_RESPONSE" | jq -r '.id')

if [ -z "$CATALOG_ID" ] || [ "$CATALOG_ID" = "null" ]; then
    echo "Error: Failed to create catalog entry for $APP_NAME"
    echo "Response: $CATALOG_RESPONSE"
    exit 1
fi

echo "Catalog entry created successfully with ID: $CATALOG_ID"
echo "Catalog entry details:"
echo "$CATALOG_RESPONSE" | jq '.' 