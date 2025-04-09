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
    response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name,clusterName")
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get environments"
        return 1
    fi

    # Check if response is valid JSON
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "Error: Invalid JSON response from environments API"
        return 1
    fi

    # Filter environments that either have matching clusterName or have the cluster name in their name
    local filtered_envs
    filtered_envs=$(echo "$response" | jq -r --arg cluster "$cluster_name" \
        '[.[] | select(.clusterName == $cluster or (.name | contains($cluster)))]')
    
    if [ "$filtered_envs" = "[]" ]; then
        log_message "No environments found for cluster $cluster_name"
        return 1
    fi
    
    echo "$filtered_envs"
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

    # First try to find exact match with cluster suffix
    local catalog_app_id
    catalog_app_id=$(echo "$response" | jq -r --arg name "$app_name-${SOURCE_CLUSTER}" \
        '.[] | select(.name == $name) | .id' | head -n 1)
    
    if [ -n "$catalog_app_id" ]; then
        echo "$catalog_app_id"
        return 0
    fi
    
    # If not found, try without cluster suffix
    catalog_app_id=$(echo "$response" | jq -r --arg name "$app_name" \
        '.[] | select(.name == $name) | .id' | head -n 1)
    
    if [ -n "$catalog_app_id" ]; then
        echo "$catalog_app_id"
        return 0
    fi
    
    # If still not found, try with just the base name (remove any -pvc suffix)
    if [[ "$app_name" == *"-pvc" ]]; then
        local base_name=${app_name%-pvc}
        catalog_app_id=$(echo "$response" | jq -r --arg name "$base_name-${SOURCE_CLUSTER}" \
            '.[] | select(.name == $name) | .id' | head -n 1)
        
        if [ -n "$catalog_app_id" ]; then
            echo "$catalog_app_id"
            return 0
        fi
    fi
    
    return 1
}

# Function to find target environment
find_target_environment() {
    local source_env_name=$1
    local target_envs=$2
    local target_env_name=""

    # Extract base name and create target name - handle different naming patterns
    if [[ "$source_env_name" == *"-${SOURCE_CLUSTER}" ]]; then
        # Standard pattern: name-clusterName
        base_name=${source_env_name%-$SOURCE_CLUSTER}
        target_env_name="${base_name}-${TARGET_CLUSTER}"
    elif [[ "$source_env_name" == *"${SOURCE_CLUSTER}"* ]]; then
        # Other patterns containing cluster name
        base_name=$(echo "$source_env_name" | sed "s/${SOURCE_CLUSTER}//g" | sed 's/--*/-/g' | sed 's/-$//')
        target_env_name="${base_name}-${TARGET_CLUSTER}"
    else
        # No cluster name in environment name
        base_name="$source_env_name"
        target_env_name="${base_name}-${TARGET_CLUSTER}"
    fi

    # Find matching target environment
    local target_env
    target_env=$(echo "$target_envs" | jq -r --arg name "$target_env_name" '.[] | select(.name == $name)')
    
    if [ -n "$target_env" ] && [ "$target_env" != "null" ]; then
        echo "$target_env"
        return 0
    fi
    
    return 1
}

# Function to update catalog application reference
update_catalog_reference() {
    local target_env_id=$1
    local app_name=$2
    local catalog_app_id=$3
    local response
    
    log_message "Updating application $app_name to use catalog reference $catalog_app_id"
    
    # Create payload for updating the application
    local payload="{\"upstreamType\": \"catalog\", \"catalogApplicationId\": \"$catalog_app_id\"}"
    
    # Update the application
    response=$(curl -s -X PUT -H "Authorization: NIRMATA-API $TOKEN" -H "Content-Type: application/json" \
        -d "$payload" "$API_ENDPOINT/environments/api/environments/$target_env_id/applications/$app_name")
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to update application $app_name"
        return 1
    fi
    
    # Verify the update was successful
    if ! echo "$response" | jq empty 2>/dev/null; then
        log_message "Error: Invalid JSON response from update API"
        return 1
    fi
    
    log_message "Successfully updated application $app_name in environment $target_env_id"
}

# Main process
log_message "Starting catalog reference update process"
log_message "API Endpoint: $API_ENDPOINT"
log_message "Source Cluster: $SOURCE_CLUSTER"
log_message "Target Cluster: $TARGET_CLUSTER"

# Check for specific restored environment
RESTORED_ENV_NAME="nginx-123-${TARGET_CLUSTER}"
log_message "Looking for restored environment: $RESTORED_ENV_NAME"

# Get the restored environment
RESTORED_ENV_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name")
if [ $? -ne 0 ]; then
    log_message "Error: Failed to get environments"
    exit 1
fi

# Check if response is valid JSON
if ! echo "$RESTORED_ENV_RESPONSE" | jq empty 2>/dev/null; then
    log_message "Error: Invalid JSON response from environments API"
    exit 1
fi

# Find the restored environment
RESTORED_ENV=$(echo "$RESTORED_ENV_RESPONSE" | jq -r --arg name "$RESTORED_ENV_NAME" '.[] | select(.name == $name)')
if [ -z "$RESTORED_ENV" ] || [ "$RESTORED_ENV" = "null" ]; then
    log_message "Restored environment $RESTORED_ENV_NAME not found"
else
    RESTORED_ENV_ID=$(echo "$RESTORED_ENV" | jq -r '.id')
    log_message "Found restored environment with ID: $RESTORED_ENV_ID"
    
    # Get applications from the restored environment
    RESTORED_APPS=$(get_catalog_app_details "$RESTORED_ENV_ID")
    if [ -z "$RESTORED_APPS" ]; then
        log_message "No applications found in restored environment $RESTORED_ENV_NAME"
    else
        # Process each application in the restored environment
        echo "$RESTORED_APPS" | jq -r '.[] | @json' | while read -r app; do
            if [ -z "$app" ] || [ "$app" = "null" ]; then
                continue
            fi
            
            app_name=$(echo "$app" | jq -r '.name // empty')
            if [ -z "$app_name" ]; then
                continue
            fi
            
            log_message "Processing application $app_name in restored environment"
            
            # Try different catalog application name patterns
            catalog_app_id=""
            
            # First try with source cluster suffix
            log_message "Looking for catalog application: $app_name-${SOURCE_CLUSTER}"
            catalog_app_id=$(get_catalog_application "$app_name")
            
            if [ -z "$catalog_app_id" ]; then
                # If not found, try without the -pvc suffix for PVC applications
                if [[ "$app_name" == *"-pvc" ]]; then
                    local base_name=${app_name%-pvc}
                    log_message "Looking for catalog application: $base_name-${SOURCE_CLUSTER}"
                    catalog_app_id=$(get_catalog_application "$base_name")
                fi
            fi
            
            if [ -z "$catalog_app_id" ]; then
                log_message "No matching catalog application found for $app_name"
                continue
            fi
            
            log_message "Found catalog application with ID: $catalog_app_id"
            
            # Update the catalog reference
            update_catalog_reference "$RESTORED_ENV_ID" "$app_name" "$catalog_app_id"
        done
    fi
fi

# Continue with the regular process for other environments
# Get source environments
source_envs=$(get_env_details "$SOURCE_CLUSTER")
if [ $? -ne 0 ]; then
    log_message "Failed to get source environments, but continuing with restored environment processing"
else
    # Get target environments
    target_envs=$(get_env_details "$TARGET_CLUSTER")
    if [ $? -ne 0 ]; then
        log_message "Failed to get target environments, but continuing with restored environment processing"
    else
        # Process each source environment
        echo "$source_envs" | jq -r '.[] | @json' | while read -r source_env; do
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

            # Skip system namespaces and already processed environments
            if [[ "$source_env_name" =~ ^(kube-system|kube-public|kube-node-lease|nirmata|ingress-haproxy|velero|default)- ]] || \
               [ "$source_env_name" = "nginx-123" ]; then
                log_message "Skipping system/processed environment: $source_env_name"
                continue
            fi
            
            log_message "Processing source environment: $source_env_name"
            
            # Find target environment
            target_env=$(find_target_environment "$source_env_name" "$target_envs")
            if [ $? -ne 0 ]; then
                log_message "No matching target environment found for $source_env_name"
                continue
            fi
            
            target_env_id=$(echo "$target_env" | jq -r '.id // empty')
            target_env_name=$(echo "$target_env" | jq -r '.name // empty')
            
            if [ -z "$target_env_id" ] || [ -z "$target_env_name" ]; then
                log_message "Error: Invalid target environment data"
                continue
            fi
            
            log_message "Found target environment: $target_env_name"
            
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
                
                # Get catalog application ID
                catalog_app_id=$(get_catalog_application "$source_app_name")
                if [ -z "$catalog_app_id" ]; then
                    log_message "No catalog application found for $source_app_name"
                    continue
                fi
                
                log_message "Processing application $source_app_name"
                update_catalog_reference "$target_env_id" "$source_app_name" "$catalog_app_id"
            done
        done
    fi
fi

log_message "Catalog reference update process completed"
log_message "Log file: $LOG_FILE" 