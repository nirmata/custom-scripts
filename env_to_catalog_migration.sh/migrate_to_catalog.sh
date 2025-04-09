#!/bin/bash

# Script to migrate environment-based applications to catalog-based deployments
# Usage: ./migrate_to_catalog.sh <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME> <ENVIRONMENT_NAME>

set -e

# Check if required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME> <ENVIRONMENT_NAME>"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"129-app-migration\" \"new-migration\""
    exit 1
fi

API_ENDPOINT=$1
API_TOKEN=$2
CLUSTER_NAME=$3
ENVIRONMENT_NAME=$4

echo "Starting migration of environment-based applications to catalog for environment: $ENVIRONMENT_NAME in cluster: $CLUSTER_NAME"

# Function to get cluster ID by name
get_cluster_id() {
    local cluster_name=$1
    local cluster_id=$(curl -s -X GET "$API_ENDPOINT/clusters/api/clusters" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json" | jq -r --arg name "$cluster_name" '.[] | select(.name == $name) | .id')
    
    if [ -z "$cluster_id" ] || [ "$cluster_id" = "null" ]; then
        echo "Error: Cluster '$cluster_name' not found"
        exit 1
    fi
    
    echo "$cluster_id"
}

# Function to get environment ID by name
get_environment_id() {
    local cluster_id=$1
    local env_name=$2
    local env_id=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json" | jq -r --arg cluster "$cluster_id" --arg name "$env_name" '.[] | select(.cluster.id == $cluster and .name == $name) | .id')
    
    if [ -z "$env_id" ] || [ "$env_id" = "null" ]; then
        echo "Error: Environment '$env_name' not found in cluster"
        exit 1
    fi
    
    echo "$env_id"
}

# Function to get applications in an environment
get_environment_applications() {
    local env_id=$1
    local apps=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments/$env_id/applications" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json")
    
    echo "$apps"
}

# Function to create a catalog entry
create_catalog_entry() {
    local app_name=$1
    local git_repo=$2
    local git_branch=$3
    local git_path=$4
    
    # Create a unique catalog name based on the application name
    local catalog_name="${app_name}-catalog"
    
    echo "Creating catalog entry: $catalog_name"
    
    # Create the catalog entry
    local catalog_payload=$(jq -n \
        --arg name "$catalog_name" \
        --arg repo "$git_repo" \
        --arg branch "$git_branch" \
        --arg path "$git_path" \
        '{
            "name": $name,
            "description": "Migrated from environment-based application",
            "gitRepository": {
                "url": $repo,
                "branch": $branch,
                "path": $path
            }
        }')
    
    local catalog_response=$(curl -s -X POST "$API_ENDPOINT/catalog/api/catalogEntries" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$catalog_payload")
    
    local catalog_id=$(echo "$catalog_response" | jq -r '.id')
    
    if [ -z "$catalog_id" ] || [ "$catalog_id" = "null" ]; then
        echo "Error: Failed to create catalog entry for $app_name"
        echo "Response: $catalog_response"
        return 1
    fi
    
    echo "$catalog_id"
}

# Function to deploy application from catalog
deploy_from_catalog() {
    local env_id=$1
    local catalog_id=$2
    local app_name=$3
    
    echo "Deploying $app_name from catalog to environment"
    
    local deploy_payload=$(jq -n \
        --arg env_id "$env_id" \
        --arg catalog_id "$catalog_id" \
        --arg name "$app_name" \
        '{
            "environmentId": $env_id,
            "catalogEntryId": $catalog_id,
            "name": $name
        }')
    
    local deploy_response=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$env_id/applications" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Content-Type: application/json" \
        -d "$deploy_payload")
    
    local deploy_id=$(echo "$deploy_response" | jq -r '.id')
    
    if [ -z "$deploy_id" ] || [ "$deploy_id" = "null" ]; then
        echo "Error: Failed to deploy application $app_name"
        echo "Response: $deploy_response"
        return 1
    fi
    
    echo "Successfully deployed $app_name with ID: $deploy_id"
    return 0
}

# Main migration process
echo "Getting cluster ID for $CLUSTER_NAME..."
CLUSTER_ID=$(get_cluster_id "$CLUSTER_NAME")
echo "Cluster ID: $CLUSTER_ID"

echo "Getting environment ID for $ENVIRONMENT_NAME..."
ENV_ID=$(get_environment_id "$CLUSTER_ID" "$ENVIRONMENT_NAME")
echo "Environment ID: $ENV_ID"

echo "Getting applications in environment..."
APPS=$(get_environment_applications "$ENV_ID")
APP_COUNT=$(echo "$APPS" | jq '. | length')

if [ "$APP_COUNT" -eq 0 ]; then
    echo "No applications found in environment $ENVIRONMENT_NAME"
    exit 0
fi

echo "Found $APP_COUNT applications to migrate"

# Process each application
echo "$APPS" | jq -c '.[]' | while read -r app; do
    APP_NAME=$(echo "$app" | jq -r '.name')
    APP_ID=$(echo "$app" | jq -r '.id')
    
    echo "Processing application: $APP_NAME (ID: $APP_ID)"
    
    # Get application details
    APP_DETAILS=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments/$ENV_ID/applications/$APP_ID" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
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
    CATALOG_ID=$(create_catalog_entry "$APP_NAME" "$GIT_REPO" "$GIT_BRANCH" "$GIT_PATH")
    
    if [ -z "$CATALOG_ID" ]; then
        echo "Failed to create catalog entry for $APP_NAME, skipping deployment"
        continue
    fi
    
    echo "Catalog entry created with ID: $CATALOG_ID"
    
    # Deploy from catalog
    echo "Deploying $APP_NAME from catalog..."
    deploy_from_catalog "$ENV_ID" "$CATALOG_ID" "$APP_NAME"
    
    echo "Migration completed for $APP_NAME"
    echo "-----------------------------------"
done

echo "Migration process completed" 