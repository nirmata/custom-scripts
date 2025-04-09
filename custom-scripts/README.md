# custom-scripts

Collection of helper scripts for Nirmata Platform Engineering.

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

