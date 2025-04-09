#!/bin/bash

# Script to list applications in an environment
# Usage: ./list_env_apps.sh <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME> <ENVIRONMENT_NAME>

set -e

# Check if required parameters are provided
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME> <ENVIRONMENT_NAME>"
    echo "Example: $0 https://pe420.nirmata.co \"YOUR_API_TOKEN\" \"129-app-migration\" \"new-migration\""
    exit 1
fi

API_ENDPOINT=$1
API_TOKEN=$2
CLUSTER_NAME=$3
ENVIRONMENT_NAME=$4

echo "Listing applications in environment: $ENVIRONMENT_NAME in cluster: $CLUSTER_NAME"

# Function to get cluster ID by name
get_cluster_id() {
    local cluster_name=$1
    echo "Fetching clusters from API..."
    local clusters_response=$(curl -s -X GET "$API_ENDPOINT/cluster/api/KubernetesCluster" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json")
    
    echo "API Response:"
    echo "$clusters_response" | jq '.'
    
    local cluster_id=$(echo "$clusters_response" | jq -r --arg name "$cluster_name" '.[] | select(.name == $name) | .id')
    
    if [ -z "$cluster_id" ] || [ "$cluster_id" = "null" ]; then
        echo "Error: Cluster '$cluster_name' not found"
        exit 1
    fi
    
    echo "$cluster_id"
}

# Function to get environment ID by name
get_environment_id() {
    local cluster_id=$1
    local env_name=$2
    echo "Fetching environments from API..."
    local environments_response=$(curl -s -X GET "$API_ENDPOINT/config/api/environments" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json")
    
    echo "API Response:"
    echo "$environments_response" | jq '.'
    
    # First, try to find environment with exact name match
    local env_id=$(echo "$environments_response" | jq -r --arg name "$env_name" '.[] | select(.name == $name) | .id')
    
    # If not found, try with nirmata- prefix
    if [ -z "$env_id" ] || [ "$env_id" = "null" ]; then
        env_id=$(echo "$environments_response" | jq -r --arg name "nirmata-$env_name" '.[] | select(.name == $name) | .id')
    fi
    
    if [ -z "$env_id" ] || [ "$env_id" = "null" ]; then
        echo "Error: Environment '$env_name' not found in cluster"
        exit 1
    fi
    
    echo "$env_id"
}

# Function to get applications in an environment
get_environment_applications() {
    local env_id=$1
    local apps=$(curl -s -X GET "$API_ENDPOINT/config/api/environments/$env_id/applications" \
        -H "Authorization: NIRMATA-API $API_TOKEN" \
        -H "Accept: application/json")
    
    echo "$apps"
}

# Main process
echo "Getting cluster ID for $CLUSTER_NAME..."
CLUSTER_ID=$(get_cluster_id "$CLUSTER_NAME")
echo "Cluster ID: $CLUSTER_ID"

echo "Getting environment ID for $ENVIRONMENT_NAME..."
ENV_ID=$(get_environment_id "$CLUSTER_ID" "$ENVIRONMENT_NAME")
echo "Environment ID: $ENV_ID"

echo "Getting applications in environment..."
APPS=$(get_environment_applications "$ENV_ID")
APP_COUNT=$(echo "$APPS" | jq '. | length')

if [ "$APP_COUNT" -eq 0 ]; then
    echo "No applications found in environment $ENVIRONMENT_NAME"
    exit 0
fi

echo "Found $APP_COUNT applications:"
echo "$APPS" | jq -r '.[] | "Name: \(.name), ID: \(.id)"'

# Save applications to a file for further processing
echo "$APPS" > "${ENVIRONMENT_NAME}_applications.json"
echo "Applications saved to ${ENVIRONMENT_NAME}_applications.json" 