# Nirmata Environment Management Scripts

This repository contains scripts for managing environments and catalog references in Nirmata.

## Scripts

### 1. Environment Restore Script (restore_env_settings.sh)

This script copies environment settings from source environments to target environments in Nirmata.

#### Prerequisites

- Bash shell
- `curl` command-line tool
- `jq` JSON processor
- Nirmata API token with appropriate permissions

#### Usage

```bash
./restore_env_settings.sh <api_endpoint> <token> <source_suffix> <target_suffix>
```

Example:
```bash
./restore_env_settings.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

#### Features

- Copies all environment settings including:
  - Resource quotas
  - Limit ranges
  - Team permissions (ACLs)
  - Labels
  - Update policies
  - Resource types
- Maintains environment relationships
- Handles system and user environments
- Provides detailed logging
- Includes error handling and validation

### 2. Catalog Reference Update Script (update_catalog_references.sh)

This script updates catalog references for applications between source and target clusters in Nirmata.

#### Prerequisites

- Bash shell
- `curl` command-line tool
- `jq` JSON processor
- Nirmata API token with appropriate permissions

#### Usage

```bash
./update_catalog_references.sh <api_endpoint> <token> <source_cluster> <target_cluster>
```

Example:
```bash
./update_catalog_references.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

#### Features

- Automatically finds matching environments between source and target clusters
- Updates catalog references for applications
- Handles both Git and catalog-based applications
- Maintains detailed logs of all operations
- Supports error handling and validation

## Directory Structure

```
.
├── custom-scripts/
│   ├── environment-restore/
│   │   └── restore_env_settings.sh
│   └── catalog-reference-update/
│       └── update_catalog_references.sh
└── logs/
    ├── environment_restore_*.log
    └── catalog_reference_update_*.log
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request

## Error Handling

Both scripts include comprehensive error handling for:
- Invalid API responses
- Missing environments or applications
- Failed updates
- Invalid JSON responses
- Missing references or permissions

## Logging

The scripts create detailed logs in the `logs` directory with timestamps. Each log file contains:
- API endpoint and cluster information
- Environment processing details
- Operation results
- Any errors or warnings encountered 