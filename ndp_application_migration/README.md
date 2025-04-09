# NDP Application Migration Scripts

This directory contains scripts for migrating applications and their settings between Nirmata environments and catalogs. The migration process is divided into three main steps, each handled by a specific script.

## Scripts Overview

### 1. Environment Settings Restoration (`environment-restore/restore_env_settings.sh`)

This script copies environment settings from a source cluster to a destination cluster.

**Functionality:**
- Automatically creates missing environments in the destination cluster
- Copies environment settings including:
  - Resource types
  - Access Control Lists (ACLs) and permissions
  - Resource quotas
  - Limit ranges
- Maintains team permissions and access controls
- Creates detailed logs of all operations

**Usage:**
```bash
./restore_env_settings.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_CLUSTER> <DEST_CLUSTER>
```

### 2. Environment to Catalog Migration (`env_to_catalog_migration/migrate_env_apps_to_catalog.sh`)

This script migrates applications from environment-based deployments to catalog-based deployments.

**Functionality:**
- Finds all environments in the source cluster
- Identifies Git-based applications in each environment
- Creates corresponding catalog applications with the same configuration
- Migrates Git upstream settings and repository information
- Handles duplicate application names by appending timestamps
- Skips non-Git-based applications (like system applications)

**Usage:**
```bash
./migrate_env_apps_to_catalog.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_CLUSTER>
```

### 3. Catalog Reference Update (`catalog-reference-update/update_catalog_references.sh`)

This script updates catalog references for applications in the destination environment.

**Functionality:**
- Maps environment applications to their catalog counterparts
- Updates application references to point to the correct catalog versions
- Maintains application configurations and settings
- Handles cases where catalog applications don't exist
- Creates detailed logs of reference updates

**Usage:**
```bash
./update_catalog_references.sh <API_ENDPOINT> <API_TOKEN> <SOURCE_CLUSTER> <DEST_CLUSTER>
```

## Migration Process

The scripts should be run in the following order:

1. First, run `restore_env_settings.sh` to copy environment settings and create environments
2. Then, run `migrate_env_apps_to_catalog.sh` to move applications to catalogs
3. Finally, run `update_catalog_references.sh` to update application references

## Example

```bash
# Step 1: Restore environment settings
./environment-restore/restore_env_settings.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"

# Step 2: Migrate applications to catalog
./env_to_catalog_migration/migrate_env_apps_to_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration"

# Step 3: Update catalog references
./catalog-reference-update/update_catalog_references.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

## Logs

Each script creates detailed logs in the following locations:
- Environment to Catalog Migration: `./migration_<cluster-name>.log`
- Environment Settings Restoration: `./restore_env_settings_<timestamp>.log`
- Catalog Reference Update: `./catalog_reference_update_<timestamp>.log`

## Notes

- All scripts include error handling and logging
- Scripts can be run multiple times safely (idempotent)
- Non-Git-based applications are automatically skipped
- Missing environments are automatically created in the destination cluster
- Team permissions and access controls are preserved during migration

## Available Scripts

### Environment to Catalog Migration
Located in `env_to_catalog_migration/`, this script migrates Git-based applications from Nirmata environments to catalogs. It automatically handles existing applications and creates new ones with unique names when needed.

Features:
- Migrates Git-based applications from environments to catalogs
- Automatically creates corresponding catalogs if they don't exist
- Handles existing applications by creating new ones with unique names
- Preserves Git repository configuration (URL, branch, path)
- Maintains application state and labels
- Provides detailed logging of the migration process

Usage:
```bash
./env_to_catalog_migration/migrate_env_apps_to_catalog.sh <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME>
```

Example:
```bash
./env_to_catalog_migration/migrate_env_apps_to_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration"
```

For detailed documentation, see [Environment to Catalog Migration](env_to_catalog_migration/README.md).

### Backup Script
The backup script runs daily at 3am and outputs to a log file:
```bash
0 3 * * 0-6 /usr/bin/nirmata-backup.sh > /var/log/nirmatabackup.txt
```

## Prerequisites
- `bash` shell
- `curl` for API calls
- `jq` for JSON processing
- Nirmata API access token with appropriate permissions

## Contributing
When adding new scripts:
1. Create a new directory for your script if it's a complex tool
2. Include a README.md with usage instructions
3. Add error handling and logging
4. Document prerequisites and dependencies
5. Update this main README.md with your script's information

