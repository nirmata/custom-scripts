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

echo "Copying settings from environments in cluster $SOURCE_CLUSTER to $DEST_CLUSTER"

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
    echo "Error: Could not find cluster IDs"
    exit 1
fi

echo "Source cluster ID: $SOURCE_CLUSTER_ID"
echo "Destination cluster ID: $DEST_CLUSTER_ID"

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
    
    # Create destination environment name
    DEST_ENV_NAME="${ENV_NAME%$SOURCE_CLUSTER}$DEST_CLUSTER"
    
    echo "Processing environment: $ENV_NAME -> $DEST_ENV_NAME"
    
    # Check if destination environment exists
    DEST_ENV=$(echo "$ENVIRONMENTS" | jq -r ".[] | select(.name == \"$DEST_ENV_NAME\")")
    
    if [ -z "$DEST_ENV" ]; then
        echo "Creating destination environment $DEST_ENV_NAME"
        # Create destination environment
        DEST_ENV_RESPONSE=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "{\"name\":\"$DEST_ENV_NAME\",\"clusterId\":\"$DEST_CLUSTER_ID\"}" \
            "${API_ENDPOINT}/environments/api/environments")
        
        DEST_ENV_ID=$(echo "$DEST_ENV_RESPONSE" | jq -r '.id')
        if [ -z "$DEST_ENV_ID" ]; then
            echo "Failed to create destination environment"
            continue
        fi
    else
        DEST_ENV_ID=$(echo "$DEST_ENV" | jq -r '.id')
    fi
    
    echo "Source ID: $SOURCE_ENV_ID"
    echo "Destination ID: $DEST_ENV_ID"
    
    # Copy resource type
    RESOURCE_TYPE=$(echo "$env" | jq -r '.resourceType')
    if [ ! -z "$RESOURCE_TYPE" ] && [ "$RESOURCE_TYPE" != "null" ]; then
        echo "Copying resource type: $RESOURCE_TYPE"
        curl -s -X PUT \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -H "Authorization: NIRMATA-API $TOKEN" \
            -d "{\"resourceType\":\"$RESOURCE_TYPE\"}" \
            "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID"
    fi
    
    # Get source ACL ID
    SOURCE_ACL_ID=$(echo "$env" | jq -r '.accessControlList[0].id')
    if [ -z "$SOURCE_ACL_ID" ] || [ "$SOURCE_ACL_ID" = "null" ]; then
        echo "No access control list found in source environment"
        continue
    fi

    echo "Source ACL ID: $SOURCE_ACL_ID"

    # Get destination ACL ID
    DEST_ACL_ID=$(curl -s -H "Accept: application/json" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        "${API_ENDPOINT}/environments/api/environments/$DEST_ENV_ID" | jq -r '.accessControlList[0].id')

    if [ -z "$DEST_ACL_ID" ] || [ "$DEST_ACL_ID" = "null" ]; then
        echo "No access control list found in destination environment"
        continue
    fi

    echo "Destination ACL ID: $DEST_ACL_ID"

    # Get ACL details
    SOURCE_ACLS=$(curl -s -H "Accept: application/json" \
        -H "Authorization: NIRMATA-API $TOKEN" \
        "${API_ENDPOINT}/environments/api/accessControlLists/$SOURCE_ACL_ID")

    # Get access controls
    ACCESS_CONTROLS=$(echo "$SOURCE_ACLS" | jq -r '.accessControls[]')

    if [ ! -z "$ACCESS_CONTROLS" ]; then
        echo "$ACCESS_CONTROLS" | while read -r control_id; do
            # Get control details
            CONTROL_DETAILS=$(curl -s -H "Accept: application/json" \
                -H "Authorization: NIRMATA-API $TOKEN" \
                "${API_ENDPOINT}/environments/api/accessControls/$control_id")
            
            TEAM_ID=$(echo "$CONTROL_DETAILS" | jq -r '.entityId')
            TEAM_NAME=$(echo "$CONTROL_DETAILS" | jq -r '.entityName')
            PERMISSION=$(echo "$CONTROL_DETAILS" | jq -r '.permission')
            
            if [ ! -z "$TEAM_ID" ] && [ ! -z "$TEAM_NAME" ] && [ ! -z "$PERMISSION" ]; then
                echo "Creating ACL for team $TEAM_NAME ($TEAM_ID) with permission $PERMISSION"
                curl -s -X POST \
                    -H "Content-Type: application/json" \
                    -H "Accept: application/json" \
                    -H "Authorization: NIRMATA-API $TOKEN" \
                    -d "{\"entityId\":\"$TEAM_ID\",\"entityType\":\"team\",\"permission\":\"$PERMISSION\",\"entityName\":\"$TEAM_NAME\"}" \
                    "${API_ENDPOINT}/environments/api/accessControlLists/$DEST_ACL_ID/accessControls"
            fi
        done
    fi
    
    # Copy resource quotas
    echo "Copying resource quotas..."
    SOURCE_QUOTAS=$(curl -s -H "Authorization: NIRMATA-API ${TOKEN}" "${API_ENDPOINT}/environments/api/resourceQuota/${SOURCE_QUOTA_ID}" | jq -r '.')
    if [[ ! -z "$SOURCE_QUOTAS" ]]; then
        QUOTA_NAME=$(echo "$SOURCE_QUOTAS" | jq -r '.name')
        QUOTA_SPEC=$(echo "$SOURCE_QUOTAS" | jq -r '.spec')
        
        if [[ ! -z "$QUOTA_NAME" && ! -z "$QUOTA_SPEC" ]]; then
            QUOTA_PAYLOAD=$(cat <<EOF
{
  "name": "${QUOTA_NAME}",
  "spec": ${QUOTA_SPEC}
}
EOF
)
            echo "Creating quota with payload: ${QUOTA_PAYLOAD}"
            curl -s -X POST -H "Authorization: NIRMATA-API ${TOKEN}" -H "Content-Type: application/json" \
                "${API_ENDPOINT}/environments/api/resourceQuota?parent=${DEST_ENV_ID}" \
                -d "${QUOTA_PAYLOAD}"
        fi
    fi
    
    # Copy limit ranges
    echo "Copying limit ranges..."
    SOURCE_LIMITS=$(curl -s -H "Authorization: NIRMATA-API ${TOKEN}" "${API_ENDPOINT}/environments/api/limitRanges/${SOURCE_LIMIT_ID}" | jq -r '.')
    if [[ ! -z "$SOURCE_LIMITS" ]]; then
        LIMIT_NAME=$(echo "$SOURCE_LIMITS" | jq -r '.name')
        LIMIT_SPEC=$(echo "$SOURCE_LIMITS" | jq -r '.spec')
        
        if [[ ! -z "$LIMIT_NAME" && ! -z "$LIMIT_SPEC" ]]; then
            LIMIT_PAYLOAD=$(cat <<EOF
{
  "name": "${LIMIT_NAME}",
  "spec": ${LIMIT_SPEC}
}
EOF
)
            echo "Creating limit range with payload: ${LIMIT_PAYLOAD}"
            curl -s -X POST -H "Authorization: NIRMATA-API ${TOKEN}" -H "Content-Type: application/json" \
                "${API_ENDPOINT}/environments/api/limitRanges?parent=${DEST_ENV_ID}" \
                -d "${LIMIT_PAYLOAD}"
        fi
    fi
    
    echo "Settings copy completed for $ENV_NAME"
done

echo "All settings copied successfully" 