#!/bin/bash

# Script to copy permissions from one environment to another
# Usage: ./copy_permissions.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_ENV> <DEST_ENV>

set -e

# Check if required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <SOURCE_ENV> <DEST_ENV>"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"source-env\" \"dest-env\""
    exit 1
fi

API_ENDPOINT=$1
API_TOKEN=$2
SOURCE_ENV=$3
DEST_ENV=$4

echo "Copying permissions from $SOURCE_ENV to $DEST_ENV..."

# Get source environment details
echo "Getting source environment details..."
SOURCE_ENV_RESPONSE=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Accept: application/json")

SOURCE_ENV_ID=$(echo "$SOURCE_ENV_RESPONSE" | jq -r --arg env "$SOURCE_ENV" '.[] | select(.name == $env) | .id')
if [ -z "$SOURCE_ENV_ID" ] || [ "$SOURCE_ENV_ID" = "null" ]; then
    echo "Error: Could not find source environment $SOURCE_ENV"
    echo "Available environments:"
    echo "$SOURCE_ENV_RESPONSE" | jq -r '.[].name'
    exit 1
fi

# Get destination environment details
echo "Getting destination environment details..."
DEST_ENV_RESPONSE=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Accept: application/json")

DEST_ENV_ID=$(echo "$DEST_ENV_RESPONSE" | jq -r --arg env "$DEST_ENV" '.[] | select(.name == $env) | .id')
if [ -z "$DEST_ENV_ID" ] || [ "$DEST_ENV_ID" = "null" ]; then
    echo "Error: Could not find destination environment $DEST_ENV"
    echo "Available environments:"
    echo "$DEST_ENV_RESPONSE" | jq -r '.[].name'
    exit 1
fi

echo "Source Environment ID: $SOURCE_ENV_ID"
echo "Destination Environment ID: $DEST_ENV_ID"

# Get source ACL details
echo "Getting source ACL details..."
SOURCE_ACL_ID=$(echo "$SOURCE_ENV_RESPONSE" | jq -r --arg env "$SOURCE_ENV" '.[] | select(.name == $env) | .accessControlList[0].id')
if [ -z "$SOURCE_ACL_ID" ] || [ "$SOURCE_ACL_ID" = "null" ]; then
    echo "Error: Could not find source ACL ID"
    exit 1
fi

SOURCE_ACL=$(curl -s -X GET "$API_ENDPOINT/environments/api/accessControlLists/$SOURCE_ACL_ID" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "Accept: application/json")

echo "Source ACL details:"
echo "$SOURCE_ACL" | jq '.'

# Get destination ACL details
echo "Getting destination ACL details..."
DEST_ACL_ID=$(echo "$DEST_ENV_RESPONSE" | jq -r --arg env "$DEST_ENV" '.[] | select(.name == $env) | .accessControlList[0].id')
if [ -z "$DEST_ACL_ID" ] || [ "$DEST_ACL_ID" = "null" ]; then
    echo "Error: Could not find destination ACL ID"
    exit 1
fi

# Copy each access control
echo "Copying access controls..."
echo "$SOURCE_ACL" | jq -c '.accessControls[]?' | while read -r control; do
    if [ -z "$control" ] || [ "$control" = "null" ]; then
        continue
    fi
    
    echo "Processing control: $control"
    
    # Extract values
    TEAM_ID=$(echo "$control" | jq -r '.entityId // empty')
    TEAM_NAME=$(echo "$control" | jq -r '.entityName // empty')
    PERMISSION=$(echo "$control" | jq -r '.permission // empty')
    
    if [ -z "$TEAM_ID" ] || [ -z "$PERMISSION" ]; then
        echo "Warning: Skipping invalid control entry (missing team ID or permission)"
        continue
    fi
    
    echo "Setting permission for team $TEAM_NAME ($TEAM_ID): $PERMISSION"
    
    # Create JSON payload
    PAYLOAD=$(jq -n \
        --arg team_id "$TEAM_ID" \
        --arg team_name "$TEAM_NAME" \
        --arg perm "$PERMISSION" \
        '{
            "entityId": $team_id,
            "entityType": "team",
            "permission": $perm,
            "entityName": $team_name
        }')
    
    echo "Sending payload: $PAYLOAD"
    
    # Set permission
    RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/accessControlLists/$DEST_ACL_ID/accessControls" \
        -H "Authorization: Bearer $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$PAYLOAD")
    
    if ! echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response from API"
        echo "Response: $RESPONSE"
    else
        echo "Successfully set permission for team $TEAM_NAME"
    fi
done

echo "Permissions copied successfully from $SOURCE_ENV to $DEST_ENV!" 