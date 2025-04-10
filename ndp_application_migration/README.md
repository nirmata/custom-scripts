# NDP Application Migration Scripts

This repository contains scripts to facilitate the migration of applications between environments in Nirmata.

## Prerequisites
- `curl` installed
- `jq` installed
- Bash shell
- Nirmata API access token
- Access to source and destination environments

## Overview
The repository contains three main scripts:

1. **restore_env_settings.sh**
   - Restores environment settings from backup
   - Handles environment-specific configurations
   - Validates environment access and permissions
   - Supports transaction-based updates

2. **migrate_env_apps_to_catalog.sh**
   - Migrates applications from environments to catalogs
   - Preserves Git repository configurations
   - Handles Git credentials securely
   - Creates unique application names with timestamps
   - Supports automatic catalog creation
   - Implements enhanced error handling and logging
   - Uses transaction-based updates for reliability

3. **update_catalog_references.sh**
   - Updates catalog references in environments
   - Maintains application relationships
   - Implements intelligent pattern matching for catalog applications
   - Supports multiple naming patterns for catalog lookup
   - Uses transaction-based updates for reliability
   - Enhanced error handling and logging
   - Automatic retry mechanism for failed updates

## Migration Process

### Step 1: Environment Settings Restoration
```bash
./restore_env_settings.sh <api_endpoint> <token> <cluster_name>
```

### Step 2: Application Migration to Catalog
```bash
./migrate_env_apps_to_catalog.sh <api_endpoint> <token> <source_cluster_name> <destination_cluster_name>
```

### Step 3: Update Catalog References
```bash
./update_catalog_references.sh <api_endpoint> <token> <source_cluster_name> <destination_cluster_name>
```

## Example Commands
```bash
# Restore environment settings
./restore_env_settings.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration"

# Migrate applications to catalog
./migrate_env_apps_to_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"

# Update catalog references
./update_catalog_references.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

## Log Files
- Migration logs: `logs/migration_<cluster_name>.log`
- Catalog reference update logs: `logs/catalog_reference_update_<timestamp>.log`
- Error logs: `logs/error_<timestamp>.log`
- Debug logs: `logs/debug_<timestamp>.log`

## Environment and Catalog Correlation
- Environment names are used as catalog names
- Applications maintain their base names with cluster suffixes
- Timestamps are added to prevent naming conflicts
- Intelligent pattern matching for catalog application lookup
- Support for multiple naming conventions

## Git Credential Handling
The migration script includes enhanced Git credential management:
- Preserves Git credential names without copying sensitive data
- Supports both `credential` and `gitCredential` field formats
- Stores credential names in `additionalProperties`
- Maintains security by only transferring credential references
- Example: "git-vikash" credential name is preserved while sensitive data remains secure

## Important Notes
1. Run scripts in the correct order
2. Verify environment access before migration
3. Check Git credential configuration
4. Monitor logs during migration
5. Validate application state post-migration
6. Ensure proper permissions for API operations
7. Verify catalog application existence before updates

## Version Compatibility
- Tested with Nirmata API v1.0
- Compatible with current Git credential formats
- Supports modern Kubernetes versions
- Enhanced error handling and logging
- Transaction-based updates for reliability

## Troubleshooting Common Issues

### Authentication Errors
- Verify API token validity
- Check token permissions
- Ensure correct API endpoint
- Validate token format and encoding

### Git Credential Issues
- Verify credential existence in destination
- Check credential name format
- Validate Git repository access
- Ensure proper credential permissions

### Application Migration Failures
- Check application dependencies
- Verify Git repository accessibility
- Review naming conflicts
- Monitor transaction logs
- Check for existing catalog applications

### Catalog Creation Issues
- Verify permissions
- Check for existing catalogs
- Review catalog naming conventions
- Validate catalog application existence
- Check pattern matching results

## Support
For issues or questions:
1. Check the logs in the `logs` directory
2. Review error messages and transaction logs
3. Verify configuration and permissions
4. Contact support team with log files

## Best Practices
1. Test in non-production first
2. Backup before migration
3. Follow migration order
4. Monitor progress through logs
5. Validate results after each step
6. Keep API tokens secure
7. Use transaction-based updates
8. Monitor pattern matching results

