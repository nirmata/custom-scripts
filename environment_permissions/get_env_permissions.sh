#!/bin/bash

# Check if all arguments are provided
if [ $# -ne 3 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME>"
    echo "Example: $0 https://pe420.nirmata.co YOUR_API_TOKEN 123-app-migration"
    exit 1
fi

# API endpoint and token from command line arguments
API_ENDPOINT="$1"
API_TOKEN="$2"
TARGET_CLUSTER="$3"

# Validate API_ENDPOINT format
if [[ ! "$API_ENDPOINT" =~ ^https?:// ]]; then
    echo "Error: API_ENDPOINT must start with http:// or https://"
    exit 1
fi

# Validate API_TOKEN is not empty
if [ -z "$API_TOKEN" ]; then
    echo "Error: API_TOKEN cannot be empty"
    exit 1
fi

# Remove trailing slash from API_ENDPOINT if present
API_ENDPOINT="${API_ENDPOINT%/}"

# Create a meaningful filename with the cluster name
CSV_FILENAME="${TARGET_CLUSTER}_environment_permissions.csv"

# Create CSV header
echo "Environment Name,Team Name,Team Permission,Team Members" > "$CSV_FILENAME"

# Get all environments with their details in a single call
echo "Fetching environments..."
ENVIRONMENTS=$(curl -s -X GET "${API_ENDPOINT}/environments/api/environments" \
    -H "Authorization: NIRMATA-API ${API_TOKEN}" \
    -H "Accept: application/json")

# Get all teams in a single call
TEAMS=$(curl -s -X GET "${API_ENDPOINT}/users/api/teams" \
    -H "Authorization: NIRMATA-API ${API_TOKEN}" \
    -H "Accept: application/json")

# Store the first hostCluster.id we find for the cluster
CLUSTER_HOST_ID=""

# First pass: find the hostCluster.id from any environment in the cluster
echo "$ENVIRONMENTS" | jq -c '.[]' | while read -r env; do
    ENV_NAME=$(echo "$env" | jq -r '.name')
    if [[ "$ENV_NAME" == *"-$TARGET_CLUSTER" ]]; then
        HOST_ID=$(echo "$env" | jq -r '.hostCluster.id // empty')
        if [ -n "$HOST_ID" ]; then
            echo "$HOST_ID" > /tmp/cluster_host_id
            break
        fi
    fi
done

if [ -f /tmp/cluster_host_id ]; then
    CLUSTER_HOST_ID=$(cat /tmp/cluster_host_id)
    rm /tmp/cluster_host_id
fi

if [ -z "$CLUSTER_HOST_ID" ]; then
    echo "Error: Could not find any environments for cluster $TARGET_CLUSTER"
    exit 1
fi

echo "Found cluster host ID: $CLUSTER_HOST_ID"

# Process each environment
echo "$ENVIRONMENTS" | jq -c '.[]' | while read -r env; do
    ENV_NAME=$(echo "$env" | jq -r '.name')
    ENV_HOST_ID=$(echo "$env" | jq -r '.hostCluster.id // empty')
    
    # Check if environment belongs to the target cluster
    if [ "$ENV_HOST_ID" = "$CLUSTER_HOST_ID" ]; then
        echo "Processing environment: $ENV_NAME"
        
        # Get ACL ID
        ACL_ID=$(echo "$env" | jq -r '.accessControlList[0].id // empty')
        echo "  ACL ID: $ACL_ID"

        if [ -n "$ACL_ID" ] && [ "$ACL_ID" != "null" ]; then
            # Get ACL details
            ACL_DETAILS=$(curl -s -X GET "${API_ENDPOINT}/environments/api/accessControlLists/${ACL_ID}" \
                -H "Authorization: NIRMATA-API ${API_TOKEN}" \
                -H "Accept: application/json")

            # Get access control IDs
            ACCESS_CONTROL_IDS=$(echo "$ACL_DETAILS" | jq -r '.accessControls[].id')
            echo "  Found access controls: $ACCESS_CONTROL_IDS"

            # Flag to track if we found any non-clusterRegistrator teams
            FOUND_CUSTOM_TEAMS=false
            FIRST_TEAM=true

            for AC_ID in $ACCESS_CONTROL_IDS; do
                # Get access control details
                AC_DETAILS=$(curl -s -X GET "${API_ENDPOINT}/environments/api/accessControls/${AC_ID}" \
                    -H "Authorization: NIRMATA-API ${API_TOKEN}" \
                    -H "Accept: application/json")

                TEAM_NAME=$(echo "$AC_DETAILS" | jq -r '.entityName')
                PERMISSION=$(echo "$AC_DETAILS" | jq -r '.permission')
                TEAM_ID=$(echo "$AC_DETAILS" | jq -r '.entityId')
                echo "    Team: $TEAM_NAME, Permission: $PERMISSION"

                # Skip clusterRegistrator team since it's added by default
                if [ "$TEAM_NAME" = "clusterRegistrator" ]; then
                    continue
                fi

                FOUND_CUSTOM_TEAMS=true

                # Get team details to get members
                TEAM_DETAILS=$(echo "$TEAMS" | jq -c --arg tid "$TEAM_ID" '.[] | select(.id == $tid)')
                
                if [ -n "$TEAM_DETAILS" ]; then
                    # Get team members
                    MEMBER_IDS=$(echo "$TEAM_DETAILS" | jq -r '.users[].id')
                    echo "      Members: $MEMBER_IDS"
                    
                    # First member flag
                    FIRST_MEMBER=true
                    
                    # Process each member
                    for MEMBER_ID in $MEMBER_IDS; do
                        # Get user email
                        MEMBER_EMAIL=$(curl -s -X GET "${API_ENDPOINT}/users/api/users/${MEMBER_ID}" \
                            -H "Authorization: NIRMATA-API ${API_TOKEN}" \
                            -H "Accept: application/json" | jq -r '.email')
                        
                        if [ "$FIRST_TEAM" = true ] && [ "$FIRST_MEMBER" = true ]; then
                            # First team, first member - show environment name
                            printf "%s,%s,%s,%s\n" "$ENV_NAME" "$TEAM_NAME" "$PERMISSION" "$MEMBER_EMAIL" >> "$CSV_FILENAME"
                            FIRST_TEAM=false
                            FIRST_MEMBER=false
                        elif [ "$FIRST_MEMBER" = true ]; then
                            # Not first team, but first member - show team info
                            printf ",%s,%s,%s\n" "$TEAM_NAME" "$PERMISSION" "$MEMBER_EMAIL" >> "$CSV_FILENAME"
                            FIRST_MEMBER=false
                        else
                            # Not first member - only show email
                            printf ",,,%s\n" "$MEMBER_EMAIL" >> "$CSV_FILENAME"
                        fi
                    done
                fi
            done

            # If no custom teams were found, add a row for the environment
            if [ "$FOUND_CUSTOM_TEAMS" = false ]; then
                printf "%s,%s,%s,%s\n" "$ENV_NAME" "No custom teams" "No custom permissions" "N/A" >> "$CSV_FILENAME"
            fi
        else
            echo "  No ACL found for environment $ENV_NAME"
            printf "%s,%s,%s,%s\n" "$ENV_NAME" "No ACL" "No permissions" "N/A" >> "$CSV_FILENAME"
        fi
    fi
done

echo "CSV file '$CSV_FILENAME' has been created with all the permissions data."
echo "You can open this file directly in Excel." 