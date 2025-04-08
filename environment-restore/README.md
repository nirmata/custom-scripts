# Environment Restore Script

This script automates the process of copying environment settings from a source cluster to a destination cluster in Nirmata.

## Features

- Monitors environments for restored namespaces
- Copies the following settings from source to destination:
  - Resource Quotas
  - Limit Ranges
  - Access Controls (Permissions)
  - Update Policies
  - Labels

## Prerequisites

- `curl` command-line tool
- `jq` JSON processor
- Access to Nirmata API endpoints
- Valid API token with appropriate permissions

## Usage

```bash
./restore_env_settings.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_CLUSTER> <DEST_CLUSTER>
```

### Parameters

- `API_ENDPOINT`: The Nirmata API endpoint (e.g., https://pe420.nirmata.co)
- `API_TOKEN`: The encrypted API token for authentication
- `SOURCE_CLUSTER`: Name of the source cluster
- `DEST_CLUSTER`: Name of the destination cluster

### Example

```bash
./restore_env_settings.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

## How it Works

1. The script monitors both source and destination clusters for environments
2. When a restored namespace is detected in the destination cluster
3. It copies all settings from the corresponding source environment to the destination
4. Settings are copied in the following order:
   - Resource Quotas
   - Limit Ranges
   - Access Controls
   - Update Policies
   - Labels

## Error Handling

- The script includes error handling for API calls
- Invalid or missing settings are skipped with appropriate warnings
- JSON parsing errors are handled gracefully

## Notes

- Make sure you have the necessary permissions in both clusters
- The script will skip environments that don't exist in either cluster
- Existing settings in the destination environment will be overwritten 