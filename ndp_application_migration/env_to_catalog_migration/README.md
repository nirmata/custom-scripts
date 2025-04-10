# Environment to Catalog Migration Scripts

This directory contains scripts for migrating environment settings to catalog environments in Nirmata.

## Scripts Overview

### migrate_env_apps_to_catalog.sh

This script facilitates the migration of applications from environments to catalogs. It's designed to:
- Migrate Git-based applications to catalogs
- Preserve Git repository configurations including credentials
- Handle application naming with destination cluster suffixes
- Create catalogs automatically if they don't exist

#### Usage
```bash
./migrate_env_apps_to_catalog.sh <api_endpoint> <token> <source_cluster_name> <destination_cluster_name>
```

Example:
```bash
./migrate_env_apps_to_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

#### Features
- Automatic catalog creation based on environment names
- Git-based application migration with credential preservation
- Intelligent application naming with destination cluster suffixes
- Automatic handling of name conflicts with timestamps
- Git credential name preservation (without copying sensitive data)
- Detailed logging of migration process

## Requirements
- `curl` for API calls
- `jq` for JSON processing
- Bash shell
- Nirmata API access token with appropriate permissions
- Access to source environments and catalogs

## Git Credential Handling
The script now includes improved Git credential handling:
- Preserves Git credential references with proper structure
- Sets credential in both `additionalProperties.credential` and `gitCredential` fields
- Uses the correct service name ("Environments") and modelIndex ("GitCredential")
- Maintains credential ID references for proper UI integration
- Does not copy sensitive credential data (username/password)
- Ensures proper credential display in the UI
- Supports both credential field formats for compatibility

Example credential structure:
```json
{
  "additionalProperties": {
    "credential": {
      "service": "Environments",
      "modelIndex": "GitCredential",
      "id": "credential-id"
    }
  },
  "gitCredential": {
    "service": "Environments",
    "modelIndex": "GitCredential",
    "id": "credential-id"
  }
}
```

## Error Handling
- Comprehensive error checking for:
  - API authentication
  - Environment existence
  - Git upstream validation
  - Application creation
  - Credential reference validation
- Detailed logging for troubleshooting

## Best Practices
1. Verify environment names and access before migration
2. Ensure Git credentials are properly configured in the destination
3. Test migration in a non-production setup first
4. Monitor migration progress and check logs
5. Validate all settings post-migration

## Migration Process
1. **Pre-migration Checks**
   - Validate source environment existence
   - Check cluster name validity
   - Verify API access

2. **Application Migration**
   - Create catalog if needed
   - Process Git-based applications
   - Copy Git repository details
   - Preserve credential references
   - Handle naming conflicts

3. **Post-migration Validation**
   - Verify application creation
   - Check Git upstream configuration
   - Validate credential references
   - Ensure proper application naming

## Troubleshooting
- Check API response codes for errors
- Verify token permissions
- Ensure environment names are correct
- Review logs for detailed error messages
- Verify Git credential configuration

## copy_to_catalog.sh

This script facilitates the migration of environment settings to catalog environments. It's designed to:
- Copy complete environment configurations
- Handle application settings and deployments
- Preserve Git repository configurations
- Maintain environment-specific settings

#### Usage
```bash
./copy_to_catalog.sh <api_endpoint> <token> <source_env> <destination_env>
```

Example:
```bash
./copy_to_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "nginx-123-app-migration" "nginx-catalog"
```

#### Features
- Complete environment configuration copying
- Application deployment settings migration
- Git repository configuration preservation
- Resource settings transfer:
  - Resource quotas
  - Limit ranges
  - Access controls
  - Update policies
  - Labels
- Automatic validation of source and destination environments

## Requirements
- `curl` for API calls
- `jq` for JSON processing
- Bash shell
- Nirmata API access token with appropriate permissions
- Access to both source environment and catalog

## Error Handling
- Comprehensive error checking for:
  - API authentication
  - Environment existence
  - Permission validation
  - Resource availability
- Detailed logging for troubleshooting

## Best Practices
1. Verify environment names and access before migration
2. Ensure catalog environment is properly configured
3. Back up source environment settings
4. Test migration in a non-production setup first
5. Monitor migration progress and check logs
6. Validate all settings post-migration

## Migration Process
1. **Pre-migration Checks**
   - Validate source environment existence
   - Verify catalog environment accessibility
   - Check required permissions

2. **Configuration Copy**
   - Copy basic environment settings
   - Transfer resource configurations
   - Migrate application settings
   - Copy Git repository details

3. **Post-migration Validation**
   - Verify all settings were copied
   - Check application configurations
   - Validate resource settings
   - Ensure proper access controls

## Troubleshooting
- Check API response codes for errors
- Verify token permissions
- Ensure environment names are correct
- Review logs for detailed error messages 