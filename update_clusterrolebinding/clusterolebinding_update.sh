#!/bin/bash

# Define the ClusterRole and ClusterRoleBinding names
CLUSTER_ROLE_NAME="nirmata:nirmata-privileged"
CLUSTER_ROLE_BINDING_NAME="nirmata-cluster-admin-binding"

# Check if the nirmata:nirmata-privileged ClusterRole already exists
if kubectl get clusterrole "$CLUSTER_ROLE_NAME" &> /dev/null; then
  # Backup the existing ClusterRole to /tmp
  kubectl get clusterrole "$CLUSTER_ROLE_NAME" -o yaml > "/tmp/$CLUSTER_ROLE_NAME-backup.yaml"
  # Delete the existing ClusterRole
  kubectl delete clusterrole "$CLUSTER_ROLE_NAME"
fi

# Create the nirmata:nirmata-privileged ClusterRole from the current directory
kubectl apply -f nirmata-privileged-admin-clusterrole.yaml

# Check if the ClusterRole was created successfully
if [ $? -eq 0 ]; then
  echo "nirmata:nirmata-privileged ClusterRole created successfully."
else
  echo "Failed to create nirmata:nirmata-privileged ClusterRole."
  exit 1
fi

# Check if the nirmata-cluster-admin-binding ClusterRoleBinding already exists
if kubectl get clusterrolebinding "$CLUSTER_ROLE_BINDING_NAME" &> /dev/null; then
  # Backup the existing ClusterRoleBinding to /tmp
  kubectl get clusterrolebinding "$CLUSTER_ROLE_BINDING_NAME" -o yaml > "/tmp/$CLUSTER_ROLE_BINDING_NAME-backup.yaml"
  # Delete the existing ClusterRoleBinding
  kubectl delete clusterrolebinding "$CLUSTER_ROLE_BINDING_NAME"
fi

# Create the nirmata-cluster-admin-binding ClusterRoleBinding from the current directory
kubectl apply -f nirmata-cluster-admin-binding.yaml

# Check if the ClusterRoleBinding was created successfully
if [ $? -eq 0 ]; then
  echo "nirmata-cluster-admin-binding ClusterRoleBinding created successfully."
else
  echo "Failed to create nirmata-cluster-admin-binding ClusterRoleBinding."
  exit 1
fi
