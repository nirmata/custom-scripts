# Kubernetes Cluster Role Configuration Script

## Description

This Bash script allows you to configure ClusterRoles and ClusterRoleBindings for multiple Kubernetes clusters using a single script. It simplifies the process of setting up RBAC (Role-Based Access Control) for different clusters.

## Usage

1. Ensure you have the `kubectl` command-line tool installed and configured with the necessary credentials.

2. Clone this repository or download the script.

3. Make the script executable:

   ```bash
   chmod +x configure-cluster-roles.sh
   ```

4. Run the script with the following command:

   ```bash
   ./configure-cluster-roles.sh <kubeconfig_path> <cluster1> <cluster2> ...
   ```

   Replace `<kubeconfig_path>` with the path to your Kubernetes configuration file (kubeconfig), and provide a list of cluster names as arguments.

## Example

```bash
./configure-cluster-roles.sh ~/.kube/config my-cluster-1 my-cluster-2
```

This will configure ClusterRoles and ClusterRoleBindings for `my-cluster-1` and `my-cluster-2`.

## Note

- The script assumes that you have appropriate permissions to create and manage ClusterRoles and ClusterRoleBindings within the specified clusters.

- It checks if the ClusterRoles and ClusterRoleBindings already exist before creating them. If they exist, it backs up the existing configurations to `/tmp` and then updates them.

- Make sure to review and customize the script to match your specific RBAC requirements.
