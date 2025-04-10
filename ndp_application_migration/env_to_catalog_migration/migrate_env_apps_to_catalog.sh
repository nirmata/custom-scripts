#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <api_endpoint> <token> <source_cluster_name> <destination_cluster_name>"
    exit 1
fi

API_ENDPOINT=$1
TOKEN=$2
SOURCE_CLUSTER_NAME=$3
DEST_CLUSTER_NAME=$4

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

# Function to get git credential reference from source application
get_git_credential_reference() {
    local git_upstream_id=$1
    local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/gitupstreams/$git_upstream_id")
    
    # First try to get credential ID from the credential field
    local cred_id=$(echo "$response" | jq -r '.credential.id // empty')
    
    if [ -z "$cred_id" ] || [ "$cred_id" = "null" ]; then
        # Try getting from gitCredential field if credential didn't work
        cred_id=$(echo "$response" | jq -r '.gitCredential.id // empty')
    fi
    
    if [ ! -z "$cred_id" ] && [ "$cred_id" != "null" ]; then
        # Get the credential name using the ID
        local cred_details=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/gitcredentials/$cred_id")
        local cred_name=$(echo "$cred_details" | jq -r '.name // empty')
        if [ ! -z "$cred_name" ] && [ "$cred_name" != "null" ]; then
            echo "$cred_name"
        fi
    fi
}

# Function to get environment git credential name
get_environment_git_credential() {
    local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/gitcredentials")
    if [ ! -z "$response" ]; then
        # Get the first git credential name
        echo "$response" | jq -r '.[0].name // empty'
    fi
}

# Get cluster ID for source cluster name
echo "Getting cluster ID for: $SOURCE_CLUSTER_NAME"
SOURCE_CLUSTER_ID=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/clusters" | jq -r ".[] | select(.name == \"$SOURCE_CLUSTER_NAME\") | .id")

if [ -z "$SOURCE_CLUSTER_ID" ]; then
    echo "No cluster found with name '$SOURCE_CLUSTER_NAME'"
    exit 1
fi

echo "Found cluster ID: $SOURCE_CLUSTER_ID"

# Get all environments for the source cluster using cluster ID
echo "Finding environments for cluster: $SOURCE_CLUSTER_NAME"
ENVIRONMENTS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments" | jq -r ".[] | select(.cluster[0].id == \"$SOURCE_CLUSTER_ID\") | .name")

if [ -z "$ENVIRONMENTS" ]; then
    echo "No environments found for cluster '$SOURCE_CLUSTER_NAME'"
    exit 1
fi

# Process each environment
echo "$ENVIRONMENTS" | while read -r SOURCE_ENV; do
    # Extract catalog name from environment name
    # For system environments that include cluster name, remove it
    if [[ "$SOURCE_ENV" == *"-${SOURCE_CLUSTER_NAME}" ]]; then
        CATALOG_NAME=$(echo "$SOURCE_ENV" | sed "s/-${SOURCE_CLUSTER_NAME}$//")
    else
        # For custom environments, use the name as is
        CATALOG_NAME="$SOURCE_ENV"
    fi
    
    # Change logging setup to use source cluster name instead of timestamp
    LOG_FILE="./migration_${SOURCE_CLUSTER_NAME}_to_${DEST_CLUSTER_NAME}.log"
    
    # Initialize log file with header
    cat > "$LOG_FILE" <<EOF
=== Migration Report ===
Date: $(date)
Source Environment: $SOURCE_ENV
Target Catalog: $CATALOG_NAME
API Endpoint: $API_ENDPOINT
Cluster: $SOURCE_CLUSTER_NAME

Migration Details:
=====================================
EOF

    echo "=== Migration Configuration ==="
    echo "API Endpoint: $API_ENDPOINT"
    echo "Source Environment: $SOURCE_ENV"
    echo "Target Catalog Name: $CATALOG_NAME"
    echo "Cluster Name: $SOURCE_CLUSTER_NAME"
    echo "==========================="

    # Function to get environment details
    get_env_details() {
        local env_name=$1
        local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name" | jq -r ".[] | select(.name == \"$env_name\")")
        if [ -z "$response" ]; then
            echo "Error: Environment $env_name not found"
            return 1
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
        local response=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$payload" "$API_ENDPOINT/catalog/api/catalogs")
        
        # Check if the response contains an error
        if echo "$response" | jq -e '.errors' > /dev/null; then
            local error_msg=$(echo "$response" | jq -r '.message')
            echo "Error: Failed to create catalog. Response: $error_msg"
            return 1
        fi
        
        # Extract the catalog ID from the response
        local catalog_id=$(echo "$response" | jq -r '.id')
        if [ -z "$catalog_id" ] || [ "$catalog_id" = "null" ]; then
            echo "Error: Failed to extract catalog ID from response"
            return 1
        fi
        
        echo "$catalog_id"
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
        continue
    fi

    # Get or create catalog
    CATALOG_ID=$(check_catalog_exists "$CATALOG_NAME")
    if [ -z "$CATALOG_ID" ]; then
        log_message "Creating new catalog '$CATALOG_NAME'..."
        CATALOG_ID=$(create_catalog "$CATALOG_NAME")
        if [ -z "$CATALOG_ID" ]; then
            log_message "✗ Failed to create catalog '$CATALOG_NAME'"
            continue
        fi
    fi

    log_message "Using catalog ID: $CATALOG_ID"

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
        
        # Check if it's a Git-based application - improved detection
        GIT_UPSTREAM_COUNT=$(echo "$APP_DETAILS" | jq '.gitUpstream | length')
        if [ "$GIT_UPSTREAM_COUNT" -eq 0 ]; then
            log_message "⚠ Skipping $APP_NAME - Not a Git-based application (no gitUpstream)"
            skip_count=$((skip_count + 1))
            continue
        fi

        # Get the first Git upstream ID
        GIT_UPSTREAM_ID=$(echo "$APP_DETAILS" | jq -r '.gitUpstream[0].id')
        if [ -z "$GIT_UPSTREAM_ID" ] || [ "$GIT_UPSTREAM_ID" = "null" ]; then
            log_message "⚠ Skipping $APP_NAME - Invalid Git upstream ID"
            skip_count=$((skip_count + 1))
            continue
        fi
        
        log_message "✓ Detected Git-based application with upstream ID: $GIT_UPSTREAM_ID"
        
        # Create name for the application using destination cluster name
        UNIQUE_APP_NAME="${APP_NAME}-${DEST_CLUSTER_NAME}"
        
        # Check if application already exists
        EXISTING_APP=$(check_application_exists "$UNIQUE_APP_NAME")
        if [ ! -z "$EXISTING_APP" ]; then
            EXISTING_APP_ID=$(echo "$EXISTING_APP" | jq -r '.id')
            log_message "⚠ Application $UNIQUE_APP_NAME already exists with ID: $EXISTING_APP_ID"
            # Add timestamp to make the name unique
            TIMESTAMP=$(date +%Y%m%d%H%M%S)
            UNIQUE_APP_NAME="${APP_NAME}-${DEST_CLUSTER_NAME}-${TIMESTAMP}"
            log_message "  Creating with new unique name: $UNIQUE_APP_NAME"
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
        
        # Get Git upstream details and credentials
        GIT_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/gitupstreams/$GIT_UPSTREAM_ID")
        REPO_URL=$(echo "$GIT_DETAILS" | jq -r '.repository')
        BRANCH=$(echo "$GIT_DETAILS" | jq -r '.branch')
        PATH_VALUE=$(echo "$GIT_DETAILS" | jq -r '.path // "/"')
        
        # Get Git credential details from source GitUpstream
        if [ -n "$GIT_UPSTREAM_ID" ]; then
            GIT_CRED_ID=$(echo "$GIT_DETAILS" | jq -r '.credential.id')
        fi

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
    "state": "running",
    "run": "$APP_NAME",
    "labels": {
        "nirmata.io/application.run": "$APP_NAME"
    }
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

        # Create GitUpstream payload
        GIT_UPSTREAM_PAYLOAD=$(cat << EOF
{
  "repository": "$REPO_URL",
  "branch": "$BRANCH",
  "parent": {
    "id": "$NEW_APP_ID",
    "service": "Catalog",
    "modelIndex": "Application",
    "childRelation": "gitUpstream"
  },
  "additionalProperties": {
    "path": "$PATH_VALUE",
    "application": "$NEW_APP_ID",
    "credential": {
      "service": "Environments",
      "modelIndex": "GitCredential",
      "id": "$GIT_CRED_ID"
    }
  },
  "gitCredential": {
    "service": "Environments",
    "modelIndex": "GitCredential",
    "id": "$GIT_CRED_ID"
  }
}
EOF
)

        # Create GitUpstream for the application with credentials
        log_message "Creating GitUpstream with payload: $GIT_UPSTREAM_PAYLOAD"
        GIT_UPSTREAM_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$GIT_UPSTREAM_PAYLOAD" "$API_ENDPOINT/catalog/api/gitupstreams")

        if [ $? -eq 0 ]; then
            log_message "✓ Successfully created GitUpstream"
            success_count=$((success_count + 1))
        else
            log_message "⚠ Failed to create GitUpstream"
            log_message "Response: $GIT_UPSTREAM_RESPONSE"
            fail_count=$((fail_count + 1))
        fi
        
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
done

echo "Migration process completed. Check migration logs for detailed report."
