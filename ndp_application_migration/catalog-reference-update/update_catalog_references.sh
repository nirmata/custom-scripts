#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <api_endpoint> <token> <source_cluster> <target_cluster>"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"123-app-migration\" \"129-app-migration\""
    exit 1
fi

API_ENDPOINT=$1
TOKEN=$2
SOURCE_CLUSTER=$3
TARGET_CLUSTER=$4

# Create logs directory if it doesn't exist
LOGS_DIR="logs"
mkdir -p "$LOGS_DIR"
LOG_FILE="$LOGS_DIR/catalog_reference_update_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages to both console and file
log_message() {
    echo "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> "$LOG_FILE"
}

# Function to get environment details
get_env_details() {
    local cluster_name=$1
    local response
    response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name")
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get environments"
        return 1
    fi

    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "Error: Invalid JSON response from environments API"
        return 1
    fi

    # Filter environments for the given cluster and format output
    echo "$response" | jq -r --arg cluster "$cluster_name" \
        '.[] | select(.name | endswith($cluster)) | @json'
}

# Function to get catalog application details from environment
get_catalog_app_details() {
    local env_id=$1
    local response
    response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments/$env_id/applications?fields=id,name,type,upstreamType,gitUpstream,catalogApplicationId,catalogApplication")
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get applications for environment $env_id"
        return 1
    fi

    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "Error: Invalid JSON response from applications API"
        return 1
    fi

    # Return application details if any exist
    echo "$response"
}

# Function to get catalog application
get_catalog_application() {
    local app_name=$1
    local response
    response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/applications?fields=id,name,type,upstreamType,gitUpstream")
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get catalog applications"
        return 1
    fi

    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "Error: Invalid JSON response from catalog API"
        return 1
    fi

    # Find the first catalog application with matching name and upstreamType=catalog
    echo "$response" | jq -r --arg name "$app_name" \
        '.[] | select(.name == $name and .upstreamType == "catalog") | .id' | head -n 1
}

# Function to update catalog application reference
update_catalog_reference() {
    local target_env_id=$1
    local app_name=$2
    local source_app=$3
    local target_app=$4
    local response
    
    # Extract source application type and references
    local source_upstream_type=$(echo "$source_app" | jq -r '.upstreamType // empty')
    local payload=""
    
    if [ "$source_upstream_type" = "git" ]; then
        # Extract Git upstream ID
        local git_upstream_id=$(echo "$source_app" | jq -r '.gitUpstream[0].id // empty')
        if [ -z "$git_upstream_id" ]; then
            log_message "Error: Failed to extract Git upstream ID from source application"
            return 1
        fi
        
        payload="{\"upstreamType\": \"git\", \"gitUpstream\": \"$git_upstream_id\"}"
        log_message "Updating application $app_name to use Git upstream $git_upstream_id"
    elif [ "$source_upstream_type" = "catalog" ] || [ -z "$source_upstream_type" ]; then
        # Get catalog application ID from source
        local catalog_app_id=$(echo "$source_app" | jq -r '.catalogApplication // empty')
        if [ -z "$catalog_app_id" ] || [ "$catalog_app_id" = "null" ]; then
            catalog_app_id=$(echo "$source_app" | jq -r '.catalogApplicationId // empty')
        fi
        
        if [ -z "$catalog_app_id" ] || [ "$catalog_app_id" = "null" ]; then
            log_message "Warning: No catalog application ID found in source application, checking catalog"
            # Try to find the catalog application with the same name
            catalog_app_id=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/applications?fields=id,name,type,upstreamType" | \
                jq -r --arg name "$app_name" '.[] | select(.name == $name and .upstreamType == "catalog") | .id' | head -n 1)
            if [ -z "$catalog_app_id" ]; then
                log_message "Error: Failed to find catalog application ID for $app_name"
                return 1
            fi
        fi
        
        log_message "Found catalog application ID: $catalog_app_id"
        
        # Verify the catalog application exists
        local catalog_app=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/applications/$catalog_app_id")
        if [ $? -ne 0 ] || [ -z "$catalog_app" ]; then
            log_message "Error: Failed to verify catalog application $catalog_app_id"
            return 1
        fi
        
        payload="{\"upstreamType\": \"catalog\", \"catalogApplicationId\": \"$catalog_app_id\"}"
        log_message "Updating application $app_name to use catalog reference $catalog_app_id"
    else
        log_message "Skipping application $app_name - not a Git or catalog application"
        return 0
    fi
    
    # Update the application
    response=$(curl -s -X PUT -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" \
        -d "$payload" "$API_ENDPOINT/environments/api/environments/$target_env_id/applications/$app_name")
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to update application $app_name"
        return 1
    fi
    
    log_message "Successfully updated application $app_name in environment $target_env_id"
}

# Main process
log_message "Starting catalog reference update process"
log_message "API Endpoint: $API_ENDPOINT"
log_message "Source Cluster: $SOURCE_CLUSTER"
log_message "Target Cluster: $TARGET_CLUSTER"

# Get source environments
source_envs=$(get_env_details "$SOURCE_CLUSTER")
if [ -z "$source_envs" ]; then
    log_message "No environments found for source cluster $SOURCE_CLUSTER"
    exit 1
fi

# Get target environments
target_envs=$(get_env_details "$TARGET_CLUSTER")
if [ -z "$target_envs" ]; then
    log_message "No environments found for target cluster $TARGET_CLUSTER"
    exit 1
fi

# Process each source environment
echo "$source_envs" | while read -r source_env; do
    if [ -z "$source_env" ] || [ "$source_env" = "null" ]; then
        continue
    fi

    # Parse source environment JSON
    source_env_id=$(echo "$source_env" | jq -r '.id // empty')
    source_env_name=$(echo "$source_env" | jq -r '.name // empty')
    
    if [ -z "$source_env_id" ] || [ -z "$source_env_name" ]; then
        log_message "Error: Invalid source environment data"
        continue
    fi

    # Extract base name and create target name
    base_name=${source_env_name%-$SOURCE_CLUSTER}
    target_env_name="${base_name}-${TARGET_CLUSTER}"
    
    log_message "Looking for target environment: $target_env_name"
    
    # Find matching target environment
    target_env=$(echo "$target_envs" | while read -r env; do
        if [ -z "$env" ] || [ "$env" = "null" ]; then
            continue
        fi
        env_name=$(echo "$env" | jq -r '.name // empty')
        if [ "$env_name" = "$target_env_name" ]; then
            echo "$env"
            break
        fi
    done)
    
    if [ -z "$target_env" ]; then
        log_message "No matching target environment found for $source_env_name (looking for $target_env_name)"
        continue
    fi
    
    target_env_id=$(echo "$target_env" | jq -r '.id // empty')
    if [ -z "$target_env_id" ]; then
        log_message "Error: Invalid target environment data"
        continue
    fi
    
    log_message "Processing environment pair: $source_env_name -> $target_env_name"
    
    # Get applications from both source and target environments
    source_apps=$(get_catalog_app_details "$source_env_id")
    if [ -z "$source_apps" ]; then
        log_message "No applications found in source environment $source_env_name"
        continue
    fi
    
    target_apps=$(get_catalog_app_details "$target_env_id")
    if [ -z "$target_apps" ]; then
        log_message "No applications found in target environment $target_env_name"
        continue
    fi
    
    # Process each application in source environment
    echo "$source_apps" | jq -r '.[] | @json' | while read -r source_app; do
        if [ -z "$source_app" ] || [ "$source_app" = "null" ]; then
            continue
        fi
        
        source_app_name=$(echo "$source_app" | jq -r '.name // empty')
        if [ -z "$source_app_name" ]; then
            continue
        fi
        
        # Find matching application in target environment
        target_app=$(echo "$target_apps" | jq -r --arg name "$source_app_name" \
            '.[] | select(.name == $name)')
        
        if [ -z "$target_app" ] || [ "$target_app" = "null" ]; then
            log_message "No matching application found in target environment for $source_app_name"
            continue
        fi
        
        log_message "Processing application $source_app_name"
        update_catalog_reference "$target_env_id" "$source_app_name" "$source_app" "$target_app"
    done
done

log_message "Catalog reference update process completed"
log_message "Log file: $LOG_FILE" 