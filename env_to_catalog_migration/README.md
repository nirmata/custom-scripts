# Environment to Catalog Migration Scripts

This directory contains scripts for migrating environment settings to catalog environments in Nirmata.

## Scripts Overview

### copy_to_catalog.sh

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