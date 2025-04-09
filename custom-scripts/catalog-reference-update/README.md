# Catalog Reference Update Script

This script updates catalog application references in restored environments. It's designed to ensure that applications in restored environments point to the correct catalog applications.

## Use Case

When environments are restored from one cluster to another (e.g., from cluster-123 to cluster-129), the applications in the restored environments need to be updated to point to their corresponding catalog applications. This script automates that process.

Example scenario:
- Source environment (old cluster): nginx-123-app-migration
- Restored environment (new cluster): nginx-129-app-migration
- Need: Update nginx-129-app-migration to use the same catalog application as nginx-123-app-migration

## Features

- Automatically finds corresponding environments between source and target clusters
- Updates catalog application references in restored environments
- Preserves catalog application relationships
- Handles all environments in the target cluster
- Provides detailed logging of all updates
- Validates catalog application existence before updating

## Prerequisites

- `bash` shell
- `curl` for API calls
- `jq` for JSON processing
- Nirmata API access token with appropriate permissions
- Access to both source and target clusters

## Usage

```bash
./update_catalog_references.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_CLUSTER> <TARGET_CLUSTER>
```

Example:
```bash
./update_catalog_references.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

## Script Process

1. **Environment Discovery**
   - Lists all environments in source cluster
   - Lists all environments in target cluster
   - Maps corresponding environments based on names

2. **Catalog Reference Collection**
   - Gets catalog application references from source environments
   - Validates catalog application existence

3. **Reference Update**
   - Updates catalog application references in target environments
   - Maintains application settings and configurations

4. **Validation**
   - Verifies successful updates
   - Checks application accessibility
   - Validates catalog application relationships

## Logging

The script creates detailed logs in the `logs` directory:
- Operation timestamps
- Environment mappings
- Catalog application details
- Update status and results
- Any errors or warnings

## Error Handling

- Validates input parameters
- Checks API responses
- Verifies environment existence
- Validates catalog application accessibility
- Provides clear error messages and suggestions

## Best Practices

1. Run in test environment first
2. Verify environment names match between clusters
3. Ensure API token has sufficient permissions
4. Review logs after execution
5. Validate application functionality after update 