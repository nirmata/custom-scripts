#!/bin/bash

# Check if URL is provided
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <NIRMATA_URL>"
    echo "Example: $0 https://nirmata.io"
    exit 1
fi

# Get URL from command line
NIRMATA_URL=$1

# Remove trailing slash from URL if present
NIRMATA_URL=${NIRMATA_URL%/}

# Prompt for API token securely (without echoing to terminal)
echo -n "Enter the Nirmata API token: "
read -s API_TOKEN
echo  # Add a newline after secret input

# Validate input
if [ -z "$API_TOKEN" ]; then
    echo "Error: API token cannot be empty"
    exit 1
fi

get_clusters() {
    curl -s -H "Authorization: NIRMATA-API $API_TOKEN" \
         -H "Content-Type: application/json" \
         "${NIRMATA_URL}/cluster/api/KubernetesCluster?fields=id,createdOn,status,name,typeSelector"
}

# Function to get node information for a cluster
get_cluster_nodes() {
    local cluster_id=$1
    curl -s -H "Authorization: NIRMATA-API $API_TOKEN" \
         -H "Content-Type: application/json" \
         "${NIRMATA_URL}/cluster/api/KubernetesCluster/${cluster_id}/node?fields=id,name,labels"
}

# Function to format date from milliseconds
format_date() {
    local timestamp=$1
    # Convert milliseconds to seconds and format
    date -d "@$((timestamp/1000))" "+%Y-%m-%d %H:%M:%S UTC" 2>/dev/null || echo "Invalid date"
}

# Main execution
echo "Fetching cluster information..."

# Get all clusters
clusters=$(get_clusters)

# Process each cluster
echo "$clusters" | jq -c '.[]' | while read -r cluster; do
    cluster_id=$(echo "$cluster" | jq -r '.id')
    cluster_name=$(echo "$cluster" | jq -r '.name')
    cluster_status=$(echo "$cluster" | jq -r '.status')
    created_on=$(echo "$cluster" | jq -r '.createdOn')
    formatted_date=$(format_date "$created_on")
    cluster_type=$(echo "$cluster" | jq -r '.typeSelector')

    # Get nodes for this cluster
    nodes=$(get_cluster_nodes "$cluster_id")
    echo "Processing nodes for cluster: $cluster_name"

    # Initialize counters and arrays
    master_count=0
    worker_count=0
    master_nodes=""
    worker_nodes=""

    # Process each node and count types
    while read -r node; do
        if [ ! -z "$node" ]; then
            labels=$(echo "$node" | jq -r '.labels')
            node_name=$(echo "$node" | jq -r '.name')
            
            if echo "$labels" | grep -q "node-role.kubernetes.io/master\|node-role.kubernetes.io/control-plane"; then
                ((master_count++))
                master_nodes="${master_nodes}\"$node_name\", "
            else
                ((worker_count++))
                worker_nodes="${worker_nodes}\"$node_name\", "
            fi
        fi
    done < <(echo "$nodes" | jq -c '.[]')

    # Remove trailing comma and space
    master_nodes=${master_nodes%, }
    worker_nodes=${worker_nodes%, }

    # Output the summary in JSON format
    cat << EOF
{
  "cluster_name": "$cluster_name",
  "worker_node_count": $worker_count,
  "master_node_count": $master_count,
  "master_nodes": [$master_nodes],
  "worker_nodes": [$worker_nodes],
  "cluster_status": $(echo "$cluster_status" | jq -c '.'),
  "creation_date": "$formatted_date",
  "cluster_id": "$cluster_id",
  "cluster_type": "$cluster_type"
}
----------------------------------------
EOF
done
