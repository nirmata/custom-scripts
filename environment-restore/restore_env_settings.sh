#!/bin/bash

API_ENDPOINT=$1
API_TOKEN=$2
SOURCE_CLUSTER=$3
DEST_CLUSTER=$4

echo "Monitoring environments for restored namespaces..."
echo "Source cluster: $SOURCE_CLUSTER"
echo "Destination cluster: $DEST_CLUSTER"

# Function to get environment details
get_env_details() {
    local env_name=$1
    echo "Fetching details for environment: $env_name"
    local response=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json")
    
    if ! echo "$response" | jq -e . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response from API"
        echo "Response: $response"
        return 1
    fi
    
    local details=$(echo "$response" | jq -r --arg name "$env_name" '.[] | select(.name == $name)')
    if [ -z "$details" ]; then
        echo "Warning: No environment found with name $env_name"
        return 1
    fi
    echo "$details"
}

# Function to wait for resource to be ready
wait_for_resource() {
    local resource_type=$1
    local resource_id=$2
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for $resource_type to be ready..."
    while [ $attempt -le $max_attempts ]; do
        local response=$(curl -s -X GET "$API_ENDPOINT/environments/api/$resource_type/$resource_id" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
            
        if ! echo "$response" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response from API"
            echo "Response: $response"
            return 1
        fi
        
        local status=$(echo "$response" | jq -r '.syncState')
        
        if [ "$status" = "applied" ]; then
            echo "$resource_type is ready"
            return 0
        fi
        
        echo "Attempt $attempt: $resource_type status is $status, waiting..."
        sleep 10
        attempt=$((attempt + 1))
    done
    
    echo "Timeout waiting for $resource_type to be ready"
    return 1
}

# Function to copy settings from source to destination environment
copy_settings() {
    local source_env=$1
    local dest_env=$2
    
    echo "Copying settings from $source_env to $dest_env"
    
    # Get environment details
    SOURCE_ENV_DETAILS=$(get_env_details "$source_env")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get source environment details"
        return 1
    fi
    SOURCE_ENV_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.id')
    
    DEST_ENV_DETAILS=$(get_env_details "$dest_env")
    if [ $? -ne 0 ]; then
        echo "Error: Failed to get destination environment details"
        return 1
    fi
    DEST_ENV_ID=$(echo "$DEST_ENV_DETAILS" | jq -r '.id')
    
    if [ -z "$SOURCE_ENV_ID" ] || [ -z "$DEST_ENV_ID" ]; then
        echo "Error: Could not find source or destination environment"
        return 1
    fi
    
    echo "Source Environment ID: $SOURCE_ENV_ID"
    echo "Destination Environment ID: $DEST_ENV_ID"
    
    # 1. Copy Limit Ranges first (required before Resource Quota)
    echo -e "\nCopying Limit Ranges..."
    SOURCE_LIMIT_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.limitRange[0].id')
    if [ "$SOURCE_LIMIT_ID" != "null" ] && [ ! -z "$SOURCE_LIMIT_ID" ]; then
        SOURCE_LIMIT=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRanges/$SOURCE_LIMIT_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        if ! echo "$SOURCE_LIMIT" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response for limit range"
            echo "Response: $SOURCE_LIMIT"
            return 1
        fi
        
        # Get the limit range spec details
        LIMIT_SPEC_ID=$(echo "$SOURCE_LIMIT" | jq -r '.spec[0].id')
        LIMIT_SPEC=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRangeSpecs/$LIMIT_SPEC_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        if ! echo "$LIMIT_SPEC" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response for limit range spec"
            echo "Response: $LIMIT_SPEC"
            return 1
        fi
        
        # Get the limit range items
        LIMIT_ITEM_ID=$(echo "$LIMIT_SPEC" | jq -r '.limits[0].id')
        LIMIT_ITEM=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRangeItems/$LIMIT_ITEM_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        if ! echo "$LIMIT_ITEM" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response for limit range item"
            echo "Response: $LIMIT_ITEM"
            return 1
        fi
        
        # Create new limit range with proper structure
        echo "Creating limit range..."
        LIMIT_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/limitRange" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"micro\",
                \"kind\": \"LimitRange\",
                \"apiVersion\": \"v1\",
                \"spec\": {
                    \"limits\": [{
                        \"type\": \"Container\",
                        \"defaultLimit\": $(echo "$LIMIT_ITEM" | jq '.defaultLimit'),
                        \"defaultRequest\": $(echo "$LIMIT_ITEM" | jq '.defaultRequest')
                    }]
                }
            }")
        
        if ! echo "$LIMIT_RESPONSE" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response when creating limit range"
            echo "Response: $LIMIT_RESPONSE"
            return 1
        fi
        
        NEW_LIMIT_ID=$(echo "$LIMIT_RESPONSE" | jq -r '.id')
        if [ ! -z "$NEW_LIMIT_ID" ] && [ "$NEW_LIMIT_ID" != "null" ]; then
            wait_for_resource "limitRanges" "$NEW_LIMIT_ID"
        fi
    fi
    
    # 2. Copy Resource Quotas (after Limit Range is ready)
    echo -e "\nCopying Resource Quotas..."
    SOURCE_QUOTA_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.resourceQuota[0].id')
    if [ "$SOURCE_QUOTA_ID" != "null" ] && [ ! -z "$SOURCE_QUOTA_ID" ]; then
        SOURCE_QUOTA=$(curl -s -X GET "$API_ENDPOINT/environments/api/resourceQuota/$SOURCE_QUOTA_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        if ! echo "$SOURCE_QUOTA" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response for resource quota"
            echo "Response: $SOURCE_QUOTA"
            return 1
        fi
        
        # Get the quota spec details
        QUOTA_SPEC_ID=$(echo "$SOURCE_QUOTA" | jq -r '.spec[0].id')
        QUOTA_SPEC=$(curl -s -X GET "$API_ENDPOINT/environments/api/resourceQuotaSpecs/$QUOTA_SPEC_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        if ! echo "$QUOTA_SPEC" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response for resource quota spec"
            echo "Response: $QUOTA_SPEC"
            return 1
        fi
        
        # Create new quota with proper structure
        echo "Creating resource quota..."
        QUOTA_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/resourceQuota" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"micro\",
                \"kind\": \"ResourceQuota\",
                \"apiVersion\": \"v1\",
                \"spec\": {
                    \"hard\": $(echo "$QUOTA_SPEC" | jq '.hard')
                }
            }")
        
        if ! echo "$QUOTA_RESPONSE" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response when creating resource quota"
            echo "Response: $QUOTA_RESPONSE"
            return 1
        fi
        
        NEW_QUOTA_ID=$(echo "$QUOTA_RESPONSE" | jq -r '.id')
        if [ ! -z "$NEW_QUOTA_ID" ] && [ "$NEW_QUOTA_ID" != "null" ]; then
            wait_for_resource "resourceQuota" "$NEW_QUOTA_ID"
        fi
    fi
    
    # 3. Copy Access Controls
    echo -e "\nCopying Access Controls..."
    SOURCE_ACL_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.accessControlList[0].id')
    DEST_ACL_ID=$(echo "$DEST_ENV_DETAILS" | jq -r '.accessControlList[0].id')
    
    if [ "$SOURCE_ACL_ID" != "null" ] && [ ! -z "$SOURCE_ACL_ID" ]; then
        SOURCE_ACL=$(curl -s -X GET "$API_ENDPOINT/environments/api/accessControlLists/$SOURCE_ACL_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        # Get teams info
        TEAMS=$(curl -s -X GET "$API_ENDPOINT/users/api/teams" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        # Copy each access control
        echo "$SOURCE_ACL" | jq -c '.accessControls[]?' | while read -r control; do
            if [ -z "$control" ] || [ "$control" = "null" ]; then
                continue
            fi
            
            # Extract values with proper JSON handling
            TEAM_ID=$(echo "$control" | jq -r '.entityId // empty')
            TEAM_NAME=$(echo "$control" | jq -r '.entityName // empty')
            PERMISSION=$(echo "$control" | jq -r '.permission // empty')
            
            if [ -z "$TEAM_ID" ] || [ -z "$PERMISSION" ]; then
                echo "Warning: Skipping invalid control entry (missing team ID or permission)"
                continue
            fi
            
            echo "Setting permission for team $TEAM_NAME ($TEAM_ID): $PERMISSION"
            
            # Create JSON payload properly
            PAYLOAD=$(jq -n \
                --arg team_id "$TEAM_ID" \
                --arg team_name "$TEAM_NAME" \
                --arg perm "$PERMISSION" \
                '{
                    "entityId": $team_id,
                    "entityType": "team",
                    "permission": $perm,
                    "entityName": $team_name
                }')
            
            curl -s -X POST "$API_ENDPOINT/environments/api/accessControlLists/$DEST_ACL_ID/accessControls" \
                -H "Authorization: NIRMATA-API $API_TOKEN" \
                -H "Content-Type: application/json" \
                -d "$PAYLOAD"
        done
    fi
    
    # 4. Copy Update Policy
    echo -e "\nCopying Update Policy..."
    SOURCE_POLICY_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.updatePolicy[0].id')
    if [ "$SOURCE_POLICY_ID" != "null" ] && [ ! -z "$SOURCE_POLICY_ID" ]; then
        SOURCE_POLICY=$(curl -s -X GET "$API_ENDPOINT/environments/api/updatePolicies/$SOURCE_POLICY_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Accept: application/json")
        
        POLICY_SPEC=$(echo "$SOURCE_POLICY" | jq 'del(.id, .parent, .ancestors, .createdBy, .createdOn, .modifiedBy, .modifiedOn, .generation, .uri, .service, .modelIndex)')
        
        echo "Creating update policy..."
        curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/updatePolicy" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "$POLICY_SPEC"
    fi
    
    # 5. Copy Labels
    echo -e "\nCopying Labels..."
    SOURCE_LABELS=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.labels')
    if [ "$SOURCE_LABELS" != "null" ] && [ ! -z "$SOURCE_LABELS" ]; then
        echo "Updating labels..."
        curl -s -X PUT "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID" \
            -H "Authorization: NIRMATA-API $API_TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"labels\":$SOURCE_LABELS}"
    fi
    
    echo -e "\nSettings copied successfully from $source_env to $dest_env!"
    return 0
}

# Main loop
while true; do
    echo "Fetching all environments..."
    ALL_ENVS=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json")
    
    if ! echo "$ALL_ENVS" | jq -e . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response when fetching environments"
        echo "Response: $ALL_ENVS"
        sleep 30
        continue
    fi
    
    echo "Available environments:"
    echo "$ALL_ENVS" | jq -r '.[] | "Name: \(.name), Cluster: \(.clusterName // "null"), Namespace: \(.namespace)"'
    
    # Process environments
    echo "$ALL_ENVS" | jq -c '.[]' | while read -r env; do
        NAMESPACE=$(echo "$env" | jq -r '.namespace')
        CLUSTER_NAME=$(echo "$env" | jq -r '.clusterName // "null"')
        ENV_NAME=$(echo "$env" | jq -r '.name')
        
        echo "Processing environment: $ENV_NAME (Namespace: $NAMESPACE, Cluster: $CLUSTER_NAME)"
        
        # Skip system namespaces except nirmata
        if [[ "$NAMESPACE" =~ ^(kube-system|kube-public|kube-node-lease|ingress-haproxy)$ ]]; then
            echo "Skipping system namespace: $NAMESPACE"
            continue
        fi
        
        # If this is an environment in the destination cluster
        if [ "$CLUSTER_NAME" = "$DEST_CLUSTER" ]; then
            echo "Found environment in destination cluster: $ENV_NAME"
            SOURCE_ENV_NAME="${NAMESPACE}-${SOURCE_CLUSTER}"
            echo "Looking for source environment: $SOURCE_ENV_NAME"
            SOURCE_ENV=$(echo "$ALL_ENVS" | jq -r --arg name "$SOURCE_ENV_NAME" '.[] | select(.name == $name) | .name')
            
            if [ ! -z "$SOURCE_ENV" ] && [ "$SOURCE_ENV" != "null" ]; then
                echo "Found matching source environment: $SOURCE_ENV"
                PROCESSED_FILE="/tmp/processed_envs_${NAMESPACE}"
                if [ ! -f "$PROCESSED_FILE" ]; then
                    echo "Found restored environment: $ENV_NAME"
                    echo "Source environment: $SOURCE_ENV"
                    
                    if copy_settings "$SOURCE_ENV" "$ENV_NAME"; then
                        touch "$PROCESSED_FILE"
                    else
                        echo "Error: Failed to copy settings from $SOURCE_ENV to $ENV_NAME"
                    fi
                else
                    echo "Environment $ENV_NAME already processed (found $PROCESSED_FILE)"
                fi
            else
                echo "No matching source environment found for $ENV_NAME"
            fi
        fi
    done
    
    echo "Sleeping for 30 seconds before next check..."
    sleep 30
done 