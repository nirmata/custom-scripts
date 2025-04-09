# NDP Application Migration Scripts

This directory contains scripts for migrating applications between environments in Nirmata. The migration process is divided into three main steps, each handled by a specific script.

## Prerequisites

Before running these scripts, ensure you have:
- Bash shell environment
- `curl` for API calls
- `jq` for JSON processing
- Nirmata API access token with appropriate permissions
- Access to both source and destination clusters

## Scripts Overview

### 1. Environment Settings Restoration (`environment-restore/restore_env_settings.sh`)

This script copies environment settings from a source cluster to a destination cluster. It handles:
- Environment creation if not present
- ACLs and permissions
- Resource quotas and limit ranges
- Labels and update policies

**Usage:**
```bash
./restore_env_settings.sh <api-url> <token> <source-cluster> <destination-cluster>
```

### 2. Environment to Catalog Migration (`env_to_catalog_migration/migrate_env_apps_to_catalog.sh`)

This script moves applications from environments to catalogs. It:
- Identifies applications in source environments
- Creates corresponding catalog applications
- Handles Git-based applications appropriately

**Usage:**
```bash
./migrate_env_apps_to_catalog.sh <api-url> <token> <source-cluster>
```

### 3. Catalog Reference Update (`catalog-reference-update/update_catalog_references.sh`)

This script updates catalog references for applications in the destination cluster. It:
- Maps environments to catalogs
- Updates application references to point to catalog applications

**Usage:**
```bash
./update_catalog_references.sh <api-url> <token> <source-cluster> <destination-cluster>
```

## Migration Process

1. First, run `restore_env_settings.sh` to copy environment settings and create environments
2. Then, run `migrate_env_apps_to_catalog.sh` to move applications to catalogs
3. Finally, run `update_catalog_references.sh` to update application references

## Example Commands

```bash
# Step 1: Restore environment settings
./restore_env_settings.sh https://pe420.nirmata.co "your-token" "123-app-migration" "129-app-migration"

# Step 2: Migrate applications to catalog
./migrate_env_apps_to_catalog.sh https://pe420.nirmata.co "your-token" "123-app-migration"

# Step 3: Update catalog references
./update_catalog_references.sh https://pe420.nirmata.co "your-token" "123-app-migration" "129-app-migration"
```

## Log Files

Each script generates detailed logs in the following locations:
- Environment restore: `logs/environment_restore_YYYYMMDD_HHMMSS.log`
- Catalog migration: `logs/catalog_migration_YYYYMMDD_HHMMSS.log`
- Reference update: `logs/catalog_reference_update_YYYYMMDD_HHMMSS.log`

## Environment and Catalog Correlations

### Environment Name Handling

The scripts handle different environment naming patterns:

1. **Environments with Cluster Suffix**:
   - Source: `default-123-app-migration`
   - Destination: `default-129-app-migration`

2. **Environments without Cluster Suffix**:
   - Source: `nginx`
   - Destination: `nginx-129-app-migration` (created by Commvault)

### Commvault Behavior

When Commvault restores namespaces:
- It appends the cluster name to the namespace: `ns_name-$(cluster-name)`
- The script expects this behavior and maps environments accordingly

### Example Scenarios

1. **Environment with Cluster Suffix**:
   ```
   Source: default-123-app-migration
   Destination: default-129-app-migration
   Action: Direct mapping, copy all settings
   ```

2. **Environment without Suffix**:
   ```
   Source: nginx
   Destination: nginx-129-app-migration (created by Commvault)
   Action: Wait for Commvault restore, then copy settings
   ```

3. **Mixed Environment Names**:
   ```
   Source: [mix of suffixed and non-suffixed names]
   Destination: [Commvault-restored names with cluster suffix]
   Action: Handle each case appropriately
   ```

## Important Notes

1. **Order of Operations**:
   - Always restore environment settings first
   - Then migrate applications to catalogs
   - Finally update catalog references

2. **Error Handling**:
   - Each script logs errors and continues processing
   - Failed operations are logged for review
   - Scripts can be run multiple times safely

3. **Idempotency**:
   - All scripts are idempotent
   - Running them multiple times produces the same result
   - Existing settings are updated rather than duplicated

4. **Environment Creation**:
   - The restore script creates missing environments
   - It handles both pre-existing and Commvault-restored environments
   - Settings are copied only after environment creation

5. **Catalog Mapping**:
   - Catalogs are mapped using environment base names
   - The update script finds the correct catalog for each environment
   - Application references are updated to point to catalog applications

## Version Compatibility

These scripts are compatible with:
- Nirmata Enterprise Platform 3.0 and above
- Kubernetes 1.20 and above
- Commvault 11.22 and above

## Troubleshooting

### Common Issues and Solutions

1. **"Environment not found" error**:
   - Verify the environment name exists in the source cluster
   - Check if the environment name follows the expected pattern
   - Ensure you have the correct permissions to access the environment

2. **"Failed to create environment" error**:
   - Verify the destination cluster has sufficient resources
   - Check if an environment with the same name already exists
   - Ensure your token has permissions to create environments

3. **"Catalog application not found" error**:
   - Run the migration script first to create catalog applications
   - Verify the catalog name matches the environment base name
   - Check if the application exists in the catalog

4. **"API connection failed" error**:
   - Verify the API URL is correct and accessible
   - Check if your token is valid and not expired
   - Ensure network connectivity between your machine and the API

### Error Messages

Common error messages and their meanings:

1. **"environments:null not found"**:
   - The environment ID is null or invalid
   - The environment doesn't exist in the specified cluster

2. **"No access control list found in destination environment"**:
   - The destination environment doesn't have an ACL configured
   - The script will create a new ACL with default permissions

3. **"Destination environment not found. This is expected if Commvault hasn't restored it yet"**:
   - The script will attempt to create the environment
   - If creation fails, wait for Commvault to restore it

4. **"Failed to update catalog reference"**:
   - The catalog application doesn't exist
   - The application name doesn't match between environment and catalog

