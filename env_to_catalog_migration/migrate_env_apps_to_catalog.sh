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

# Change logging setup to use cluster name instead of timestamp
LOG_FILE="custom-scripts/env_to_catalog_migration/migration_logs/migration_${CLUSTER_NAME}.log"

# Function to log messages to both console and file
log_message() {
    echo "$1"
    echo "$1" >> "$LOG_FILE"
}

# Function to check if application exists
check_application_exists() {
    local app_name=$1
    local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/applications?fields=id,name" | jq -r ".[] | select(.name == \"$app_name\")")
    echo "$response"
}

# Initialize log file with header
cat > "$LOG_FILE" <<EOF
=== Migration Report ===
Date: $(date)
Source Environment: $SOURCE_ENV
Target Catalog: $CATALOG_NAME
API Endpoint: $API_ENDPOINT
Cluster: $CLUSTER_NAME

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
    log_message "\nProcessing application: $APP_NAME"
    
    # Get detailed application info
    APP_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/applications/$APP_ID")
    
    # Check if it's a Git-based application
    if ! echo "$APP_DETAILS" | jq -e '.gitUpstream[0].id' > /dev/null; then
        log_message "⚠ Skipping $APP_NAME - Not a Git-based application"
        skip_count=$((skip_count + 1))
        continue
    fi

    GIT_UPSTREAM_ID=$(echo "$APP_DETAILS" | jq -r '.gitUpstream[0].id')
    log_message "✓ Detected Git-based application with upstream ID: $GIT_UPSTREAM_ID"
    
    # Create name for the application using cluster name
    UNIQUE_APP_NAME="${APP_NAME}-${CLUSTER_NAME}"
    
    # Check if application already exists
    EXISTING_APP=$(check_application_exists "$UNIQUE_APP_NAME")
    if [ ! -z "$EXISTING_APP" ]; then
        EXISTING_APP_ID=$(echo "$EXISTING_APP" | jq -r '.id')
        log_message "⚠ Application $UNIQUE_APP_NAME already exists with ID: $EXISTING_APP_ID"
        log_message "  Skipping creation to avoid conflicts"
        skip_count=$((skip_count + 1))
        continue
    fi
    
    log_message "\nMigrating application:"
    log_message "===================="
    log_message "Source:"
    log_message "  - Environment: $SOURCE_ENV"
    log_message "  - Application: $APP_NAME"
    log_message "  - Git Upstream ID: $GIT_UPSTREAM_ID"
    log_message "\nTarget:"
    log_message "  - Catalog: $CATALOG_NAME"
    log_message "  - New Name: $UNIQUE_APP_NAME"
    
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
    "description": "Migrated from environment $SOURCE_ENV (Original: $APP_NAME)",
    "upstreamType": "git",
    "namespace": ""
}
EOF
)
    
    log_message "Creating application with payload: $APP_PAYLOAD"
    APP_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$APP_PAYLOAD" "$API_ENDPOINT/catalog/api/applications")
    
    # Check for application creation errors
    if echo "$APP_RESPONSE" | jq -e '.errors' > /dev/null; then
        ERROR_MSG=$(echo "$APP_RESPONSE" | jq -r '.message')
        log_message "✗ Failed to create application: $ERROR_MSG"
        fail_count=$((fail_count + 1))
        continue
    fi
    
    NEW_APP_ID=$(echo "$APP_RESPONSE" | jq -r '.id')
    if [ -z "$NEW_APP_ID" ] || [ "$NEW_APP_ID" = "null" ]; then
        log_message "✗ Failed to get new application ID for $UNIQUE_APP_NAME"
        fail_count=$((fail_count + 1))
        continue
    fi
    
    log_message "✓ Created new application with ID: $NEW_APP_ID"
    
    # Get Git upstream details with error handling
    GIT_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/gitupstreams/$GIT_UPSTREAM_ID")
    if [ $? -ne 0 ] || [ -z "$GIT_DETAILS" ]; then
        log_message "✗ Failed to get Git upstream details"
        fail_count=$((fail_count + 1))
        continue
    fi
    
    # Extract Git details
    REPO_URL=$(echo "$GIT_DETAILS" | jq -r '.repository')
    BRANCH=$(echo "$GIT_DETAILS" | jq -r '.branch')
    PATH_VALUE=$(echo "$GIT_DETAILS" | jq -r '.path')
    
    log_message "Git Details:"
    log_message "  Repository: $REPO_URL"
    log_message "  Branch: $BRANCH"
    log_message "  Path: $PATH_VALUE"
    
    # Create GitUpstream with error handling
    GIT_UPSTREAM_PAYLOAD=$(cat <<EOF
{
    "modelIndex": "GitUpstream",
    "parent": {
        "id": "$NEW_APP_ID",
        "service": "Catalog",
        "modelIndex": "Application",
        "childRelation": "gitUpstream"
    },
    "repository": "$REPO_URL",
    "branch": "$BRANCH",
    "path": "$PATH_VALUE",
    "includeList": ["*.yaml", "*.yml"],
    "application": "$NEW_APP_ID"
}
EOF
)
    
    log_message "Creating GitUpstream with payload: $GIT_UPSTREAM_PAYLOAD"
    GIT_UPSTREAM_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$GIT_UPSTREAM_PAYLOAD" "$API_ENDPOINT/catalog/api/gitupstreams")
    
    log_message "\nMigration Result: ✓ SUCCESS"
    log_message "  - New Application ID: $NEW_APP_ID"
    log_message "  - Git Repository: $REPO_URL"
    log_message "  - Branch: $BRANCH"
    log_message "  - Path: $PATH_VALUE"
    
    log_message "\n----------------------------------------\n"
done

# Update summary with more details
log_message "\nMigration Summary:"
log_message "=================="
log_message "Environment: $SOURCE_ENV -> Catalog: $CATALOG_NAME"
log_message "Total applications processed: $((processed_count))"
log_message "Successfully migrated: $((success_count))"
log_message "Skipped applications: $((skip_count))"
log_message "Failed migrations: $((fail_count))"
log_message "\nLog file: $LOG_FILE"

echo "Migration process completed. Check $LOG_FILE for detailed report."
