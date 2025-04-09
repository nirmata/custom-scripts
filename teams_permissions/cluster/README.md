# Bash Script for Managing AccessControl in Nirmata

This Bash script is designed to simplify the process of managing AccessControl in [Nirmata](https://www.nirmata.io/) for a specified team. It allows you to grant permissions to the team for one or more clusters.

## Usage

Make sure you have the necessary arguments ready before running the script:

```bash
Usage: ./manage_access.sh NIRMATAURL TOKEN TEAM_NAME PERMISSION CLUSTER_NAME [CLUSTER_NAME2 ...]
```

- `NIRMATAURL`: The URL of your Nirmata instance.
- `TOKEN`: Your Nirmata API token for authorization.
- `TEAM_NAME`: The name of the team you want to grant permissions to.
- `PERMISSION`: The permission you want to grant to the team (e.g., `read`, `write`, etc.).
- `CLUSTER_NAME`: The name of the cluster you want to grant access to. You can provide one or more cluster names as additional arguments.

## How it works

1. The script first checks if all the required arguments are provided. If not, it displays the usage instructions.

2. It then iterates through the provided cluster names and performs the following steps for each cluster:

   - Retrieves the team ID by name.
   - Retrieves the cluster ID by name.
   - Retrieves the parent ID for AccessControl.
   - Creates the AccessControl entry, granting the specified permission to the team for the cluster.

3. It displays success or failure messages for each cluster.

## Example

Here's an example of how to use the script:

```bash
./manage_access.sh https://your-nirmata-url.com your-api-token MyTeam ns-creator MyCluster1 MyCluster2
```

This command grants the `ns-creator` permission to the team named `MyTeam` for `MyCluster1` and `MyCluster2`.
