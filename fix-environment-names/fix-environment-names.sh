#!/bin/bash

# Configuration
NIRMATA_URL="$1"
CLUSTER_NAME="$2"

if [[ $# != 2 ]]; then
	echo
	echo "Usage: $0 <NirmataURL> <cluster-name>"
	echo
	exit 1
fi

echo
echo "Enter the Nirmata API token: "
read -s API_TOKEN
echo

CLUSTER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API ${API_TOKEN}" -X GET "${NIRMATA_URL}/cluster/api/KubernetesCluster?fields=id,name" | jq -r ".[] | select( .name == \"$CLUSTER_NAME\" ).id")

# Function to fetch environment details from Nirmata
get_nirmata_environments() {
    echo "Fetching environment details from Nirmata..." >&2

    # Make API call to Nirmata and store response
    response=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" \
                    -H "Authorization: NIRMATA-API ${API_TOKEN}" \
                    -X GET "${NIRMATA_URL}/environments/api/Environment?fields=id,name,namespace&filter=hostCluster.id,eq,${CLUSTER_ID}" | jq .)

    # Check if curl command was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to fetch data from Nirmata API"
        exit 1
    fi

    # Debug: Print the raw response
    #echo "Raw API Response:"
    #echo "$response"

    # Validate JSON response
    if ! echo "$response" | jq . >/dev/null 2>&1; then
        echo "Error: Invalid JSON response from API">&2
        echo "Response content:">&2
        echo "$response">&2
        exit 1
    fi

    echo "$response"
}

# Function to update namespace annotation
update_namespace_annotation() {
    local namespace=$1
    local env_id=$2
    local env_name=$3

    echo -e "\nProcessing namespace: $namespace"

    # Get current annotations
    current_annotation=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.nirmata\.io}' 2>/dev/null)
    if [ -z "$current_annotation" ]; then
        echo "No current annotation found for nirmata.io in namespace: $namespace"
        return 1
    fi


    current_env_id=$(kubectl get namespace "$namespace" -o jsonpath='{.metadata.annotations.nirmata\.io}' | jq -r '.["environment.modelId"]' 2>/dev/null || echo "none")
    if [ "$current_env_id" = "$env_id" ]; then
        echo "Namespace $namespace already has correct environment ID: $env_id"
        return 0
    fi

    echo "Current environment ID: $current_env_id"
    echo "New environment ID: $env_id"
    echo "Environment name: $env_name"


    updated_annotation=$(echo "$current_annotation" | jq --arg env_id "$env_id" --arg env_name "$env_name" '. + { "environment.modelId": $env_id, "environment.name": $env_name }' | jq -c)
    # Create patch json
    patch_json=$(cat <<EOF
{
  "metadata": {
    "annotations": {
      "nirmata.io": $(echo "$updated_annotation" | jq -sR .)
    }
  }
}
EOF
)

    # Apply patch
    if kubectl patch namespace "$namespace" --patch "$patch_json" --type=merge; then
        echo "Successfully updated annotations for namespace: $namespace"
    else
        echo "Error: Failed to update annotations for namespace: $namespace"
        return 1
    fi
}

# Main script
main() {
    # Check if kubectl is installed
    if ! command -v kubectl &> /dev/null; then
        echo "Error: kubectl is not installed"
        exit 1
    fi

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        echo "Error: jq is not installed"
        exit 2
    fi


    # Get environment data from Nirmata
    env_data=$(get_nirmata_environments)
    # In your main function:

    # Debug: Validate env_data
    echo "Environment data received:"
    echo "$env_data"

    if echo "$env_data" | jq . >/dev/null 2>&1; then
        echo "JSON is valid"
    else
        echo "JSON is invalid"
        echo "Content of env_data:"
        echo "$env_data" | cat -A
    fi


    # Process each environment
    echo "$env_data" | jq -r '.[] | .namespace'
    echo "$env_data" | jq -c '.[]' | while read -r env; do
        namespace=$(echo "$env" | jq -r '.namespace // empty')
        env_id=$(echo "$env" | jq -r '.id')
        env_name=$(echo "$env" | jq -r '.name')

        # Skip if namespace is empty
        if [ -z "$namespace" ]; then
            continue
        fi

        # Check if namespace exists in cluster
        if kubectl get namespace "$namespace" &>/dev/null; then
            update_namespace_annotation "$namespace" "$env_id" "$env_name"
        else
            echo "Namespace $namespace does not exist in the cluster"
        fi
    done
}

# Run main function
main
