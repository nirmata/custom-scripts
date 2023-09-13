# Kubernetes ClusterRole and ClusterRoleBinding Update Script

This script is designed to update Kubernetes ClusterRoles and ClusterRoleBindings by replacing an existing ClusterRole with a new one and updating or creating a ClusterRoleBinding.

## Prerequisites

- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) is installed and configured to connect to your Kubernetes cluster.

## Usage

1. Clone this repository to your local machine or download the script.

2. Navigate to the directory containing the script.

3. Make the script executable if necessary:

   ```bash
   chmod +x update-clusterrole.sh
   ```

4. Edit the script to set the following variables:

   - `CLUSTER_ROLE_NAME`: The name of the ClusterRole you want to update or create (e.g., `"nirmata:nirmata-privileged"`).
   - `CLUSTER_ROLE_BINDING_NAME`: The name of the ClusterRoleBinding you want to update or create (e.g., `"nirmata-cluster-admin-binding"`).
   - Ensure that your YAML files for the new ClusterRole and ClusterRoleBinding are named appropriately (e.g., `nirmata-privileged-admin-clusterrole.yaml` and `nirmata-cluster-admin-binding.yaml`).

5. Run the script:

   ```bash
   ./update-clusterrole.sh
   ```

## Script Behavior

- The script first checks if the specified ClusterRole (`CLUSTER_ROLE_NAME`) already exists. If it does, it creates a backup of the existing ClusterRole in `/tmp` and deletes it.

- It then applies the new ClusterRole from the current directory.

- After updating the ClusterRole, the script checks if the specified ClusterRoleBinding (`CLUSTER_ROLE_BINDING_NAME`) already exists. If it does, it creates a backup of the existing ClusterRoleBinding in `/tmp` and deletes it.

- Finally, it applies the new ClusterRoleBinding from the current directory.

- The script provides feedback on whether each step was successful or if any errors occurred.

