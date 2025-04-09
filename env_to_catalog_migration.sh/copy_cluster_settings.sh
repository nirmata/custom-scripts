#!/bin/bash

# Script to copy settings from source cluster to destination cluster
# Usage: ./copy_cluster_settings.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_CLUSTER> <DEST_CLUSTER>

set -e

# Check if required arguments are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <api-endpoint> <token> <source-cluster> <destination-cluster>"
    echo "Example: $0 https://pe420.nirmata.co \"token\" \"123-app-migration\" \"129-app-migration\""
    exit 1
fi

API_ENDPOINT=$1
TOKEN=$(echo "$2" | tr -d '\n')  # Remove any newlines from token
SOURCE_CLUSTER=$3
DEST_CLUSTER=$4

echo "Copying settings from $SOURCE_CLUSTER to $DEST_CLUSTER"

# Function to get environment details
get_env_details() {
    local env_name=$1
    echo "Fetching details for environment: $env_name"
    local response=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Debug output
    echo "API Response: $response"
    
    # Check if response is valid JSON
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

# Function to create environment if it doesn't exist
create_environment() {
    local env_name=$1
    local namespace=$2
    local cluster_id=$3
    
    echo "Checking if environment $env_name exists..."
    
    # Check if environment exists
    local response=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Accept: application/json")
    
    # Debug output
    echo "API Response for environment check: $response"
    
    # Check if environment exists
    local env_exists=$(echo "$response" | jq -r --arg name "$env_name" '.[] | select(.name == $name) | .id')
    
    if [ -z "$env_exists" ] || [ "$env_exists" = "null" ]; then
        echo "Environment $env_name does not exist. Creating..."
        
        # Create environment
        local create_response=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{
                \"name\": \"$env_name\",
                \"namespace\": \"$namespace\",
                \"cluster\": {
                    \"id\": \"$cluster_id\"
                }
            }")
        
        # Debug output
        echo "Create environment response: $create_response"
        
        if ! echo "$create_response" | jq -e . >/dev/null 2>&1; then
            echo "Error: Invalid JSON response when creating environment"
            echo "Response: $create_response"
            return 1
        fi
        
        echo "Environment $env_name created successfully"
    else
        echo "Environment $env_name already exists"
    fi
    
    return 0
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
    
    # Extract source environment details
    SOURCE_ENV_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.id')
    SOURCE_NAMESPACE=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.namespace')
    SOURCE_CLUSTER_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.cluster.id')
    
    echo "Source Environment ID: $SOURCE_ENV_ID"
    echo "Source Namespace: $SOURCE_NAMESPACE"
    echo "Source Cluster ID: $SOURCE_CLUSTER_ID"
    
    # Create destination environment if it doesn't exist
    create_environment "$dest_env" "$SOURCE_NAMESPACE" "$SOURCE_CLUSTER_ID"
    
    # Get destination environment details
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
    
    echo "Destination Environment ID: $DEST_ENV_ID"
    
    # 1. Copy Limit Ranges
    echo -e "\nCopying Limit Ranges..."
    SOURCE_LIMIT_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.limitRange[0].id')
    if [ "$SOURCE_LIMIT_ID" != "null" ] && [ ! -z "$SOURCE_LIMIT_ID" ]; then
        SOURCE_LIMIT=$(curl -s -X GET "$API_ENDPOINT/environments/api/limitRanges/$SOURCE_LIMIT_ID" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Accept: application/json")
        
        # Debug output
        echo "Source Limit Range: $SOURCE_LIMIT"
        
        # Create new limit range
        echo "Creating limit range..."
        LIMIT_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/limitRange" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(echo "$SOURCE_LIMIT" | jq 'del(.id, .uri, .generation, .modifiedOn, .createdOn)')")
        
        # Debug output
        echo "Create Limit Range Response: $LIMIT_RESPONSE"
    else
        echo "No limit range found in source environment"
    fi
    
    # 2. Copy Resource Quotas
    echo -e "\nCopying Resource Quotas..."
    SOURCE_QUOTA_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.resourceQuota[0].id')
    if [ "$SOURCE_QUOTA_ID" != "null" ] && [ ! -z "$SOURCE_QUOTA_ID" ]; then
        SOURCE_QUOTA=$(curl -s -X GET "$API_ENDPOINT/environments/api/resourceQuota/$SOURCE_QUOTA_ID" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Accept: application/json")
        
        # Debug output
        echo "Source Resource Quota: $SOURCE_QUOTA"
        
        # Create new quota
        echo "Creating resource quota..."
        QUOTA_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/resourceQuota" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(echo "$SOURCE_QUOTA" | jq 'del(.id, .uri, .generation, .modifiedOn, .createdOn)')")
        
        # Debug output
        echo "Create Resource Quota Response: $QUOTA_RESPONSE"
    else
        echo "No resource quota found in source environment"
    fi
    
    # 3. Copy Access Controls
    echo -e "\nCopying Access Controls..."
    SOURCE_ACL_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.accessControlList[0].id')
    DEST_ACL_ID=$(echo "$DEST_ENV_DETAILS" | jq -r '.accessControlList[0].id')
    
    if [ "$SOURCE_ACL_ID" != "null" ] && [ ! -z "$SOURCE_ACL_ID" ]; then
        # Get source ACL details
        SOURCE_ACL=$(curl -s -X GET "$API_ENDPOINT/environments/api/accessControlLists/$SOURCE_ACL_ID" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Accept: application/json")
        
        # Debug output
        echo "Source ACL: $SOURCE_ACL"
        
        # Delete existing access controls in destination
        if [ "$DEST_ACL_ID" != "null" ] && [ ! -z "$DEST_ACL_ID" ]; then
            echo "Deleting existing access controls in destination..."
            DELETE_RESPONSE=$(curl -s -X DELETE "$API_ENDPOINT/environments/api/accessControlLists/$DEST_ACL_ID/accessControls" \
                -H "Authorization: NIRMATA-API $TOKEN")
            
            # Debug output
            echo "Delete Access Controls Response: $DELETE_RESPONSE"
        fi
        
        # Copy each access control
        echo "$SOURCE_ACL" | jq -c '.accessControls[]?' | while read -r control; do
            if [ -z "$control" ] || [ "$control" = "null" ]; then
                continue
            fi
            
            TEAM_ID=$(echo "$control" | jq -r '.entityId // empty')
            TEAM_NAME=$(echo "$control" | jq -r '.entityName // empty')
            PERMISSION=$(echo "$control" | jq -r '.permission // empty')
            
            if [ -z "$TEAM_ID" ] || [ -z "$PERMISSION" ]; then
                echo "Warning: Skipping invalid control entry (missing team ID or permission)"
                continue
            fi
            
            echo "Setting permission for team $TEAM_NAME ($TEAM_ID): $PERMISSION"
            
            # Create JSON payload
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
            
            # Debug output
            echo "Access Control Payload: $PAYLOAD"
            
            # Set permission
            ACL_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/accessControlLists/$DEST_ACL_ID/accessControls" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                -H "Content-Type: application/json" \
                -d "$PAYLOAD")
            
            # Debug output
            echo "Create Access Control Response: $ACL_RESPONSE"
        done
    else
        echo "No access controls found in source environment"
    fi
    
    # 4. Copy Update Policy
    echo -e "\nCopying Update Policy..."
    SOURCE_POLICY_ID=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.updatePolicy[0].id')
    if [ "$SOURCE_POLICY_ID" != "null" ] && [ ! -z "$SOURCE_POLICY_ID" ]; then
        SOURCE_POLICY=$(curl -s -X GET "$API_ENDPOINT/environments/api/updatePolicies/$SOURCE_POLICY_ID" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Accept: application/json")
        
        # Debug output
        echo "Source Update Policy: $SOURCE_POLICY"
        
        # Create new policy
        echo "Creating update policy..."
        POLICY_RESPONSE=$(curl -s -X POST "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID/updatePolicy" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            -d "$(echo "$SOURCE_POLICY" | jq 'del(.id, .uri, .generation, .modifiedOn, .createdOn)')")
        
        # Debug output
        echo "Create Update Policy Response: $POLICY_RESPONSE"
    else
        echo "No update policy found in source environment"
    fi
    
    # 5. Copy Labels
    echo -e "\nCopying Labels..."
    SOURCE_LABELS=$(echo "$SOURCE_ENV_DETAILS" | jq -r '.labels')
    if [ "$SOURCE_LABELS" != "null" ] && [ ! -z "$SOURCE_LABELS" ]; then
        echo "Updating labels..."
        LABELS_RESPONSE=$(curl -s -X PUT "$API_ENDPOINT/environments/api/environments/$DEST_ENV_ID" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -H "Content-Type: application/json" \
            -d "{\"labels\":$SOURCE_LABELS}")
        
        # Debug output
        echo "Update Labels Response: $LABELS_RESPONSE"
    else
        echo "No labels found in source environment"
    fi
    
    echo "Settings copied successfully from $source_env to $dest_env"
    return 0
}

# Get all environments
echo "Fetching environments..."
ENVIRONMENTS=$(curl -s -X GET "$API_ENDPOINT/environments/api/environments" \
    -H "Authorization: NIRMATA-API $TOKEN" \
    -H "Accept: application/json")

# Debug output
echo "Environments API Response: $ENVIRONMENTS"

# Process each environment in the source cluster
echo "$ENVIRONMENTS" | jq -c '.[]' | while read -r env; do
    ENV_NAME=$(echo "$env" | jq -r '.name')
    CLUSTER_NAME=$(echo "$env" | jq -r '.clusterName // "null"')
    
    # Check if environment belongs to source cluster
    if [[ "$ENV_NAME" == *"-$SOURCE_CLUSTER" ]]; then
        # Get the base name without cluster suffix
        BASE_NAME=$(echo "$ENV_NAME" | sed "s/-$SOURCE_CLUSTER$//")
        DEST_ENV_NAME="${BASE_NAME}-${DEST_CLUSTER}"
        
        echo "Processing environment: $ENV_NAME -> $DEST_ENV_NAME"
        copy_settings "$ENV_NAME" "$DEST_ENV_NAME"
    fi
done

echo "All settings copied successfully!" 