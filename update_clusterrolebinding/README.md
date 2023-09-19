# ClusterRoleBinding Update Script

## Description

This Bash script allows you to update ClusterRoleBindings for multiple Kubernetes clusters using a single script. It simplifies the process of modifying RBAC (Role-Based Access Control) configurations for different clusters.

## Usage

1. Ensure you have the `kubectl` command-line tool installed and configured with the necessary credentials.

2. Clone this repository or download the script.

3. Make the script executable:

   ```bash
   chmod +x clusterolebinding_update.sh
   ```

4. Run the script with the following command:

   ```bash
   ./clusterolebinding_update.sh <kubeconfig_path> <cluster1> <cluster2> ...
   ```

   Replace `<kubeconfig_path>` with the path to your Kubernetes configuration file (kubeconfig), and provide a list of cluster names as arguments.

## Example

```bash
./clusterolebinding_update.sh ~/.kube/config my-cluster-1 my-cluster-2
```

This will update ClusterRoleBindings for `my-cluster-1` and `my-cluster-2`.

## Note

- The script assumes that you have appropriate permissions to modify ClusterRoleBindings within the specified clusters.

- It checks if the ClusterRoleBindings already exist before updating them. If they exist, it backs up the existing configurations to `/tmp` and then updates them.

- Make sure to review and customize the script to match your specific RBAC requirements.
