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
LOG_FILE="migration_${SOURCE_CLUSTER_NAME}_to_${DEST_CLUSTER_NAME}.log"

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

# Function to get consistent catalog app name
get_catalog_app_name() {
    local app_name=$1
    local source_env=$2
    local cluster_name=$3
    
    # Extract base name without any cluster suffixes or timestamps
    local base_name=$(echo "$app_name" | sed -E 's/-[0-9]+(-[0-9]+)?$//' | sed "s/-${SOURCE_CLUSTER_NAME}$//")
    
    # Create consistent catalog app name with cluster identifier
    echo "app-${base_name}-${cluster_name}"
}

# Function to migrate application
migrate_application() {
    local APP_ID=$1
    local CATALOG_ID=$2
    local SOURCE_ENV=$3
    
    # Get application details
    local APP_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/applications/$APP_ID")
    local APP_NAME=$(echo "$APP_DETAILS" | jq -r '.name')
    
    # Get consistent catalog app name with cluster identifier
    local CATALOG_APP_NAME=$(get_catalog_app_name "$APP_NAME" "$SOURCE_ENV" "$SOURCE_CLUSTER_NAME")
    
    # Check if catalog app already exists
    local EXISTING_APP=$(check_application_exists "$CATALOG_APP_NAME")
    if [ ! -z "$EXISTING_APP" ]; then
        echo "Catalog application $CATALOG_APP_NAME already exists, skipping creation"
        return 0
    fi
    
    # Get Git upstream details
    local GIT_UPSTREAM=$(echo "$APP_DETAILS" | jq -r '.gitUpstream[0]')
    if [ -z "$GIT_UPSTREAM" ] || [ "$GIT_UPSTREAM" = "null" ]; then
        echo "No Git upstream found for application $APP_NAME"
        return 1
    fi
    
    # Get Git credential reference
    local GIT_CRED_NAME=$(get_git_credential_reference "$(echo "$GIT_UPSTREAM" | jq -r '.id')")
    if [ -z "$GIT_CRED_NAME" ]; then
        echo "No Git credential found for application $APP_NAME"
        return 1
    fi
    
    # Create catalog application with cluster-specific configuration
    local CATALOG_APP_PAYLOAD=$(cat <<EOF
{
    "name": "$CATALOG_APP_NAME",
    "description": "Migrated from environment $SOURCE_ENV in cluster $SOURCE_CLUSTER_NAME",
    "catalog": "$CATALOG_ID",
    "gitUpstream": $GIT_UPSTREAM,
    "gitCredential": "$GIT_CRED_NAME",
    "service": "Catalog",
    "modelIndex": "Application",
    "metadata": {
        "sourceCluster": "$SOURCE_CLUSTER_NAME",
        "sourceEnvironment": "$SOURCE_ENV",
        "originalAppName": "$APP_NAME"
    }
}
EOF
)
    
    local CATALOG_APP_RESPONSE=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$CATALOG_APP_PAYLOAD" \
        "$API_ENDPOINT/catalog/api/applications")
    
    if [ $? -eq 0 ] && [ ! -z "$CATALOG_APP_RESPONSE" ]; then
        echo "Successfully created catalog application: $CATALOG_APP_NAME"
        return 0
    else
        echo "Failed to create catalog application: $CATALOG_APP_NAME"
        return 1
    fi
}

# Function to process a single environment
process_environment() {
    local SOURCE_ENV=$1
    local processed_count=0
    local success_count=0
    local skip_count=0
    local fail_count=0
    local has_git_apps=false

    # First check if there are any Git-based applications
    echo "Checking for Git-based applications in environment $SOURCE_ENV..."
    APPS_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/applications?fields=id,name,gitUpstream,yamlData")
    
    if [ "$(echo "$APPS_RESPONSE" | jq 'length')" -eq 0 ]; then
        echo "No applications found in environment $SOURCE_ENV"
        return
    fi

    # Check if any application has Git upstream
    while read -r app; do
        if [ -n "$app" ]; then
            APP_ID=$(echo "$app" | jq -r '.id')
            GIT_UPSTREAM_COUNT=$(echo "$app" | jq '.gitUpstream | length')
            
            if [ "$GIT_UPSTREAM_COUNT" -gt 0 ]; then
                has_git_apps=true
                break
            fi
        fi
    done < <(echo "$APPS_RESPONSE" | jq -c '.[]')

    # Only proceed with catalog creation if there are Git-based applications
    if [ "$has_git_apps" = true ]; then
        # Get catalog name from environment name, removing any unnecessary suffixes
        CATALOG_NAME=$(echo "$SOURCE_ENV" | sed 's/-[0-9].*$//')
        
        # Check if catalog already exists
        echo "Checking if catalog $CATALOG_NAME already exists..."
        CATALOG_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/catalogs?fields=id,name")
        CATALOG_ID=$(echo "$CATALOG_RESPONSE" | jq -r ".[] | select(.name == \"$CATALOG_NAME\") | .id")

        if [ -n "$CATALOG_ID" ]; then
            echo "Catalog $CATALOG_NAME already exists with ID: $CATALOG_ID"
        else
            echo "Creating new catalog: $CATALOG_NAME"
            CATALOG_PAYLOAD=$(cat <<EOF
{
    "name": "$CATALOG_NAME",
    "description": "Migrated from environment $SOURCE_ENV",
    "service": "Catalog",
    "modelIndex": "Catalog"
}
EOF
)
            CATALOG_RESPONSE=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" -d "$CATALOG_PAYLOAD" "$API_ENDPOINT/catalog/api/catalogs")
            CATALOG_ID=$(echo "$CATALOG_RESPONSE" | jq -r '.id')
            
            if [ -n "$CATALOG_ID" ]; then
                echo "Successfully created catalog with ID: $CATALOG_ID"
            else
                echo "Failed to create catalog"
                return 1
            fi
        fi

        # Process applications
        while read -r app; do
            if [ -n "$app" ]; then
                APP_ID=$(echo "$app" | jq -r '.id')
                APP_NAME=$(echo "$app" | jq -r '.name')
                GIT_UPSTREAM_COUNT=$(echo "$app" | jq '.gitUpstream | length')
                
                ((processed_count++))
                
                if [ "$GIT_UPSTREAM_COUNT" -gt 0 ]; then
                    echo "Processing Git-based application: $APP_NAME"
                    migrate_application "$APP_ID" "$CATALOG_ID" "$SOURCE_ENV"
                    if [ $? -eq 0 ]; then
                        ((success_count++))
                    else
                        ((fail_count++))
                    fi
                else
                    echo "Skipping non-Git application: $APP_NAME"
                    ((skip_count++))
                fi
            fi
        done < <(echo "$APPS_RESPONSE" | jq -c '.[]')
    else
        echo "No Git-based applications found in environment $SOURCE_ENV, skipping catalog creation"
    fi

    # Log migration summary for this environment
    echo "=== Migration Summary for $SOURCE_ENV ===" >> "$LOG_FILE"
    echo "Applications processed: $processed_count" >> "$LOG_FILE"
    echo "Successfully migrated: $success_count" >> "$LOG_FILE"
    echo "Skipped (non-Git): $skip_count" >> "$LOG_FILE"
    echo "Failed: $fail_count" >> "$LOG_FILE"
    echo "=====================================" >> "$LOG_FILE"
}

# Process each environment
echo "$ENVIRONMENTS" | while read -r SOURCE_ENV; do
    # Change logging setup to use source cluster name instead of timestamp
    LOG_FILE="./migration_${SOURCE_CLUSTER_NAME}_to_${DEST_CLUSTER_NAME}.log"
    
    # Initialize log file with header
    cat > "$LOG_FILE" <<EOF
=== Migration Report ===
Date: $(date)
Source Environment: $SOURCE_ENV
Target Catalog: $SOURCE_ENV
API Endpoint: $API_ENDPOINT
Cluster: $SOURCE_CLUSTER_NAME

Migration Details:
=====================================
EOF

    echo "=== Migration Configuration ==="
    echo "API Endpoint: $API_ENDPOINT"
    echo "Source Environment: $SOURCE_ENV"
    echo "Target Catalog Name: $SOURCE_ENV"
    echo "Cluster Name: $SOURCE_CLUSTER_NAME"
    echo "==========================="

    # Process the environment
    process_environment "$SOURCE_ENV"
done

echo "Migration process completed. Check migration logs for detailed report."