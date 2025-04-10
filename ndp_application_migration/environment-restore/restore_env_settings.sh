#!/bin/bash

# Check if required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <api_endpoint> <token> <source_cluster> <destination_cluster>"
    exit 1
fi

API_ENDPOINT=$1
TOKEN=$2
SOURCE_CLUSTER=$3
DEST_CLUSTER=$4

# Create logs directory if it doesn't exist
LOG_DIR="logs"
mkdir -p "$LOG_DIR"

# Create log file with timestamp
LOG_FILE="${LOG_DIR}/env_restore_$(date '+%Y%m%d_%H%M%S').log"
SUMMARY_FILE="${LOG_DIR}/env_restore_summary_$(date '+%Y%m%d_%H%M%S').log"

# Function to log messages with timestamp
log_message() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message"
    echo "$message" >> "$LOG_FILE"
}

# Function to log summary
log_summary() {
    local message="[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    echo "$message" >> "$SUMMARY_FILE"
}

# Initialize summary counters
TOTAL_ENVIRONMENTS=0
SUCCESSFUL_COPIES=0
SKIPPED_ENVIRONMENTS=0
FAILED_COPIES=0

log_message "Starting environment settings restoration from $SOURCE_CLUSTER to $DEST_CLUSTER"
log_summary "Environment Settings Restoration Summary"
log_summary "Source Cluster: $SOURCE_CLUSTER"
log_summary "Destination Cluster: $DEST_CLUSTER"
log_summary "----------------------------------------"

# Validate token
if [ -z "$TOKEN" ]; then
    log_message "Error: Token is required"
    exit 1
fi

# Get all clusters
CLUSTERS_RESPONSE=$(curl -s -H "Accept: application/json" \
    -H "Authorization: NIRMATA-API ${TOKEN}" \
    "${API_ENDPOINT}/environments/api/clusters")

# Check if unauthorized
if echo "$CLUSTERS_RESPONSE" | grep -q "Not authorized"; then
    log_message "Error: Not authorized. Please check your token."
    log_message "Response: $CLUSTERS_RESPONSE"
    exit 1
fi

# Check if response is valid JSON
if ! echo "$CLUSTERS_RESPONSE" | jq '.' >/dev/null 2>&1; then
    log_message "Error: Invalid JSON response from clusters API"
    log_message "Response: $CLUSTERS_RESPONSE"
    exit 1
fi

# Get cluster IDs using the correct JSON path
SOURCE_CLUSTER_ID=$(echo "$CLUSTERS_RESPONSE" | jq -r --arg name "$SOURCE_CLUSTER" '.[] | select(.name == $name) | .id')
DEST_CLUSTER_ID=$(echo "$CLUSTERS_RESPONSE" | jq -r --arg name "$DEST_CLUSTER" '.[] | select(.name == $name) | .id')

if [ -z "$SOURCE_CLUSTER_ID" ] || [ -z "$DEST_CLUSTER_ID" ]; then
    log_message "Error: Could not find cluster IDs"
    log_message "Source cluster ($SOURCE_CLUSTER): $SOURCE_CLUSTER_ID"
    log_message "Destination cluster ($DEST_CLUSTER): $DEST_CLUSTER_ID"
    log_message "Available clusters:"
    echo "$CLUSTERS_RESPONSE" | jq -r '.[].name'
    exit 1
fi

log_message "Source cluster ID: $SOURCE_CLUSTER_ID"
log_message "Destination cluster ID: $DEST_CLUSTER_ID"

# Get all environments
ENVIRONMENTS_RESPONSE=$(curl -s -H "Accept: application/json" \
    -H "Authorization: NIRMATA-API $TOKEN" \
    "${API_ENDPOINT}/environments/api/environments")

# Check if response is valid JSON
if ! echo "$ENVIRONMENTS_RESPONSE" | jq '.' >/dev/null 2>&1; then
    log_message "Error: Invalid JSON response from environments API"
    log_message "Response: $ENVIRONMENTS_RESPONSE"
    exit 1
fi

ENVIRONMENTS="$ENVIRONMENTS_RESPONSE"

# Get source environments using the correct JSON path
SOURCE_ENVIRONMENTS=$(echo "$ENVIRONMENTS_RESPONSE" | jq -r --arg cluster "$SOURCE_CLUSTER_ID" '.[] | select(.cluster[].id == $cluster)')

# Debug output
echo "All environments:"
echo "$ENVIRONMENTS" | jq '.'
echo "Source cluster ID: $SOURCE_CLUSTER_ID"
echo "Source environments:"
echo "$SOURCE_ENVIRONMENTS" | jq '.'

if [ -z "$SOURCE_ENVIRONMENTS" ]; then
    log_message "No environments found in source cluster $SOURCE_CLUSTER"
    log_message "Source cluster ID: $SOURCE_CLUSTER_ID"
    log_message "Available environments:"
    echo "$ENVIRONMENTS_RESPONSE" | jq -r '.[].name'
    exit 1
fi

# Function to get team rolebindings
get_team_rolebindings() {
    local env_id=$1
    local response
    response=$(curl -s -H "Authorization: NIRMATA-API $TOKEN" \
        "$API_ENDPOINT/environments/api/environments/$env_id/teamrolebindings?fields=id,name,team,role")
    
    if [ $? -ne 0 ]; then
        log_message "Error: Failed to get team rolebindings for environment $env_id"
        return 1
    fi
    
    echo "$response"
}

# Function to create team rolebinding
create_team_rolebinding() {
    local env_id=$1
    local team_id=$2
    local role_id=$3
    local team_name=$4
    local permission=$5
    
    log_message "Creating team rolebinding for team $team_name with permission $permission"
    
    # Create payload for team rolebinding
    local payload="{
        \"modelIndex\": \"TeamRoleBinding\",
        \"parent\": {
            \"id\": \"$env_id\",
            \"service\": \"Environment\",
            \"modelIndex\": \"Environment\",
            \"childRelation\": \"teamrolebindings\"
        },
        \"team\": \"$team_id\",
        \"role\": \"$role_id\",
        \"permission\": \"$permission\"
    }"
    
    curl -s -X POST -H "Authorization: NIRMATA-API $TOKEN" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "$API_ENDPOINT/environments/api/environments/$env_id/teamrolebindings"
    
    log_message "Created team rolebinding for team $team_name"
}

# Function to copy team rolebindings
copy_team_rolebindings() {
    local source_env_id=$1
    local dest_env_id=$2
    local source_env_name=$3
    local dest_env_name=$4
    
    log_message "Copying team rolebindings from $source_env_name to $dest_env_name"
    
    # Get source ACL ID
    SOURCE_ACL_ID=$(curl -s -H "Accept: application/json" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        "${API_ENDPOINT}/environments/api/environments/$source_env_id" | jq -r '.accessControlList[0].id')

    if [ ! -z "$SOURCE_ACL_ID" ] && [ "$SOURCE_ACL_ID" != "null" ]; then
        # Get source ACL details
        SOURCE_ACL_DETAILS=$(curl -s -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            "${API_ENDPOINT}/environments/api/accessControlLists/$SOURCE_ACL_ID")
        
        # Get access control IDs
        ACCESS_CONTROL_IDS=$(echo "$SOURCE_ACL_DETAILS" | jq -r '.accessControls[].id')
        
        # Process each access control
        for control_id in $ACCESS_CONTROL_IDS; do
            # Get access control details
            CONTROL_DETAILS=$(curl -s -H "Accept: application/json" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                "${API_ENDPOINT}/environments/api/accessControls/$control_id")
            
            ENTITY_ID=$(echo "$CONTROL_DETAILS" | jq -r '.entityId')
            ENTITY_TYPE=$(echo "$CONTROL_DETAILS" | jq -r '.entityType')
            PERMISSION=$(echo "$CONTROL_DETAILS" | jq -r '.permission')
            ENTITY_NAME=$(echo "$CONTROL_DETAILS" | jq -r '.entityName')
            
            if [ "$ENTITY_TYPE" = "team" ]; then
                log_message "Creating team rolebinding for team $ENTITY_NAME with permission $PERMISSION"
                
                # Create team rolebinding payload
                local payload="{
                    \"modelIndex\": \"TeamRoleBinding\",
                    \"parent\": {
                        \"id\": \"$dest_env_id\",
                        \"service\": \"Environment\",
                        \"modelIndex\": \"Environment\",
                        \"childRelation\": \"teamrolebindings\"
                    },
                    \"team\": \"$ENTITY_ID\",
                    \"role\": \"$PERMISSION\",
                    \"name\": \"$ENTITY_NAME-$PERMISSION\"
                }"
                
                # Create team rolebinding
                local response=$(curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Authorization: NIRMATA-API $TOKEN" \
                    -d "$payload" \
                    "${API_ENDPOINT}/environments/api/environments/$dest_env_id/teamrolebindings")
                
                if [ ! -z "$response" ]; then
                    log_message "Successfully created team rolebinding for team $ENTITY_NAME"
                else
                    log_message "Failed to create team rolebinding for team $ENTITY_NAME"
                fi
            fi
        done
    fi
}

# Function to copy environment settings
copy_environment_settings() {
    local source_env_id=$1
    local dest_env_id=$2
    local source_env_name=$3
    local dest_env_name=$4
    
    # ... existing code ...
    
    # Copy team rolebindings
    copy_team_rolebindings "$source_env_id" "$dest_env_id" "$source_env_name" "$dest_env_name"
    
    # ... existing code ...
}

# Process each environment
echo "$SOURCE_ENVIRONMENTS" | jq -c '.' | while read -r env; do
    ENV_NAME=$(echo "$env" | jq -r '.name')
    SOURCE_ENV_ID=$(echo "$env" | jq -r '.id')
    TOTAL_ENVIRONMENTS=$((TOTAL_ENVIRONMENTS + 1))
    
    # Determine destination environment name based on naming pattern
    if [[ "$ENV_NAME" == "new-migration" ]]; then
        # Special case for new-migration environment
        DEST_ENV_NAME="new-migration-${DEST_CLUSTER}"
    elif [[ "$ENV_NAME" == *"$SOURCE_CLUSTER" ]]; then
        # Environment has source cluster suffix
        DEST_ENV_NAME="${ENV_NAME%$SOURCE_CLUSTER}$DEST_CLUSTER"
    else
        # Environment doesn't have cluster suffix
        DEST_ENV_NAME="${ENV_NAME}-${DEST_CLUSTER}"
    fi
    
    log_message "Processing environment: $ENV_NAME -> $DEST_ENV_NAME"
    
    # Check if destination environment exists
    DEST_ENV=$(echo "$ENVIRONMENTS" | jq -r --arg name "$DEST_ENV_NAME" '.[] | select(.name == $name)')
    
    if [ -z "$DEST_ENV" ]; then
        log_message "Destination environment $DEST_ENV_NAME not found."
        FAILED_COPIES=$((FAILED_COPIES + 1))
        log_summary "FAILED: $ENV_NAME -> $DEST_ENV_NAME (Environment not found)"
        continue
    fi
    
    DEST_ENV_ID=$(echo "$DEST_ENV" | jq -r '.id')
    
    log_message "Source ID: $SOURCE_ENV_ID"
    log_message "Destination ID: $DEST_ENV_ID"
    
    # Copy resource type
    RESOURCE_TYPE=$(echo "$env" | jq -r '.resourceType')
    if [ ! -z "$RESOURCE_TYPE" ] && [ "$RESOURCE_TYPE" != "null" ]; then
        log_message "Copying resource type: $RESOURCE_TYPE"
        curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "{\"resourceType\":\"$RESOURCE_TYPE\"}" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID"
    fi
    
    # Copy ACLs and permissions
    SOURCE_ACL_ID=$(echo "$env" | jq -r '.accessControlList[0].id')
    if [ -z "$SOURCE_ACL_ID" ] || [ "$SOURCE_ACL_ID" = "null" ]; then
        log_message "No access control list found in source environment"
    else
        log_message "Source ACL ID: $SOURCE_ACL_ID"
        
        # Get source ACL details
        SOURCE_ACL_DETAILS=$(curl -s -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            "${API_ENDPOINT}/environments/api/accessControlLists/$SOURCE_ACL_ID")
        
        # Get destination ACL ID
        DEST_ENV_DETAILS=$(curl -s -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID")
        
        DEST_ACL_ID=$(echo "$DEST_ENV_DETAILS" | jq -r '.accessControlList[0].id')
        
        if [ -z "$DEST_ACL_ID" ] || [ "$DEST_ACL_ID" = "null" ]; then
            log_message "No access control list found in destination environment"
        else
            log_message "Destination ACL ID: $DEST_ACL_ID"
            
            # Get and copy access controls
            ACCESS_CONTROLS=$(echo "$SOURCE_ACL_DETAILS" | jq -r '.accessControls[]?.id')
            
            if [ ! -z "$ACCESS_CONTROLS" ] && [ "$ACCESS_CONTROLS" != "null" ]; then
                echo "$ACCESS_CONTROLS" | while read -r control_id; do
                    if [ ! -z "$control_id" ] && [ "$control_id" != "null" ]; then
                        # Get control details
                        CONTROL_DETAILS=$(curl -s -H "Accept: application/json" \
                            -H "Authorization: NIRMATA-API $TOKEN" \
                            "${API_ENDPOINT}/environments/api/accessControls/$control_id")
                        
                        TEAM_ID=$(echo "$CONTROL_DETAILS" | jq -r '.entityId')
                        TEAM_NAME=$(echo "$CONTROL_DETAILS" | jq -r '.entityName')
                        PERMISSION=$(echo "$CONTROL_DETAILS" | jq -r '.permission')
                        
                        if [ ! -z "$TEAM_ID" ] && [ ! -z "$TEAM_NAME" ] && [ ! -z "$PERMISSION" ]; then
                            log_message "Creating ACL for team $TEAM_NAME ($TEAM_ID) with permission $PERMISSION"
                            ACL_RESPONSE=$(curl -s -X POST \
                                -H "Content-Type: application/json" \
                                -H "Accept: application/json" \
                                -H "Authorization: NIRMATA-API $TOKEN" \
                                -d "{\"entityId\":\"$TEAM_ID\",\"entityType\":\"team\",\"permission\":\"$PERMISSION\",\"entityName\":\"$TEAM_NAME\"}" \
                                "${API_ENDPOINT}/environments/api/accessControlLists/$DEST_ACL_ID/accessControls")
                            
                            # Check if ACL was created successfully
                            if [ ! -z "$ACL_RESPONSE" ]; then
                                log_message "Successfully created ACL for team $TEAM_NAME"
                            else
                                log_message "Failed to create ACL for team $TEAM_NAME"
                            fi
                        else
                            log_message "Missing required ACL information for control ID: $control_id"
                        fi
                    fi
                done
            else
                log_message "No access controls found in source ACL"
            fi
        fi
    fi
    
    # Copy resource quotas
    log_message "Copying resource quotas..."
    SOURCE_QUOTAS=$(curl -s -H "Authorization: NIRMATA-API ${TOKEN}" \
        "${API_ENDPOINT}/environments/api/environments/${SOURCE_ENV_ID}/resourceQuota" | jq -r '.[]')
    
    if [ ! -z "$SOURCE_QUOTAS" ]; then
        echo "$SOURCE_QUOTAS" | jq -c '.' | while read -r quota; do
            QUOTA_NAME=$(echo "$quota" | jq -r '.name')
            QUOTA_SPEC=$(echo "$quota" | jq -r '.spec')
            
            if [ ! -z "$QUOTA_NAME" ] && [ ! -z "$QUOTA_SPEC" ] && [ "$QUOTA_SPEC" != "null" ]; then
                log_message "Creating quota: $QUOTA_NAME"
                
                # Extract all quota values
                # Check if the 'hard' field exists and has the right structure
                if echo "$QUOTA_SPEC" | jq -e '.hard' > /dev/null 2>&1; then
                    # Standard structure extraction
                    CPU=$(echo "$QUOTA_SPEC" | jq -r '.hard."cpu" // empty')
                    MEMORY=$(echo "$QUOTA_SPEC" | jq -r '.hard."memory" // empty')
                    EPHEMERAL_STORAGE=$(echo "$QUOTA_SPEC" | jq -r '.hard."ephemeral-storage" // empty')
                    REQUESTS_MEMORY=$(echo "$QUOTA_SPEC" | jq -r '.hard."requests.memory" // empty')
                    REQUESTS_CPU=$(echo "$QUOTA_SPEC" | jq -r '.hard."requests.cpu" // empty')
                    REQUESTS_EPHEMERAL_STORAGE=$(echo "$QUOTA_SPEC" | jq -r '.hard."requests.ephemeral-storage" // empty')
                    LIMITS_CPU=$(echo "$QUOTA_SPEC" | jq -r '.hard."limits.cpu" // empty')
                    LIMITS_MEMORY=$(echo "$QUOTA_SPEC" | jq -r '.hard."limits.memory" // empty')
                    LIMITS_EPHEMERAL_STORAGE=$(echo "$QUOTA_SPEC" | jq -r '.hard."limits.ephemeral-storage" // empty')
                else
                    # Handle alternative structure or missing fields
                    log_message "Quota has non-standard structure or is missing 'hard' field. Creating basic quota."
                    CPU=""
                    MEMORY=""
                    EPHEMERAL_STORAGE=""
                    REQUESTS_MEMORY=""
                    REQUESTS_CPU=""
                    REQUESTS_EPHEMERAL_STORAGE=""
                    LIMITS_CPU=""
                    LIMITS_MEMORY=""
                    LIMITS_EPHEMERAL_STORAGE=""
                fi
                
                # Build quota spec with all resources
                QUOTA_PAYLOAD="{
                    \"name\": \"${QUOTA_NAME}\",
                    \"spec\": {
                        \"hard\": {"
                
                # Add resources only if they exist
                FIRST=true
                if [ "$CPU" != "null" ]; then
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"cpu\": \"${CPU}\""
                    FIRST=false
                fi
                
                if [ "$MEMORY" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"memory\": \"${MEMORY}\""
                    FIRST=false
                fi
                
                if [ "$EPHEMERAL_STORAGE" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"ephemeral-storage\": \"${EPHEMERAL_STORAGE}\""
                    FIRST=false
                fi
                
                if [ "$REQUESTS_MEMORY" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"requests.memory\": \"${REQUESTS_MEMORY}\""
                    FIRST=false
                fi
                
                if [ "$REQUESTS_CPU" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"requests.cpu\": \"${REQUESTS_CPU}\""
                    FIRST=false
                fi
                
                if [ "$REQUESTS_EPHEMERAL_STORAGE" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"requests.ephemeral-storage\": \"${REQUESTS_EPHEMERAL_STORAGE}\""
                    FIRST=false
                fi
                
                if [ "$LIMITS_CPU" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"limits.cpu\": \"${LIMITS_CPU}\""
                    FIRST=false
                fi
                
                if [ "$LIMITS_MEMORY" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"limits.memory\": \"${LIMITS_MEMORY}\""
                    FIRST=false
                fi
                
                if [ "$LIMITS_EPHEMERAL_STORAGE" != "null" ]; then
                    if [ "$FIRST" = false ]; then QUOTA_PAYLOAD="${QUOTA_PAYLOAD},"; fi
                    QUOTA_PAYLOAD="${QUOTA_PAYLOAD}\"limits.ephemeral-storage\": \"${LIMITS_EPHEMERAL_STORAGE}\""
                fi
                
                QUOTA_PAYLOAD="${QUOTA_PAYLOAD}}}}}"
                
                log_message "Creating quota with payload: $QUOTA_PAYLOAD"
                
                QUOTA_RESPONSE=$(curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Authorization: NIRMATA-API ${TOKEN}" \
                    "${API_ENDPOINT}/environments/api/environments/${DEST_ENV_ID}/resourceQuota" \
                    -d "${QUOTA_PAYLOAD}")
                
                if [ ! -z "$QUOTA_RESPONSE" ]; then
                    log_message "Successfully created quota $QUOTA_NAME"
                    # Verify the quota was created correctly
                    VERIFY_QUOTA=$(curl -s -H "Authorization: NIRMATA-API ${TOKEN}" \
                        "${API_ENDPOINT}/environments/api/environments/${DEST_ENV_ID}/resourceQuota" | \
                        jq -r --arg name "$QUOTA_NAME" '.[] | select(.name == $name)')
                    if [ ! -z "$VERIFY_QUOTA" ]; then
                        log_message "Verified quota $QUOTA_NAME was created successfully"
                    else
                        log_message "Warning: Could not verify quota $QUOTA_NAME creation"
                    fi
                else
                    log_message "Failed to create quota $QUOTA_NAME"
                fi
            fi
        done
    else
        log_message "No resource quotas found in source environment"
    fi
    
    # Copy limit ranges
    log_message "Copying limit ranges..."
    SOURCE_LIMITS=$(curl -s -H "Authorization: NIRMATA-API ${TOKEN}" \
        "${API_ENDPOINT}/environments/api/environments/${SOURCE_ENV_ID}/limitRange" | jq -r '.[]')
    
    if [ ! -z "$SOURCE_LIMITS" ]; then
        echo "$SOURCE_LIMITS" | jq -c '.' | while read -r limit; do
            LIMIT_NAME=$(echo "$limit" | jq -r '.name')
            LIMIT_SPEC=$(echo "$limit" | jq -r '.spec')
            
            if [ ! -z "$LIMIT_NAME" ] && [ ! -z "$LIMIT_SPEC" ] && [ "$LIMIT_SPEC" != "null" ]; then
                log_message "Creating limit range: $LIMIT_NAME"
                LIMIT_PAYLOAD="{\"name\":\"${LIMIT_NAME}\",\"spec\":${LIMIT_SPEC}}"
                LIMIT_RESPONSE=$(curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Authorization: NIRMATA-API ${TOKEN}" \
                    "${API_ENDPOINT}/environments/api/environments/${DEST_ENV_ID}/limitRange" \
                    -d "${LIMIT_PAYLOAD}")
                
                if [ ! -z "$LIMIT_RESPONSE" ]; then
                    log_message "Successfully created limit range $LIMIT_NAME"
                else
                    log_message "Failed to create limit range $LIMIT_NAME"
                fi
            fi
        done
    else
        log_message "No limit ranges found in source environment"
    fi
    
    # Copy owner details
    log_message "Copying owner details..."
    OWNER=$(echo "$env" | jq -r '.createdBy')
    if [ ! -z "$OWNER" ] && [ "$OWNER" != "null" ]; then
        log_message "Setting owner to: $OWNER"
        curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "{\"createdBy\":\"$OWNER\",\"modifiedBy\":\"$OWNER\"}" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID"
        log_message "Updated owner details"
    fi

    # Copy labels
    log_message "Copying labels..."
    LABELS=$(echo "$env" | jq -r '.labels')
    if [ ! -z "$LABELS" ] && [ "$LABELS" != "null" ] && [ "$LABELS" != "{}" ]; then
        log_message "Source labels: $LABELS"
        curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "{\"labels\":$LABELS}" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID"
        log_message "Updated labels"
    fi
    
    # Copy team rolebindings
    copy_team_rolebindings "$SOURCE_ENV_ID" "$DEST_ENV_ID" "$ENV_NAME" "$DEST_ENV_NAME"
    
    # Update summary counters
    SUCCESSFUL_COPIES=$((SUCCESSFUL_COPIES + 1))
    log_summary "SUCCESS: $ENV_NAME -> $DEST_ENV_NAME"
    
    log_message "Settings copy completed for $ENV_NAME"
done

# Log final summary
log_message "All settings copied successfully"
log_summary "----------------------------------------"
log_summary "Total Environments Processed: $TOTAL_ENVIRONMENTS"
log_summary "Successfully Copied: $SUCCESSFUL_COPIES"
log_summary "Skipped: $SKIPPED_ENVIRONMENTS"
log_summary "Failed: $FAILED_COPIES"
log_summary "----------------------------------------" 