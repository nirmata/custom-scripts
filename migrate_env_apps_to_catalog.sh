#!/bin/bash

# Check if all required arguments are provided
if [ "$#" -lt 3 ] || [ "$#" -gt 4 ]; then
    echo "Usage: $0 <api_endpoint> <token> <source_cluster> [destination_cluster]"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"123-app-migration\" \"129-app-migration\""
    exit 1
fi

API_ENDPOINT=$1
TOKEN=$2
CLUSTER_NAME=$3
DESTINATION_CLUSTER=${4:-$CLUSTER_NAME}  # Use destination cluster if provided, otherwise use source cluster
TOKEN_FORMAT="NIRMATA-API"  # Default token format, may change during validation

# Check for dry run option
DRY_RUN=false
if [ "$4" = "--dry-run" ] || [ "$5" = "--dry-run" ]; then
    DRY_RUN=true
    log_message "*** DRY RUN MODE ENABLED - No changes will be made ***"
fi

FORCE_MODE=false

# Function to validate token
validate_token() {
    log_message "Validating token..."
    
    # Debug token format
    log_message "Token length: ${#TOKEN}"
    local first_10_chars="${TOKEN:0:10}..."
    log_message "Token first 10 chars: $first_10_chars"
    
    # Try different header formats
    log_message "Trying standard header format..."
    local std_response=$(curl -s -v -H "Authorization: NIRMATA-API $TOKEN" "$API_ENDPOINT/users/api/users/current" 2>&1)
    local std_status=$(echo "$std_response" | grep -oE "HTTP/[0-9.]+ [0-9]+" | tail -1 | awk '{print $2}')
    
    log_message "Standard header response status: $std_status"
    
    if [ "$std_status" = "200" ]; then
        log_message "Token validated successfully with standard header."
        return 0
    fi
    
    # Try Base64 encoded token
    log_message "Trying with encoded token..."
    local encoded_token=$(echo -n "$TOKEN" | base64)
    local enc_response=$(curl -s -v -H "Authorization: NIRMATA-API $encoded_token" "$API_ENDPOINT/users/api/users/current" 2>&1)
    local enc_status=$(echo "$enc_response" | grep -oE "HTTP/[0-9.]+ [0-9]+" | tail -1 | awk '{print $2}')
    
    log_message "Encoded token response status: $enc_status"
    
    if [ "$enc_status" = "200" ]; then
        TOKEN="$encoded_token"
        log_message "Token validated successfully with encoded token."
        return 0
    fi
    
    # Try with bearer token format
    log_message "Trying with Bearer token format..."
    local bearer_response=$(curl -s -v -H "Authorization: Bearer $TOKEN" "$API_ENDPOINT/users/api/users/current" 2>&1)
    local bearer_status=$(echo "$bearer_response" | grep -oE "HTTP/[0-9.]+ [0-9]+" | tail -1 | awk '{print $2}')
    
    log_message "Bearer token response status: $bearer_status"
    
    if [ "$bearer_status" = "200" ]; then
        TOKEN_FORMAT="Bearer"
        log_message "Token validated successfully with Bearer format."
        return 0
    fi
    
    log_message "Error: Invalid token or API endpoint. All authentication methods failed."
    log_message "Standard response: $std_response"
    return 1
}

# Function to check if application exists in catalog
check_catalog_application_exists() {
    local app_name=$1
    local catalog_id=$2
    local response=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/catalog/api/applications?fields=id,name,catalog" | jq -r ".[] | select(.name == \"$app_name\" and .catalog == \"$catalog_id\")")
    echo "$response"
}

# Function to get Git credentials from source application
get_git_credentials() {
    local app_id=$1
    local response=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/environments/api/applications/$app_id/credentials")
    echo "$response"
}

# Function to check if catalog exists
check_catalog_exists() {
    local catalog_name=$1
    local response=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/catalog/api/catalogs?fields=id,name" | jq -r ".[] | select(.name == \"$catalog_name\") | .id")
    echo "$response"
}

# Function to get application configuration
get_application_config() {
    local app_id=$1
    local config=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/environments/api/applications/$app_id/configuration")
    echo "$config"
}

# Find environments based on the cluster name
log_message "Finding environments in cluster $CLUSTER_NAME..."
CLUSTER_FIELD="cluster"
ENVIRONMENT_RESPONSE=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name,$CLUSTER_FIELD")

# Update all curl commands to use the dynamic TOKEN_FORMAT
# This is a placeholder edit to help the apply model find all instances
# that contain "Authorization: NIRMATA-API $TOKEN" and replace them with
# "Authorization: $TOKEN_FORMAT $TOKEN"

# In ENV_DETAILS_RESPONSE call
ENV_DETAILS_RESPONSE=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/environments/api/environments?fields=id,name,$CLUSTER_FIELD&query=name%3D$SOURCE_ENV")

# In APPS_RESPONSE call
APPS_RESPONSE=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/environments/api/environments/$ENV_ID/applications?fields=id,name,gitUpstream,configuration")

# In GIT_DETAILS call
GIT_DETAILS=$(curl -s -H "Authorization: $TOKEN_FORMAT $TOKEN" "$API_ENDPOINT/environments/api/gitupstreams/$GIT_UPSTREAM_ID")

# In APP_RESPONSE calls
APP_RESPONSE=$(curl -s -X PUT \
    -H "Authorization: $TOKEN_FORMAT $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$APP_PAYLOAD" \
    "$API_ENDPOINT/catalog/api/applications/$EXISTING_APP_ID")

APP_RESPONSE=$(curl -s -X POST \
    -H "Authorization: $TOKEN_FORMAT $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$APP_PAYLOAD" \
    "$API_ENDPOINT/catalog/api/applications")

# In GIT_UPSTREAM_RESPONSE call
GIT_UPSTREAM_RESPONSE=$(curl -s -X POST \
    -H "Authorization: $TOKEN_FORMAT $TOKEN" \
    -H "Content-Type: application/json" \
    -d "$GIT_UPSTREAM_PAYLOAD" \
    "$API_ENDPOINT/catalog/api/gitupstreams")

# Start migration
log_message "Starting environment to catalog migration"
log_message "API Endpoint: $API_ENDPOINT"
log_message "Source Cluster: $CLUSTER_NAME"
log_message "Destination Cluster: $DESTINATION_CLUSTER"

# Validate token before proceeding - commenting out for now
# if ! validate_token; then
#     log_message "Error: Token validation failed. Exiting."
#     exit 1
# fi 