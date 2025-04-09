#!/bin/bash

# Script to copy settings from a required copied environment to a catalog base app
# Usage: ./copy_to_catalog.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_ENV> <DEST_ENV>

set -e

# Enable debug mode
set -x

# Check if required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <api-endpoint> <token> <source-env> <destination-env>"
    echo "Example: $0 https://pe420.nirmata.co \"token\" \"new-migration\" \"129-app-migration\""
    exit 1
fi

API_ENDPOINT=$1
# Remove any newlines from the token
TOKEN=$(echo "$2" | tr -d '\n')
SOURCE_ENV=$3
DEST_ENV=$4

# Function to create environment if it doesn't exist
create_environment() {
    local ENV_NAME=$1
    local NAMESPACE=$2
    local CLUSTER_ID=$3

    # Check if environment exists
    local ENV_CHECK=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments" | jq -r ".[] | select(.name == \"$ENV_NAME\")")
    
    if [ -z "$ENV_CHECK" ]; then
        echo "Creating environment $ENV_NAME..."
        curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "{\"name\":\"$ENV_NAME\",\"namespace\":\"$NAMESPACE\",\"cluster\":{\"id\":\"$CLUSTER_ID\"}}" \
            "$API_ENDPOINT/environments/api/environments"
    else
        echo "Environment $ENV_NAME already exists"
    fi
}

# Get source environment details
SOURCE_ENV_DETAILS=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments" | jq -r ".[] | select(.name == \"$SOURCE_ENV\")")

if [ -z "$SOURCE_ENV_DETAILS" ]; then
    echo "Source environment $SOURCE_ENV not found"
    exit 1
fi

# Extract source environment ID and cluster ID
SOURCE_ENV_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.id')
SOURCE_CLUSTER_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.cluster[0].id')

if [ -z "$SOURCE_CLUSTER_ID" ]; then
    echo "Could not find cluster ID for source environment"
    exit 1
fi

# Create destination environment if it doesn't exist
create_environment "$DEST_ENV" "$DEST_ENV" "$SOURCE_CLUSTER_ID"

# Get destination environment details
DEST_ENV_DETAILS=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments" | jq -r ".[] | select(.name == \"$DEST_ENV\")")
DEST_ENV_ID=$(echo "$DEST_ENV_DETAILS" | jq -r '.id')

if [ -z "$DEST_ENV_ID" ]; then
    echo "Destination environment $DEST_ENV not found"
    exit 1
fi

# Copy access controls
echo "Copying access controls..."
ACCESS_CONTROLS=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/accessControlLists?environment.id=$SOURCE_ENV_ID")

if [ ! -z "$ACCESS_CONTROLS" ]; then
    # Delete existing access controls in destination
    DEST_ACLS=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/accessControlLists?environment.id=$DEST_ENV_ID")
    echo "$DEST_ACLS" | jq -r '.[] | .id' | while read -r acl_id; do
        curl -s -X DELETE -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/accessControlLists/$acl_id"
    done

    # Create new access controls
    echo "$ACCESS_CONTROLS" | jq -c '.[]' | while read -r acl; do
        NEW_ACL=$(echo "$acl" | jq ". + {\"environment\":{\"id\":\"$DEST_ENV_ID\"}}" | jq 'del(.id, .uri, .generation, .modifiedOn, .createdOn)')
        curl -s -X POST -H "Content-Type: application/json" -H "Authorization: NIRMATA-API $TOKEN" -d "$NEW_ACL" "$API_ENDPOINT/environments/api/accessControlLists"
    done
fi

# Copy resource quotas
echo "Copying resource quotas..."
RESOURCE_QUOTAS=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/resourceQuota?environment.id=$SOURCE_ENV_ID")

if [ ! -z "$RESOURCE_QUOTAS" ]; then
    # Delete existing quotas in destination
    DEST_QUOTAS=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/resourceQuota?environment.id=$DEST_ENV_ID")
    echo "$DEST_QUOTAS" | jq -r '.[] | .id' | while read -r quota_id; do
        curl -s -X DELETE -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/resourceQuota/$quota_id"
    done

    # Create new quotas
    echo "$RESOURCE_QUOTAS" | jq -c '.[]' | while read -r quota; do
        NEW_QUOTA=$(echo "$quota" | jq ". + {\"environment\":{\"id\":\"$DEST_ENV_ID\"}}" | jq 'del(.id, .uri, .generation, .modifiedOn, .createdOn)')
        curl -s -X POST -H "Content-Type: application/json" -H "Authorization: NIRMATA-API $TOKEN" -d "$NEW_QUOTA" "$API_ENDPOINT/environments/api/resourceQuota"
    done
fi

# Copy limit ranges
echo "Copying limit ranges..."
LIMIT_RANGES=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/limitRanges?environment.id=$SOURCE_ENV_ID")

if [ ! -z "$LIMIT_RANGES" ]; then
    # Delete existing ranges in destination
    DEST_RANGES=$(curl -s -H "Accept: application/json" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/limitRanges?environment.id=$DEST_ENV_ID")
    echo "$DEST_RANGES" | jq -r '.[] | .id' | while read -r range_id; do
        curl -s -X DELETE -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/limitRanges/$range_id"
    done

    # Create new ranges
    echo "$LIMIT_RANGES" | jq -c '.[]' | while read -r range; do
        NEW_RANGE=$(echo "$range" | jq ". + {\"environment\":{\"id\":\"$DEST_ENV_ID\"}}" | jq 'del(.id, .uri, .generation, .modifiedOn, .createdOn)')
        curl -s -X POST -H "Content-Type: application/json" -H "Authorization: NIRMATA-API $TOKEN" -d "$NEW_RANGE" "$API_ENDPOINT/environments/api/limitRanges"
    done
fi

echo "Settings copied successfully from $SOURCE_ENV to $DEST_ENV"

# 1. Copy Access Controls
echo -e "\nCopying Access Controls..."
SOURCE_ACL_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.accessControlList[0].id')
DEST_ACL_ID=$(echo "$DEST_ENV_DETAILS" | jq -r '.accessControlList[0].id')

echo "Source ACL ID: $SOURCE_ACL_ID"
echo "Destination ACL ID: $DEST_ACL_ID"

if [ "$SOURCE_ACL_ID" != "null" ] && [ ! -z "$SOURCE_ACL_ID" ]; then
    echo "Fetching source ACL details..."
    SOURCE_ACL=$(curl -s -X GET "$API_ENDPOINT/environments/api/accessControlLists/$SOURCE_ACL_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    if ! echo "$SOURCE_ACL" | jq -e . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response from ACL API"
        echo "Response: $SOURCE_ACL"
        exit 1
    fi
    
    echo "Source ACL details:"
    echo "$SOURCE_ACL" | jq '.'
    
    # Copy each access control
    echo "$SOURCE_ACL" | jq -c '.accessControls[]?' | while read -r control; do
        if [ -z "$control" ] || [ "$control" = "null" ]; then
            continue
        fi
        
        echo "Processing control: $control"
        
        # Extract values with proper JSON handling
        TEAM_ID=$(echo "$control" | jq -r '.entityId // empty')
        TEAM_NAME=$(echo "$control" | jq -r '.entityName // empty')
        PERMISSION=$(echo "$control" | jq -r '.permission // empty')
        
        if [ -z "$TEAM_ID" ] || [ -z "$PERMISSION" ]; then
            echo "Warning: Skipping invalid control entry (missing team ID or permission)"
            continue
        fi
        
        echo "Setting permission for team $TEAM_NAME ($TEAM_ID): $PERMISSION"
        
        # Create JSON payload properly
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
        
        RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/accessControlLists/$DEST_ACL_ID/accessControls" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$PAYLOAD")
        
        if ! echo "$RESPONSE" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response from API"
            echo "Response: $RESPONSE"
        else
            echo "Successfully set permission for team $TEAM_NAME"
        fi
    done
else
    echo "No source ACL found or ACL ID is null"
fi

# 2. Copy Resource Quotas
echo -e "\nCopying Resource Quotas..."
SOURCE_QUOTA_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.resourceQuota[0].id')
if [ "$SOURCE_QUOTA_ID" != "null" ] && [ ! -z "$SOURCE_QUOTA_ID" ]; then
    SOURCE_QUOTA=$(curl -s -X GET "$API_ENDPOINT/environments/api/resourceQuota/$SOURCE_QUOTA_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Get the quota spec details
    QUOTA_SPEC_ID=$(echo "$SOURCE_QUOTA" | jq -r '.spec[0].id')
    QUOTA_SPEC=$(curl -s -X GET "$API_ENDPOINT/environments/api/resourceQuotaSpecs/$QUOTA_SPEC_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Create new quota with proper structure
    echo "Creating resource quota..."
    QUOTA_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/resourceQuota" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"micro\",
            \"kind\": \"ResourceQuota\",
            \"apiVersion\": \"v1\",
            \"spec\": {
                \"hard\": $(echo "$QUOTA_SPEC" | jq '.hard')
            }
        }")
fi

# 3. Copy Limit Ranges
echo -e "\nCopying Limit Ranges..."
SOURCE_LIMIT_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.limitRange[0].id')
if [ "$SOURCE_LIMIT_ID" != "null" ] && [ ! -z "$SOURCE_LIMIT_ID" ]; then
    SOURCE_LIMIT=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRanges/$SOURCE_LIMIT_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Get the limit range spec details
    LIMIT_SPEC_ID=$(echo "$SOURCE_LIMIT" | jq -r '.spec[0].id')
    LIMIT_SPEC=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRangeSpecs/$LIMIT_SPEC_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Get the limit range items
    LIMIT_ITEM_ID=$(echo "$LIMIT_SPEC" | jq -r '.limits[0].id')
    LIMIT_ITEM=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRangeItems/$LIMIT_ITEM_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Create new limit range with proper structure
    echo "Creating limit range..."
    LIMIT_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/limitRange" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{
            \"name\": \"micro\",
            \"kind\": \"LimitRange\",
            \"apiVersion\": \"v1\",
            \"spec\": {
                \"limits\": [{
                    \"type\": \"Container\",
                    \"defaultLimit\": $(echo "$LIMIT_ITEM" | jq '.defaultLimit'),
                    \"defaultRequest\": $(echo "$LIMIT_ITEM" | jq '.defaultRequest')
                }]
            }
        }")
fi

# 4. Copy Update Policy
echo -e "\nCopying Update Policy..."
SOURCE_POLICY_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.updatePolicy[0].id')
if [ "$SOURCE_POLICY_ID" != "null" ] && [ ! -z "$SOURCE_POLICY_ID" ]; then
    SOURCE_POLICY=$(curl -s -X GET "$API_ENDPOINT/environments/api/updatePolicies/$SOURCE_POLICY_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    POLICY_SPEC=$(echo "$SOURCE_POLICY" | jq 'del(.id, .parent, .ancestors, .createdBy, .createdOn, .modifiedBy, .modifiedOn, .generation, .uri, .service, .modelIndex)')
    
    echo "Creating update policy..."
    curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/updatePolicy" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$POLICY_SPEC"
fi

# 5. Copy Labels
echo -e "\nCopying Labels..."
SOURCE_LABELS=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.labels')
if [ "$SOURCE_LABELS" != "null" ] && [ ! -z "$SOURCE_LABELS" ]; then
    echo "Updating labels..."
    curl -s -X PUT "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "{\"labels\":$SOURCE_LABELS}"
fi

# 6. Get applications in the source environment
echo -e "\nGetting applications in source environment..."
SOURCE_APPS=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments/$SOURCE_ENV_ID/applications" \
    -H "Authorization: NIRMATA-API $TOKEN" \
    -H "Accept: application/json")

APP_COUNT=$(echo "$SOURCE_APPS" | jq '. | length')

if [ "$APP_COUNT" -eq 0 ]; then
    echo "No applications found in source environment $SOURCE_ENV"
    echo "Settings copied successfully from $SOURCE_ENV to $DEST_ENV!"
    exit 0
fi

echo "Found $APP_COUNT applications to migrate to catalog"

# 7. Process each application
echo "$SOURCE_APPS" | jq -c '.[]' | while read -r app; do
    APP_NAME=$(echo "$app" | jq -r '.name')
    APP_ID=$(echo "$app" | jq -r '.id')
    
    echo "Processing application: $APP_NAME (ID: $APP_ID)"
    
    # Get application details
    APP_DETAILS=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments/$SOURCE_ENV_ID/applications/$APP_ID" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Extract Git repository details
    GIT_REPO=$(echo "$APP_DETAILS" | jq -r '.gitRepository.url // empty')
    GIT_BRANCH=$(echo "$APP_DETAILS" | jq -r '.gitRepository.branch // empty')
    GIT_PATH=$(echo "$APP_DETAILS" | jq -r '.gitRepository.path // empty')
    
    if [ -z "$GIT_REPO" ]; then
        echo "Warning: Application $APP_NAME does not have Git repository information, skipping"
        continue
    fi
    
    echo "Git Repository: $GIT_REPO"
    echo "Git Branch: $GIT_BRANCH"
    echo "Git Path: $GIT_PATH"
    
    # Create catalog entry
    echo "Creating catalog entry for $APP_NAME..."
    CATALOG_NAME="${APP_NAME}-catalog"
    
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
    
    CATALOG_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/catalog/api/catalogEntries" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$CATALOG_PAYLOAD")
    
    CATALOG_ID=$(echo "$CATALOG_RESPONSE" | jq -r '.id')
    
    if [ -z "$CATALOG_ID" ] || [ "$CATALOG_ID" = "null" ]; then
        echo "Error: Failed to create catalog entry for $APP_NAME"
        echo "Response: $CATALOG_RESPONSE"
        continue
    fi
    
    echo "Catalog entry created with ID: $CATALOG_ID"
    
    # Deploy from catalog
    echo "Deploying $APP_NAME from catalog..."
    DEPLOY_PAYLOAD=$(jq -n \
        --arg env_id "$DEST_ENV_ID" \
        --arg catalog_id "$CATALOG_ID" \
        --arg name "$APP_NAME" \
        '{
            "environmentId": $env_id,
            "catalogEntryId": $catalog_id,
            "name": $name
        }')
    
    DEPLOY_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/applications" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$DEPLOY_PAYLOAD")
    
    DEPLOY_ID=$(echo "$DEPLOY_RESPONSE" | jq -r '.id')
    
    if [ -z "$DEPLOY_ID" ] || [ "$DEPLOY_ID" = "null" ]; then
        echo "Error: Failed to deploy application $APP_NAME"
        echo "Response: $DEPLOY_RESPONSE"
        continue
    fi
    
    echo "Successfully deployed $APP_NAME with ID: $DEPLOY_ID"
    echo "-----------------------------------"
done

echo -e "\nSettings and applications copied successfully from $SOURCE_ENV to $DEST_ENV!" 