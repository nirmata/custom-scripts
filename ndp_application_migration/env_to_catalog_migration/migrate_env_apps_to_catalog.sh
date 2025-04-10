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
    APPS_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments/$SOURCE_CLUSTER_ID/applications?fields=id,name,gitUpstream,yamlData")
    
    if [ "$(echo "$APPS_RESPONSE" | jq 'length')" -eq 0 ]; then
        echo "No applications found in environment $SOURCE_ENV"
        return
    fi

    # Check if any application has Git upstream
    while read -r app; do
        if [ -n "$app" ]; then
            APP_ID=$(echo "$app" | jq -r '.id')
            APP_DETAILS=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/applications/$APP_ID")
            GIT_UPSTREAM_COUNT=$(echo "$APP_DETAILS" | jq '.gitUpstream | length')
            
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

    # Process the environment
    process_environment "$SOURCE_ENV"
done

echo "Migration process completed. Check migration logs for detailed report."
