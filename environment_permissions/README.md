# Environment Permissions Export Tool

This script exports environment permissions from Nirmata clusters into a CSV file. It provides a detailed view of environment access controls, including team permissions and team members.

## Features

- Exports environment permissions for a specific cluster
- Shows team permissions and members for each environment
- Handles environments with no custom teams or ACLs
- Creates a CSV file that can be easily opened in Excel
- Formats output with environment grouping and team member listing

## Prerequisites

- `bash` shell
- `curl` for API calls
- `jq` for JSON processing

## Usage

```bash
./get_env_permissions.sh <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME>
```

### Parameters

- `API_ENDPOINT`: Your Nirmata instance URL (e.g., https://pe420.nirmata.co)
- `API_TOKEN`: Your Nirmata API token
- `CLUSTER_NAME`: The name of the cluster to export permissions from

### Example

```bash
./get_env_permissions.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration"
```

## Output

The script creates a CSV file named `{CLUSTER_NAME}_environment_permissions.csv` with the following columns:

- Environment Name: Name of the Nirmata environment
- Team Name: Name of the team with access
- Team Permission: Permission level (e.g., admin, edit, view)
- Team Members: List of team member email addresses

### CSV Format Example

```
Environment Name,Team Name,Team Permission,Team Members
nginx,dev,edit,anudeep.nalla@nirmata.com
,,,yun@nirmata.com
,new,admin,sagar@nirmata.com
,,,anubhav@nirmata.com
```

## Notes

- The script skips the default "clusterRegistrator" team entries
- Empty cells in subsequent rows indicate continuation of the previous environment/team
- "No custom teams" indicates environments with only default permissions
- "No ACL" indicates environments without access control lists 