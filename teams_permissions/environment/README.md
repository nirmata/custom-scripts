# Nirmata Access Control Bash Script

This Bash script allows you to manage access control in Nirmata by granting specific permissions to a team for one or more environments. It utilizes the Nirmata API for this purpose.

## Prerequisites

Before using this script, ensure that you have the following prerequisites:

- [Nirmata URL](https://www.nirmata.io/) - The URL where your Nirmata instance is hosted.
- API Token - A valid API token for authentication.
- Team Name - The name of the team to which you want to grant permissions.
- Cluster Name - The name of the cluster where you want to grant permissions.
- Permission - The permission level you want to grant (e.g., read, write, admin).
- Environment Names - One or more environment names to which you want to grant permissions.

## Usage

To use the script, run the following command:

```bash
./nirmata-access-control.sh NIRMATAURL TOKEN teamname clustername Permission EnvironmentName [EnvironmentName ...]
```

Replace the placeholders with your specific values:

- `NIRMATAURL` - The URL of your Nirmata instance.
- `TOKEN` - Your Nirmata API token.
- `teamname` - The name of the team you want to grant permissions to.
- `clustername` - The name of the cluster for which you want to grant permissions.
- `Permission` - The permission level to grant (e.g., read, write, admin).
- `EnvironmentName` - One or more environment names to which you want to grant permissions.

The script will iterate through the specified environment names and set the specified permissions accordingly.

## Example

Here's an example of how to use the script:

```bash
./nirmata-access-control.sh https://your-nirmata-url.com your-api-token MyTeam MyCluster view Development Production
```

This command grants "view" permissions to the "MyTeam" for the "Development" and "Production" environments in the "MyCluster" cluster.

