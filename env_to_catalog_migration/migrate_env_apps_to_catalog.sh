#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <api_endpoint> <token> <source_env> <cluster_name>"
    exit 1
fi

API_ENDPOINT=$1
TOKEN=$2
SOURCE_ENV=$3
CLUSTER_NAME=$4

# Remove cluster suffix from environment name to get catalog name
CATALOG_NAME=$(echo "$SOURCE_ENV" | sed "s/-${CLUSTER_NAME}$//")

# After the initial configuration section, add logging setup
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG_FILE="custom-scripts/env_to_catalog_migration/migration_logs/migration_${TIMESTAMP}.log"

# Function to log messages to both console and file
log_message() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Initialize log file with header
cat > "$LOG_FILE" <<EOF
=== Migration Report ===
Date: $(date)
Source Environment: $SOURCE_ENV
Target Catalog: $CATALOG_NAME
API Endpoint: $API_ENDPOINT

Migration Details:
=====================================
EOF

echo "=== Migration Configuration ==="
echo "API Endpoint: $API_ENDPOINT"
echo "Source Environment: $SOURCE_ENV"
echo "Target Catalog Name: $CATALOG_NAME"
echo "Cluster Name: $CLUSTER_NAME"
echo "==========================="

# Function to get environment details
get_env_details() {
    local env_name=$1
    local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name" | jq -r ".[] | select(.name == \"$env_name\")")
    if [ -z "$response" ]; then
        echo "Error: Environment $env_name not found"
        exit 2
    fi
    echo "$response"
}

# Function to check if catalog exists
check_catalog_exists() {
    local catalog_name=$1
    local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/catalogs?fields=id,name" | jq -r ".[] | select(.name == \"$catalog_name\") | .id")
    if [ ! -z "$response" ]; then
        echo "$response"
    fi
}

# Function to create a new catalog
create_catalog() {
    local catalog_name=$1
    local payload="{\"name\":\"$catalog_name\",\"modelIndex\":\"Catalog\",\"description\":\"Migrated from environment $SOURCE_ENV\"}"
    echo "Creating catalog with payload: $payload"
    local response=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$payload" "$API_ENDPOINT/catalog/api/catalogs")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create catalog. Response: $response"
        exit 3
    fi
    echo "$response" | jq -r '.id'
}

# Get source environment details
echo "Getting source environment details..."
ENV_DETAILS=$(get_env_details "$SOURCE_ENV")
ENV_ID=$(echo "$ENV_DETAILS" | jq -r '.id')
echo "Found source environment ID: $ENV_ID"

# Get applications from source environment
echo "Getting applications from source environment..."
APPS_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments/$ENV_ID/applications?fields=id,name,gitUpstream,yamlData")
if [ $? -ne 0 ]; then
    echo "Error: Failed to get applications. Response: $APPS_RESPONSE"
    exit 4
fi

# Get or create catalog
CATALOG_ID=$(check_catalog_exists "$CATALOG_NAME")
if [ -z "$CATALOG_ID" ]; then
    echo "Creating new catalog '$CATALOG_NAME'..."
    CATALOG_ID=$(create_catalog "$CATALOG_NAME")
fi

echo "Using catalog ID: $CATALOG_ID"

# Add counters before processing applications
processed_count=0
success_count=0
skip_count=0
fail_count=0

# Process each application
echo "$APPS_RESPONSE" | jq -c '.[]' | while read -r app; do
    processed_count=$((processed_count + 1))
    
    APP_NAME=$(echo "$app" | jq -r '.name')
    APP_ID=$(echo "$app" | jq -r '.id')
    log_message "Processing application: $APP_NAME"
    
    # Get detailed application info
    APP_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/applications/$APP_ID")
    
    # Check if it's a Git-based application
    if ! echo "$APP_DETAILS" | jq -e '.gitUpstream[0].id' > /dev/null; then
        log_message "⚠ Skipping $APP_NAME - Not a Git-based application"
        skip_count=$((skip_count + 1))
        continue
    fi

    GIT_UPSTREAM_ID=$(echo "$APP_DETAILS" | jq -r '.gitUpstream[0].id')
    echo "Detected Git-based application with upstream ID: $GIT_UPSTREAM_ID"
    
    UNIQUE_APP_NAME="${APP_NAME}-${CLUSTER_NAME}"
    echo "Will create as: $UNIQUE_APP_NAME"
    
    # Create base application in catalog
    APP_PAYLOAD=$(cat <<EOF
{
    "name": "$UNIQUE_APP_NAME",
    "modelIndex": "Application",
    "parent": {
        "id": "$CATALOG_ID",
        "service": "Catalog",
        "modelIndex": "Catalog",
        "childRelation": "applications"
    },
    "catalog": "$CATALOG_ID",
    "description": "Migrated from environment $SOURCE_ENV",
    "upstreamType": "git",
    "namespace": ""
}
EOF
)
    
    echo "Creating application with payload: $APP_PAYLOAD"
    APP_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$APP_PAYLOAD" "$API_ENDPOINT/catalog/api/applications")
    echo "Application creation response: $APP_RESPONSE"
    
    NEW_APP_ID=$(echo "$APP_RESPONSE" | jq -r '.id')
    if [ -z "$NEW_APP_ID" ] || [ "$NEW_APP_ID" = "null" ]; then
        echo "Error: Failed to get new application ID for $UNIQUE_APP_NAME"
        continue
    fi
    
    echo "Created new application with ID: $NEW_APP_ID"
    
    # Get Git upstream details
    GIT_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/gitupstreams/$GIT_UPSTREAM_ID")
    
    # Extract Git configuration
    GIT_URL=$(echo "$GIT_DETAILS" | jq -r '.repository')
    GIT_BRANCH=$(echo "$GIT_DETAILS" | jq -r '.branch')
    GIT_PATH=$(echo "$GIT_DETAILS" | jq -r '.directoryList[0]')
    
    echo "Git Details:"
    echo "  Repository: $GIT_URL"
    echo "  Branch: $GIT_BRANCH"
    echo "  Path: $GIT_PATH"
    
    # Create GitUpstream for the application
    GIT_PAYLOAD=$(cat <<EOF
{
    "modelIndex": "GitUpstream",
    "parent": {
        "id": "$NEW_APP_ID",
        "service": "Catalog",
        "modelIndex": "Application",
        "childRelation": "gitUpstream"
    },
    "repository": "$GIT_URL",
    "branch": "$GIT_BRANCH",
    "path": "$GIT_PATH",
    "includeList": ["*.yaml", "*.yml"],
    "application": "$NEW_APP_ID"
}
EOF
)
    
    echo "Creating GitUpstream with payload: $GIT_PAYLOAD"
    GIT_RESPONSE=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$GIT_PAYLOAD" "$API_ENDPOINT/catalog/api/applications/$NEW_APP_ID/gitUpstream")
    echo "GitUpstream creation response: $GIT_RESPONSE"

    # After successful creation of application and GitUpstream
    if [ $? -eq 0 ]; then
        success_count=$((success_count + 1))
        log_message "✓ Successfully migrated Git-based application $APP_NAME to $UNIQUE_APP_NAME"
    else
        fail_count=$((fail_count + 1))
        log_message "✗ Failed to migrate application $APP_NAME"
    fi
    
    log_message "----------------------------------------"
done

log_message "\nMigration Summary:"
log_message "=================="
log_message "Total applications processed: $((processed_count))"
log_message "Successfully migrated: $((success_count))"
log_message "Skipped (non-Git): $((skip_count))"
log_message "Failed: $((fail_count))"
log_message "\nLog file created at: $LOG_FILE"

echo "Migration process completed."
