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

# Create logs directory if it doesn't exist
mkdir -p logs

# Generate log file name with timestamp
LOG_FILE="logs/catalog_reference_update_$(date +%Y%m%d_%H%M%S).log"

# Function to log messages
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Function to check authentication
check_auth() {
    log_message "Checking authentication..."
    local response=$(curl -s -w "%{http_code}" -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/applications")
    local http_code=${response: -3}
    local body=${response%???}
    
    if [ "$http_code" = "200" ]; then
        log_message "Authentication successful"
        return 0
    else
        log_message "ERROR: Authentication failed. HTTP code: $http_code"
        log_message "ERROR: Response: $body"
        return 1
    fi
}

# Function to find catalog application
find_catalog_application() {
    local app_name=$1
    local base_name=$2
    local cluster_name=$3
    
    log_message "Looking for catalog application for: $app_name (base name: $base_name, cluster: $cluster_name)"
    
    # Try different patterns to find the catalog application
    local patterns=(
        "app-${app_name}-${SOURCE_CLUSTER_NAME}"
        "app-${app_name}-${cluster_name}"
        "app-${app_name}"
        "${app_name}"
        "app-${base_name}-${SOURCE_CLUSTER_NAME}"
        "app-${base_name}-${cluster_name}"
        "app-${base_name}"
        "${base_name}"
    )
    
    for pattern in "${patterns[@]}"; do
        log_message "Trying pattern: $pattern"
        local response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/catalog/api/applications?fields=id,name" | jq -r ".[] | select(.name == \"$pattern\")")
        
        if [ ! -z "$response" ] && [ "$response" != "null" ]; then
            local catalog_app_id=$(echo "$response" | jq -r '.id')
            log_message "Found catalog application with ID: $catalog_app_id"
            echo "$catalog_app_id"
            return 0
        fi
    done
    
    log_message "No catalog application found for: $app_name"
    return 1
}

# Function to make API calls with retries
make_api_call() {
    local endpoint=$1
    local method=${2:-GET}
    local data=$3
    local max_retries=3
    local retry_count=0
    local wait_time=5

    while [ $retry_count -lt $max_retries ]; do
        if [ -n "$data" ]; then
            local response=$(curl -s -w "%{http_code}" -X "$method" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                -H "Content-Type: application/json" \
                -d "$data" \
                "$API_ENDPOINT$endpoint")
        else
            local response=$(curl -s -w "%{http_code}" -X "$method" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                "$API_ENDPOINT$endpoint")
        fi

        local http_code=${response: -3}
        local body=${response%???}

        case $http_code in
            200|201|202|204)
                echo "$body"
                return 0
                ;;
            401)
                log_message "ERROR: Authentication failed. Please check your token."
                return 1
                ;;
            403)
                log_message "ERROR: Permission denied. Please check your access rights."
                return 1
                ;;
            404)
                log_message "ERROR: Resource not found: $endpoint"
                return 1
                ;;
            429)
                log_message "WARNING: Rate limit exceeded. Waiting before retry..."
                sleep $wait_time
                wait_time=$((wait_time * 2))
                ;;
            500|502|503|504)
                log_message "WARNING: Server error ($http_code). Retrying in $wait_time seconds..."
                sleep $wait_time
                wait_time=$((wait_time * 2))
                ;;
            *)
                log_message "ERROR: Unexpected HTTP code: $http_code"
                log_message "Response: $body"
                return 1
                ;;
        esac

        retry_count=$((retry_count + 1))
    done

    log_message "ERROR: Maximum retries reached for $endpoint"
    return 1
}

# Function to update catalog reference with enhanced error handling
update_catalog_reference() {
    local app_id=$1
    local catalog_app_id=$2
    local app_name=$3
    local max_retries=3
    local retry_count=0
    local wait_time=5

    log_message "Updating catalog reference for application $app_id to catalog application $catalog_app_id"

    while [ $retry_count -lt $max_retries ]; do
        # Update catalog reference
        local update_data="{\"catalogApplicationId\": \"$catalog_app_id\"}"
        local update_response=$(make_api_call "/environments/api/applications/$app_id" "PUT" "$update_data")
        if [ $? -ne 0 ]; then
            log_message "ERROR: Failed to update catalog reference for $app_name"
            retry_count=$((retry_count + 1))
            if [ $retry_count -lt $max_retries ]; then
                log_message "Retrying in $wait_time seconds... (Attempt $((retry_count + 1)) of $max_retries)"
                sleep $wait_time
                wait_time=$((wait_time * 2))
                continue
            fi
            return 1
        fi

        log_message "Successfully updated catalog reference for $app_name"
        return 0
    done

    log_message "ERROR: Maximum retries reached for updating catalog reference for $app_name"
    return 1
}

# Function to process application with error handling
process_application() {
    local app_id=$1
    local app_name=$2
    local cluster_name=$3
    local base_name=$4

    log_message "Processing application: $app_name (ID: $app_id)"

    # Get catalog application ID
    local catalog_app_id=$(find_catalog_application "$app_name" "$base_name" "$cluster_name")
    if [ -z "$catalog_app_id" ]; then
        log_message "No catalog application found for: $app_name"
        return 0
    fi

    # Update catalog reference with retries
    if ! update_catalog_reference "$app_id" "$catalog_app_id" "$app_name"; then
        log_message "ERROR: Failed to update catalog reference for $app_name after multiple retries"
        return 1
    fi

    return 0
}

# Main execution with error handling
main() {
    local failed_apps=()
    local success_count=0
    local failure_count=0

    # Check authentication
    if ! check_auth; then
        log_message "ERROR: Authentication failed. Exiting."
        exit 1
    fi

    # Get environments
    local environments=$(get_environments)
    if [ $? -ne 0 ]; then
        log_message "ERROR: Failed to get environments. Exiting."
        exit 1
    fi

    # Process each environment
    echo "$environments" | jq -c '.[]' | while read -r env; do
        local env_id=$(echo "$env" | jq -r '.id')
        local env_name=$(echo "$env" | jq -r '.name')
        local cluster_name=$(echo "$env" | jq -r '.clusterName')

        log_message "Processing environment: $env_name (ID: $env_id, Cluster: $cluster_name)"

        # Get applications in environment
        local applications=$(get_applications "$env_id")
        if [ $? -ne 0 ]; then
            log_message "ERROR: Failed to get applications for environment $env_name"
            continue
        fi

        # Process each application
        echo "$applications" | jq -c '.[]' | while read -r app; do
            local app_id=$(echo "$app" | jq -r '.id')
            local app_name=$(echo "$app" | jq -r '.name')
            local base_name=$(echo "$app_name" | sed -E 's/-[0-9]{14}$//' | sed -E 's/-[0-9]+$//')

            if process_application "$app_id" "$app_name" "$cluster_name" "$base_name"; then
                success_count=$((success_count + 1))
            else
                failure_count=$((failure_count + 1))
                failed_apps+=("$app_name")
            fi
        done
    done

    # Log summary
    log_message "Catalog reference update process completed"
    log_message "Successfully processed: $success_count applications"
    if [ $failure_count -gt 0 ]; then
        log_message "Failed to process: $failure_count applications"
        log_message "Failed applications: ${failed_apps[*]}"
    fi
    log_message "Log file: $LOG_FILE"
}

# Main script
log_message "Starting catalog reference update process"

# Check authentication first
if ! check_auth; then
    log_message "ERROR: Authentication check failed. Exiting."
    exit 1
fi

# Get all environments
log_message "Getting environments..."
environments=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name,clusterName")

# Process each environment
echo "$environments" | jq -c '.[]' | while read -r env; do
    env_id=$(echo "$env" | jq -r '.id')
    env_name=$(echo "$env" | jq -r '.name')
    cluster_name=$(echo "$env" | jq -r '.clusterName')
    
    log_message "Processing environment: $env_name (ID: $env_id, Cluster: $cluster_name)"
    
    # Get applications in the environment
    applications=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/environments/api/environments/$env_id/applications")
    
    # Process each application
    echo "$applications" | jq -c '.[]' | while read -r app; do
        app_id=$(echo "$app" | jq -r '.id')
        app_name=$(echo "$app" | jq -r '.name')
        
        log_message "Processing application: $app_name (ID: $app_id)"
        
        # Extract base name (remove cluster suffix and timestamp if present)
        base_name=$(echo "$app_name" | sed -E "s/-${SOURCE_CLUSTER_NAME}-[0-9]+$//" | sed -E "s/-${DEST_CLUSTER_NAME}-[0-9]+$//")
        
        # Find catalog application
        if catalog_app_id=$(find_catalog_application "$app_name" "$base_name" "$cluster_name"); then
            # Update catalog reference
            if update_catalog_reference "$app_id" "$catalog_app_id" "$app_name"; then
                log_message "Successfully processed application: $app_name"
            else
                log_message "ERROR: Failed to update catalog reference for application: $app_name"
            fi
        else
            log_message "No catalog application found for: $app_name"
        fi
    done
done

log_message "Catalog reference update process completed"
log_message "Log file: $LOG_FILE" 