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

# Function to log messages with timestamp
log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

# Function to validate required arguments
validate_args() {
    if [ -z "$1" ]; then
        log_message "Error: Missing required argument"
        log_message "Usage: $0 <token>"
        exit 1
    fi
}

# Function to authenticate and get access token
authenticate() {
    local token=$1
    log_message "Authenticating with token..."
    
    # First try to get the token info to validate it
    local token_info=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $token" \
        -H "Content-Type: application/json" \
        "https://api.nirmata.io/api/v1/token/info")
    
    local http_code=$(echo "$token_info" | tail -n1)
    local response=$(echo "$token_info" | sed '$d')
    
    if [ "$http_code" -eq 200 ]; then
        log_message "Token validation successful"
        echo "$token"
        return 0
    else
        log_message "Error: Token validation failed with status $http_code"
        log_message "Response: $response"
        return 1
    fi
}

# Function to find catalog application by name pattern
find_catalog_app() {
    local access_token=$1
    log_message "Searching for catalog applications..."
    
    # Get all applications
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        "https://api.nirmata.io/api/v1/applications")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ne 200 ]; then
        log_message "Error: Failed to get applications list (HTTP $http_code)"
        log_message "Response: $body"
        return 1
    fi
    
    # Look for catalog applications using various patterns
    local catalog_app=$(echo "$body" | jq -r '.items[] | select(
        (.metadata.name | test("^catalog-.*")) or
        (.metadata.name | test("^catalog.*")) or
        (.metadata.name | test(".*catalog.*")) or
        (.metadata.name | test("^novartis-catalog.*")) or
        (.metadata.name | test("^novartis-catalog-.*"))
    ) | .metadata.name')
    
    if [ -n "$catalog_app" ]; then
        log_message "Found catalog application: $catalog_app"
        echo "$catalog_app"
        return 0
    else
        log_message "No catalog application found"
        return 1
    fi
}

# Function to update catalog references
update_catalog_references() {
    local access_token=$1
    local catalog_app=$2
    
    log_message "Updating catalog references for application: $catalog_app"
    
    # Get the application details
    local response=$(curl -s -w "\n%{http_code}" \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        "https://api.nirmata.io/api/v1/applications/$catalog_app")
    
    local http_code=$(echo "$response" | tail -n1)
    local body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -ne 200 ]; then
        log_message "Error: Failed to get application details (HTTP $http_code)"
        log_message "Response: $body"
        return 1
    fi
    
    # Update the catalog references
    local update_response=$(curl -s -w "\n%{http_code}" \
        -X PUT \
        -H "Authorization: Bearer $access_token" \
        -H "Content-Type: application/json" \
        -d "$body" \
        "https://api.nirmata.io/api/v1/applications/$catalog_app")
    
    local update_http_code=$(echo "$update_response" | tail -n1)
    local update_body=$(echo "$update_response" | sed '$d')
    
    if [ "$update_http_code" -eq 200 ]; then
        log_message "Successfully updated catalog references"
        return 0
    else
        log_message "Error: Failed to update catalog references (HTTP $update_http_code)"
        log_message "Response: $update_body"
        return 1
    fi
}

# Main script
main() {
    # Validate arguments
    validate_args "$1"
    
    # Authenticate
    local access_token=$(authenticate "$1")
    if [ $? -ne 0 ]; then
        log_message "Authentication failed"
        exit 1
    fi
    
    # Find catalog application
    local catalog_app=$(find_catalog_app "$access_token")
    if [ $? -ne 0 ]; then
        log_message "Failed to find catalog application"
        exit 1
    fi
    
    # Update catalog references
    update_catalog_references "$access_token" "$catalog_app"
    if [ $? -ne 0 ]; then
        log_message "Failed to update catalog references"
        exit 1
    fi
    
    log_message "Script completed successfully"
}

# Execute main function with all arguments
main "$@"

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

# Function to get base name from environment name
get_base_name() {
    local env_name=$1
    local cluster_name=$2
    
    # Remove cluster suffix if present
    local base_name=$(echo "$env_name" | sed "s/-${cluster_name}$//")
    
    # Remove any timestamp suffixes
    base_name=$(echo "$base_name" | sed -E 's/-[0-9]+(-[0-9]+)?$//')
    
    echo "$base_name"
}

# Function to find catalog application
find_catalog_application() {
    local app_name=$1
    local base_name=$2
    local cluster_name=$3
    
    log_message "Looking for catalog application for $app_name (base: $base_name, cluster: $cluster_name)"
    
    # Get all catalog applications first
    local catalog_apps
    catalog_apps=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" \
        "$API_ENDPOINT/catalog/api/applications?fields=id,name,metadata")
    
    if [ $? -ne 0 ] || [ -z "$catalog_apps" ]; then
        log_message "Error: Failed to get catalog applications"
        return 1
    fi
    
    # First try exact match
    local response
    response=$(echo "$catalog_apps" | jq -r --arg name "$app_name" \
        '.[] | select(.name == $name) | .id' | head -n 1)
    
    if [ ! -z "$response" ] && [ "$response" != "null" ]; then
        log_message "Found catalog app using exact match: $app_name (ID: $response)"
        echo "$response"
        return 0
    fi
    
    # Try without timestamp if present
    local base_app_name=$(echo "$app_name" | sed -E 's/-[0-9]{8}[0-9]*$//')
    if [ "$base_app_name" != "$app_name" ]; then
        log_message "Trying without timestamp: $base_app_name"
        response=$(echo "$catalog_apps" | jq -r --arg name "$base_app_name" \
            '.[] | select(.name == $name) | .id' | head -n 1)
        
        if [ ! -z "$response" ] && [ "$response" != "null" ]; then
            log_message "Found catalog app using base name without timestamp: $base_app_name (ID: $response)"
            echo "$response"
            return 0
        fi
    fi
    
    # Try without cluster suffix if present
    local no_cluster_name=$(echo "$app_name" | sed "s/-${cluster_name}.*//")
    if [ "$no_cluster_name" != "$app_name" ]; then
        log_message "Trying without cluster suffix: $no_cluster_name"
        response=$(echo "$catalog_apps" | jq -r --arg name "$no_cluster_name" \
            '.[] | select(.name == $name) | .id' | head -n 1)
        
        if [ ! -z "$response" ] && [ "$response" != "null" ]; then
            log_message "Found catalog app using name without cluster suffix: $no_cluster_name (ID: $response)"
            echo "$response"
            return 0
        fi
    fi
    
    # Try with different patterns
    local patterns=(
        "${app_name}"                                    # Exact match
        "${base_app_name}"                              # Without timestamp
        "${no_cluster_name}"                            # Without cluster suffix
        "${app_name%-pvc}"                              # Without -pvc suffix
        "${base_app_name%-pvc}"                         # Without -pvc suffix and timestamp
        "${no_cluster_name%-pvc}"                       # Without -pvc suffix and cluster
        "${app_name#private-git-}"                      # Without private-git- prefix
        "${base_app_name#private-git-}"                 # Without private-git- prefix and timestamp
        "${no_cluster_name#private-git-}"               # Without private-git- prefix and cluster
        "$(echo "$app_name" | sed 's/-gitops//')"      # Without -gitops suffix
        "$(echo "$base_app_name" | sed 's/-gitops//')" # Without -gitops suffix and timestamp
        "$(echo "$no_cluster_name" | sed 's/-gitops//')" # Without -gitops suffix and cluster
    )
    
    for pattern in "${patterns[@]}"; do
        if [ -z "$pattern" ]; then
            continue
        fi
        
        log_message "Trying pattern: $pattern"
        response=$(echo "$catalog_apps" | jq -r --arg name "$pattern" \
            '.[] | select(.name == $name) | .id' | head -n 1)
        
        if [ ! -z "$response" ] && [ "$response" != "null" ]; then
            log_message "Found catalog app using pattern: $pattern (ID: $response)"
            echo "$response"
            return 0
        fi
        
        # Try with -git suffix
        local git_pattern="${pattern}-git"
        log_message "Trying with -git suffix: $git_pattern"
        response=$(echo "$catalog_apps" | jq -r --arg name "$git_pattern" \
            '.[] | select(.name == $name) | .id' | head -n 1)
        
        if [ ! -z "$response" ] && [ "$response" != "null" ]; then
            log_message "Found catalog app using -git suffix: $git_pattern (ID: $response)"
            echo "$response"
            return 0
        fi
    done
    
    log_message "No catalog application found for $app_name"
    echo ""  # Return empty string if no catalog app found
    return 1
}

# Function to update catalog reference
update_catalog_reference() {
    local target_env_id=$1
    local app_name=$2
    local base_name=$3
    local cluster_name=$4
    
    log_message "Processing application $app_name in environment $target_env_id"
    
    # Find catalog application
    local catalog_app_id
    catalog_app_id=$(find_catalog_application "$app_name" "$base_name" "$cluster_name")
    
    if [ -z "$catalog_app_id" ] || [[ "$catalog_app_id" == *"Looking for catalog application"* ]]; then
        log_message "No catalog application found for $app_name in cluster $cluster_name"
        return 1
    fi
    
    # Get the application ID
    local app_id_response
    app_id_response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" \
        "$API_ENDPOINT/environments/api/environments/$target_env_id/applications?fields=id,name")
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get application ID for $app_name"
        return 1
    fi
    
    local app_id
    app_id=$(echo "$app_id_response" | jq -r --arg name "$app_name" '.[] | select(.name == $name) | .id')
    
    if [ -z "$app_id" ] || [ "$app_id" = "null" ]; then
        log_message "Error: Could not find application ID for $app_name"
        return 1
    fi
    
    # Get catalog application details to verify it's the right one
    local catalog_app_details
    catalog_app_details=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" \
        "$API_ENDPOINT/catalog/api/applications/$catalog_app_id?fields=id,name,metadata")
    
    if [ $? -ne 0 ] || [ -z "$catalog_app_details" ]; then
        log_message "Error: Failed to get catalog application details for ID: $catalog_app_id"
        return 1
    fi
    
    local catalog_app_name=$(echo "$catalog_app_details" | jq -r '.name')
    if [ -z "$catalog_app_name" ] || [ "$catalog_app_name" = "null" ]; then
        log_message "Error: Could not get catalog application name for ID: $catalog_app_id"
        return 1
    fi
    
    log_message "Found catalog application: $catalog_app_name (ID: $catalog_app_id)"
    
    # Update the application
    local update_payload
    update_payload=$(cat <<EOF
{
    "upstreamType": "catalog",
    "type": "catalog",
    "catalogApplicationId": "$catalog_app_id",
    "catalogApplication": "$catalog_app_id",
    "parent": {
        "id": "$target_env_id",
        "service": "Environment",
        "modelIndex": "Environment",
        "childRelation": "applications"
    },
    "modelIndex": "Application",
    "service": "Environment",
    "metadata": {
        "sourceCluster": "$cluster_name",
        "originalAppName": "$app_name",
        "catalogAppName": "$catalog_app_name"
    }
}
EOF
)
    
    # Start a transaction
    local txn_response
    txn_response=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        "$API_ENDPOINT/environments/api/txn")
    
    if [ $? -ne 0 ] || [ -z "$txn_response" ]; then
        log_message "Failed to start transaction for application $app_name"
        return 1
    fi
    
    local txn_id=$(echo "$txn_response" | jq -r '.id')
    
    # Update the application within the transaction
    local update_response
    update_response=$(curl -s -X PUT -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$update_payload" \
        "$API_ENDPOINT/environments/api/applications/$app_id?txnId=$txn_id")
    
    if [ $? -eq 0 ] && [ ! -z "$update_response" ]; then
        log_message "Successfully updated catalog reference for $app_name to $catalog_app_name"
        
        # First commit the transaction
        local commit_response
        commit_response=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            "$API_ENDPOINT/environments/api/txn/$txn_id/commit")
        
        if [ $? -eq 0 ] && [ ! -z "$commit_response" ]; then
            log_message "Successfully committed transaction for $app_name"
            
            # Now save the changes using the application commit endpoint
            local save_payload
            save_payload=$(cat <<EOF
{
    "modelIndex": "Application",
    "id": "$app_id",
    "service": "Environment",
    "upstreamType": "catalog",
    "catalogApplicationId": "$catalog_app_id",
    "catalogApplication": "$catalog_app_id"
}
EOF
)
            
            local save_response
            save_response=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
                -H "Content-Type: application/json" \
                -d "$save_payload" \
                "$API_ENDPOINT/environments/api/applications/$app_id/commit")
            
            if [ $? -eq 0 ] && [ ! -z "$save_response" ]; then
                log_message "Successfully saved changes for application $app_name"
                
                # Finally, refresh the application to ensure changes are applied
                local refresh_response
                refresh_response=$(curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
                    -H "Content-Type: application/json" \
                    "$API_ENDPOINT/environments/api/applications/$app_id/refresh")
                
                if [ $? -eq 0 ] && [ ! -z "$refresh_response" ]; then
                    log_message "Successfully refreshed application $app_name"
                    return 0
                else
                    log_message "Warning: Failed to refresh application $app_name"
                    return 0  # Continue anyway since the save was successful
                fi
            else
                log_message "Failed to save changes for application $app_name"
                return 1
            fi
        else
            log_message "Failed to commit transaction for application $app_name"
            # Try to rollback the transaction
            curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
                -H "Content-Type: application/json" \
                "$API_ENDPOINT/environments/api/txn/$txn_id/rollback"
            return 1
        fi
    else
        log_message "Failed to update catalog reference for $app_name to $catalog_app_name"
        # Try to rollback the transaction
        curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            "$API_ENDPOINT/environments/api/txn/$txn_id/rollback"
        return 1
    fi
}

# Main process
log_message "Starting catalog reference update process"

# Get all environments
ENVIRONMENTS_RESPONSE=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" \
    "$API_ENDPOINT/environments/api/environments?fields=id,name,cluster")

if [ $? -ne 0 ]; then
    log_message "Error: Failed to get environments"
    exit 1
fi

# Process each environment
echo "$ENVIRONMENTS_RESPONSE" | jq -c '.[]' | while read -r env; do
    env_id=$(echo "$env" | jq -r '.id')
    env_name=$(echo "$env" | jq -r '.name')
    
    # Extract cluster name from environment name if it contains the target cluster
    if [[ "$env_name" == *"$TARGET_CLUSTER"* ]]; then
        cluster_name="$TARGET_CLUSTER"
    else
        continue
    fi
    
    # Get base name for the environment
    base_name=$(get_base_name "$env_name" "$TARGET_CLUSTER")
    
    # Get applications in the environment
    apps_response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" \
        "$API_ENDPOINT/environments/api/environments/$env_id/applications?fields=id,name")
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get applications for environment $env_name"
        continue
    fi
    
    # Process each application
    echo "$apps_response" | jq -c '.[]' | while read -r app; do
        app_name=$(echo "$app" | jq -r '.name')
        
        # Update catalog reference with cluster name
        update_catalog_reference "$env_id" "$app_name" "$base_name" "$cluster_name"
    done
done

log_message "Catalog reference update process completed"
log_message "Log file: $LOG_FILE" 