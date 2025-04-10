# Catalog Reference Update Script

This script automates the process of updating catalog references for applications in Nirmata environments. It handles the migration of catalog references from one cluster to another, with robust error handling and retry mechanisms.

## Features

- **Automated Catalog Reference Updates**: Automatically finds and updates catalog references for applications
- **Robust Error Handling**: 
  - Retries failed operations with exponential backoff
  - Handles various HTTP error codes (401, 403, 404, 429, 500, etc.)
  - Provides detailed error messages and logging
- **Transaction Safety**: Ensures updates are performed safely with proper error handling
- **Comprehensive Logging**: Detailed logs with timestamps for all operations
- **Pattern Matching**: Supports multiple patterns for finding catalog applications:
  - `app-{name}-{cluster}`
  - `app-{name}`
  - `{name}`
  - `{name}-{timestamp}`

## Prerequisites

- Bash shell
- `curl` command-line tool
- `jq` JSON processor
- Nirmata API access token
- Source and target cluster information

## Usage

```bash
./update_catalog_references.sh <api_endpoint> <token> <source_cluster> <target_cluster>
```

### Parameters

- `api_endpoint`: The Nirmata API endpoint (e.g., https://pe420.nirmata.co)
- `token`: Your Nirmata API token
- `source_cluster`: The source cluster name (e.g., 123-app-migration)
- `target_cluster`: The target cluster name (e.g., 129-app-migration)

### Example

```bash
./update_catalog_references.sh https://pe420.nirmata.co YOUR_TOKEN 123-app-migration 129-app-migration
```

## Error Handling

The script includes comprehensive error handling:

1. **Authentication Errors (401)**
   - Validates token at startup
   - Provides clear error messages for authentication failures

2. **Permission Errors (403)**
   - Checks access rights
   - Logs detailed permission-related issues

3. **Resource Not Found (404)**
   - Handles missing resources gracefully
   - Provides specific error messages for missing applications

4. **Rate Limiting (429)**
   - Implements exponential backoff
   - Automatically retries after waiting

5. **Server Errors (500, 502, 503, 504)**
   - Retries with increasing delays
   - Maximum of 3 retry attempts

## Logging

- Logs are stored in the `logs` directory
- Each run creates a timestamped log file
- Log format: `catalog_reference_update_YYYYMMDD_HHMMSS.log`
- Includes detailed information about:
  - Authentication status
  - Environment processing
  - Application updates
  - Errors and retries
  - Success/failure counts

## Output

The script provides:
- Real-time progress updates
- Success/failure counts
- List of failed applications
- Detailed error messages
- Summary report at completion

## Troubleshooting

1. **Authentication Issues**
   - Verify your API token is valid
   - Check token permissions
   - Ensure token is properly formatted

2. **Missing Catalog Applications**
   - Verify catalog applications exist
   - Check naming patterns
   - Ensure proper cluster configuration

3. **Update Failures**
   - Check application permissions
   - Verify API endpoint accessibility
   - Review log files for specific errors

## Support

For issues or questions:
1. Check the log files in the `logs` directory
2. Review error messages in the console output
3. Contact Nirmata support with the log file reference 