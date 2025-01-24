#!/bin/bash

# Define the backup directory with a timestamp
BACKUP_DIR="$PWD/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$BACKUP_DIR/namespaced" "$BACKUP_DIR/cluster"

# Retrieve namespaced and cluster-wide resources using kubectl api-resources
NAMESPACED_RESOURCES=$(kubectl api-resources --namespaced=true -o name | tr '\n' ' ')
CLUSTER_RESOURCES=$(kubectl api-resources --namespaced=false -o name | tr '\n' ' ')

# Function to backup namespaced resources
backup_namespaced_resource() {
    local namespace=$1
    local resource=$2

    # Check if resource exists in the namespace
    if kubectl get "$resource" -n "$namespace" &> /dev/null; then
        # Create namespace directory
        mkdir -p "$BACKUP_DIR/namespaced/$namespace"

        # Backup each resource instance in YAML format
        for item in $(kubectl get "$resource" -n "$namespace" -o name); do
            kubectl get "$item" -n "$namespace" -o yaml > "$BACKUP_DIR/namespaced/$namespace/$resource-$(echo "$item" | cut -d'/' -f2).yaml"
        done
    # else
    #     echo "No $resource found in namespace $namespace."
    fi
}

# Function to backup cluster-wide resources
backup_cluster_resource() {
    local resource=$1

    # Check if the cluster-wide resource exists
    if kubectl get "$resource" &> /dev/null; then
        # Backup each resource instance in YAML format
        for item in $(kubectl get "$resource" -o name); do
            kubectl get "$item" -o yaml > "$BACKUP_DIR/cluster/$resource-$(echo "$item" | cut -d'/' -f2).yaml"
        done
    # else
    #     echo "No $resource found at the cluster level."
    fi
}

# Get all namespaces
echo 
echo "Backing up k8s resources... This might take few minutes based on the number of resources in your cluster."
namespaces=$(kubectl get namespaces -o jsonpath='{.items[*].metadata.name}')

# Backup each namespaced resource in each namespace
for namespace in $namespaces; do
    for resource in $NAMESPACED_RESOURCES; do
        backup_namespaced_resource "$namespace" "$resource"
    done
done

# Backup each cluster-wide resource
for resource in $CLUSTER_RESOURCES; do
    backup_cluster_resource "$resource"
done

echo "Backup completed in $BACKUP_DIR"
echo

