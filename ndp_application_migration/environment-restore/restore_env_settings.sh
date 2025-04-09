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

# Get all environments
ENVIRONMENTS=$(curl -s -H "Accept: application/json" \
    -H "Authorization: NIRMATA-API $TOKEN" \
    "${API_ENDPOINT}/environments/api/environments")

# Get all clusters
CLUSTERS=$(curl -s -H "Accept: application/json" \
    -H "Authorization: NIRMATA-API $TOKEN" \
    "${API_ENDPOINT}/environments/api/clusters")

# Find source and destination cluster IDs
SOURCE_CLUSTER_ID=$(echo "$CLUSTERS" | jq -r ".[] | select(.name == \"$SOURCE_CLUSTER\") | .id")
DEST_CLUSTER_ID=$(echo "$CLUSTERS" | jq -r ".[] | select(.name == \"$DEST_CLUSTER\") | .id")

if [ -z "$SOURCE_CLUSTER_ID" ] || [ -z "$DEST_CLUSTER_ID" ]; then
    log_message "Error: Could not find cluster IDs"
    exit 1
fi

log_message "Source cluster ID: $SOURCE_CLUSTER_ID"
log_message "Destination cluster ID: $DEST_CLUSTER_ID"

# Get environments from source cluster
SOURCE_ENVIRONMENTS=$(echo "$ENVIRONMENTS" | jq -r --arg cluster_id "$SOURCE_CLUSTER_ID" '.[] | select(.cluster | any(.id == $cluster_id))')

# Debug output
echo "All environments:"
echo "$ENVIRONMENTS" | jq '.'
echo "Source cluster ID: $SOURCE_CLUSTER_ID"
echo "Source environments:"
echo "$SOURCE_ENVIRONMENTS" | jq '.'

if [ -z "$SOURCE_ENVIRONMENTS" ]; then
    echo "No environments found in source cluster $SOURCE_CLUSTER"
    exit 1
fi

# Process each environment
echo "$SOURCE_ENVIRONMENTS" | jq -c '.' | while read -r env; do
    ENV_NAME=$(echo "$env" | jq -r '.name')
    SOURCE_ENV_ID=$(echo "$env" | jq -r '.id')
    TOTAL_ENVIRONMENTS=$((TOTAL_ENVIRONMENTS + 1))
    
    # Determine destination environment name based on naming pattern
    if [[ "$ENV_NAME" == *"$SOURCE_CLUSTER" ]]; then
        # Environment has source cluster suffix
        DEST_ENV_NAME="${ENV_NAME%$SOURCE_CLUSTER}$DEST_CLUSTER"
    else
        # Environment doesn't have cluster suffix (will be restored by Commvault)
        DEST_ENV_NAME="${ENV_NAME}-${DEST_CLUSTER}"
    fi
    
    log_message "Processing environment: $ENV_NAME -> $DEST_ENV_NAME"
    
    # Check if destination environment exists
    DEST_ENV=$(echo "$ENVIRONMENTS" | jq -r ".[] | select(.name == \"$DEST_ENV_NAME\")")
    
    if [ -z "$DEST_ENV" ]; then
        log_message "Destination environment $DEST_ENV_NAME not found. This is expected if Commvault hasn't restored it yet."
        log_message "Will try to create it now..."
        SKIPPED_ENVIRONMENTS=$((SKIPPED_ENVIRONMENTS + 1))
        log_summary "SKIPPED: $ENV_NAME -> $DEST_ENV_NAME (Environment not found)"
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
                QUOTA_PAYLOAD="{\"name\":\"${QUOTA_NAME}\",\"spec\":${QUOTA_SPEC}}"
                QUOTA_RESPONSE=$(curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Authorization: NIRMATA-API ${TOKEN}" \
                    "${API_ENDPOINT}/environments/api/environments/${DEST_ENV_ID}/resourceQuota" \
                    -d "${QUOTA_PAYLOAD}")
                
                if [ ! -z "$QUOTA_RESPONSE" ]; then
                    log_message "Successfully created quota $QUOTA_NAME"
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
    
    # Copy owner details (simplified version)
    log_message "Copying owner details..."
    OWNER=$(echo "$env" | jq -r '.createdBy')
    if [ ! -z "$OWNER" ] && [ "$OWNER" != "null" ]; then
        log_message "Setting owner to: $OWNER"
        
        # Get source environment details for permissions
        SOURCE_ENV_DETAILS=$(curl -s -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            "${API_ENDPOINT}/environments/api/environments/$SOURCE_ENV_ID")
        
        # Extract all relevant fields
        OWNER_FIELDS=$(echo "$SOURCE_ENV_DETAILS" | jq -r '{createdBy, modifiedBy, owner, ownerEmail, ownerName}')
        
        # Update owner details
        OWNER_UPDATE_RESPONSE=$(curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "$OWNER_FIELDS" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID")
        
        if [ ! -z "$OWNER_UPDATE_RESPONSE" ]; then
            log_message "Successfully updated owner details"
            OWNER_UPDATED=true
        else
            log_message "Failed to update owner details"
            OWNER_UPDATED=false
        fi
    else
        log_message "No owner found in source environment"
        OWNER_UPDATED=false
    fi

    # Copy labels (improved version)
    log_message "Copying labels..."
    LABELS=$(echo "$env" | jq -r '.labels')
    if [ ! -z "$LABELS" ] && [ "$LABELS" != "null" ] && [ "$LABELS" != "{}" ]; then
        log_message "Source labels: $LABELS"
        
        # First get existing labels
        EXISTING_LABELS=$(curl -s -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID" | jq -r '.labels')
        
        log_message "Existing labels in destination: $EXISTING_LABELS"
        
        # Merge labels, with source labels taking precedence
        MERGED_LABELS=$(echo "$LABELS $EXISTING_LABELS" | jq -s 'add')
        log_message "Merged labels: $MERGED_LABELS"
        
        # Update labels with retry mechanism
        MAX_RETRIES=3
        RETRY_COUNT=0
        LABELS_UPDATED=false
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$LABELS_UPDATED" = false ]; do
            LABELS_UPDATE_RESPONSE=$(curl -s -X PUT \
                -H "Content-Type: application/json" \
                -H "Accept: application/json" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                -d "{\"labels\":$MERGED_LABELS}" \
                "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID")
            
            # Verify the update
            sleep 2  # Wait for changes to propagate
            UPDATED_ENV=$(curl -s -H "Accept: application/json" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID")
            
            UPDATED_LABELS=$(echo "$UPDATED_ENV" | jq -r '.labels')
            if [ "$UPDATED_LABELS" = "$MERGED_LABELS" ]; then
                log_message "Successfully updated labels"
                LABELS_UPDATED=true
                break
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                    log_message "Retrying labels update (attempt $RETRY_COUNT of $MAX_RETRIES)..."
                else
                    log_message "Warning: Failed to verify labels update after $MAX_RETRIES attempts"
                fi
            fi
        done
    fi

    # Copy update action with verification
    log_message "Copying update action..."
    UPDATE_ACTION=$(echo "$env" | jq -r '.updateAction')
    if [ ! -z "$UPDATE_ACTION" ] && [ "$UPDATE_ACTION" != "null" ]; then
        log_message "Setting update action to: $UPDATE_ACTION"
        
        MAX_RETRIES=3
        RETRY_COUNT=0
        ACTION_UPDATED=false
        
        while [ $RETRY_COUNT -lt $MAX_RETRIES ] && [ "$ACTION_UPDATED" = false ]; do
            ACTION_UPDATE_RESPONSE=$(curl -s -X PUT \
                -H "Content-Type: application/json" \
                -H "Accept: application/json" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                -d "{\"updateAction\":\"$UPDATE_ACTION\"}" \
                "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID")
            
            # Verify the update
            sleep 2  # Wait for changes to propagate
            UPDATED_ENV=$(curl -s -H "Accept: application/json" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID")
            
            UPDATED_ACTION=$(echo "$UPDATED_ENV" | jq -r '.updateAction')
            if [ "$UPDATED_ACTION" = "$UPDATE_ACTION" ]; then
                log_message "Successfully updated update action to: $UPDATE_ACTION"
                ACTION_UPDATED=true
                break
            else
                RETRY_COUNT=$((RETRY_COUNT + 1))
                if [ $RETRY_COUNT -lt $MAX_RETRIES ]; then
                    log_message "Retrying update action update (attempt $RETRY_COUNT of $MAX_RETRIES)..."
                else
                    log_message "Warning: Failed to verify update action update after $MAX_RETRIES attempts"
                fi
            fi
        done
    fi
    
    # Copy update policies (improved version)
    log_message "Copying update policies..."
    SOURCE_UPDATE_POLICY=$(curl -s -H "Accept: application/json" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        "${API_ENDPOINT}/environments/api/environments/${SOURCE_ENV_ID}/updatePolicy")
    
    if [ ! -z "$SOURCE_UPDATE_POLICY" ] && [ "$SOURCE_UPDATE_POLICY" != "null" ]; then
        echo "$SOURCE_UPDATE_POLICY" | jq -c '.[]' | while read -r policy; do
            POLICY_NAME=$(echo "$policy" | jq -r '.name')
            POLICY_SPEC=$(echo "$policy" | jq -r '.spec')
            POLICY_ACTION=$(echo "$policy" | jq -r '.action')
            
            if [ ! -z "$POLICY_NAME" ] && [ ! -z "$POLICY_SPEC" ] && [ "$POLICY_SPEC" != "null" ]; then
                log_message "Creating update policy: $POLICY_NAME with action: $POLICY_ACTION"
                POLICY_PAYLOAD="{\"name\":\"${POLICY_NAME}\",\"spec\":${POLICY_SPEC},\"action\":\"${POLICY_ACTION}\"}"
                POLICY_RESPONSE=$(curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Authorization: NIRMATA-API ${TOKEN}" \
                    "${API_ENDPOINT}/environments/api/environments/${DEST_ENV_ID}/updatePolicy" \
                    -d "${POLICY_PAYLOAD}")
                
                if [ ! -z "$POLICY_RESPONSE" ]; then
                    log_message "Successfully created update policy $POLICY_NAME"
                else
                    log_message "Failed to create update policy $POLICY_NAME"
                fi
            fi
        done
    else
        log_message "No update policies found in source environment"
    fi
    
    # Update summary counters
    if [ "$OWNER_UPDATED" = true ] && [ "$LABELS_UPDATED" = true ] && [ "$ACTION_UPDATED" = true ]; then
        SUCCESSFUL_COPIES=$((SUCCESSFUL_COPIES + 1))
        log_summary "SUCCESS: $ENV_NAME -> $DEST_ENV_NAME"
    else
        FAILED_COPIES=$((FAILED_COPIES + 1))
        log_summary "FAILED: $ENV_NAME -> $DEST_ENV_NAME"
        # Log what failed
        if [ "$OWNER_UPDATED" != true ]; then
            log_summary "  - Owner update failed"
        fi
        if [ "$LABELS_UPDATED" != true ]; then
            log_summary "  - Labels update failed"
        fi
        if [ "$ACTION_UPDATED" != true ]; then
            log_summary "  - Update action failed"
        fi
    fi
    
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