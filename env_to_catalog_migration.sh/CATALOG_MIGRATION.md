# Catalog Migration Scripts

This directory contains scripts to help migrate applications from environment-based deployments to catalog-based deployments in Nirmata.

## Overview

The migration process involves several steps:

1. Identify applications in an environment
2. Extract application details (Git repository, branch, path)
3. Create a catalog entry for each application
4. Deploy the application from the catalog to the environment

Each step is implemented as a separate script, allowing you to test and verify each part of the process independently.

## Scripts

### 1. List Environment Applications

**Script:** `list_env_apps.sh`

Lists all applications in a specified environment.

```bash
./list_env_apps.sh <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME> <ENVIRONMENT_NAME>
```

Example:
```bash
./list_env_apps.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "129-app-migration" "new-migration"
```

### 2. Get Application Details

**Script:** `get_app_details.sh`

Retrieves detailed information about a specific application, including Git repository details.

```bash
./get_app_details.sh <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <APPLICATION_ID>
```

Example:
```bash
./get_app_details.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "env-id-123" "app-id-456"
```

### 3. Create Catalog Entry

**Script:** `create_catalog_entry.sh`

Creates a catalog entry for an application based on its Git repository details.

```bash
./create_catalog_entry.sh <API_ENDPOINT> <API_TOKEN> <APP_NAME> <GIT_REPO> [GIT_BRANCH] [GIT_PATH]
```

Example:
```bash
./create_catalog_entry.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "my-app" "https://github.com/org/repo.git" "main" "path/to/manifests"
```

### 4. Deploy from Catalog

**Script:** `deploy_from_catalog.sh`

Deploys an application from the catalog to a specified environment.

```bash
./deploy_from_catalog.sh <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <CATALOG_ID> <APP_NAME>
```

Example:
```bash
./deploy_from_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "env-id-123" "catalog-id-456" "my-app"
```

## Complete Migration Process

To migrate all applications in an environment to catalog-based deployments, follow these steps:

1. List all applications in the environment:
   ```bash
   ./list_env_apps.sh <API_ENDPOINT> <API_TOKEN> <CLUSTER_NAME> <ENVIRONMENT_NAME>
   ```

2. For each application, get its details:
   ```bash
   ./get_app_details.sh <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <APPLICATION_ID>
   ```

3. Create a catalog entry for each application:
   ```bash
   ./create_catalog_entry.sh <API_ENDPOINT> <API_TOKEN> <APP_NAME> <GIT_REPO> <GIT_BRANCH> <GIT_PATH>
   ```

4. Deploy each application from the catalog:
   ```bash
   ./deploy_from_catalog.sh <API_ENDPOINT> <API_TOKEN> <ENVIRONMENT_ID> <CATALOG_ID> <APP_NAME>
   ```

## Prerequisites

- `curl` command-line tool
- `jq` JSON processor
- Access to Nirmata API endpoints
- Valid API token with appropriate permissions

## Notes

- Make sure to test each script individually before running the complete migration process
- The scripts include error handling and will provide detailed output for troubleshooting
- Consider backing up your environment before starting the migration process 