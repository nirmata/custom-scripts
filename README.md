# Nirmata Environment Management Scripts

This repository contains scripts for managing Nirmata environments, catalog references, and environment migrations.

## Scripts

### migrate_env_apps_to_catalog.sh

This script migrates environment applications to catalogs in Nirmata.

#### Prerequisites

- Bash shell
- `curl` command-line tool
- `jq` JSON processor
- Nirmata API token with appropriate permissions

#### Usage

```bash
./migrate_env_apps_to_catalog.sh <api_endpoint> <token> <source_cluster> <target_cluster>
```

Example:
```bash
./migrate_env_apps_to_catalog.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

#### Features

- Creates catalogs for applications
- Migrates Git-based applications to catalog applications
- Maintains application configurations and settings
- Handles error cases and validation
- Provides detailed logging

### restore_env_settings.sh

This script restores environment settings from a source environment to a target environment.

#### Usage

```bash
./restore_env_settings.sh <api_endpoint> <token> <source_cluster> <target_cluster>
```

#### Features

- Copies environment settings including:
  - Resource quotas
  - Limit ranges
  - Team permissions (ACLs)
  - Labels
  - Update policies
- Handles system and user environments
- Maintains environment type and configurations
- Provides detailed logging and error handling

### update_catalog_references.sh

This script updates catalog references for applications between source and target clusters in Nirmata.

#### Usage

```bash
./update_catalog_references.sh <api_endpoint> <token> <source_cluster> <target_cluster>
```

#### Features

- Automatically finds matching environments between source and target clusters
- Updates catalog references for applications
- Handles both Git and catalog-based applications
- Maintains detailed logs of all operations
- Supports error handling and validation

## Common Parameters

For all scripts:
- `api_endpoint`: The Nirmata API endpoint URL
- `token`: Nirmata API token for authentication
- `source_cluster`: Name of the source cluster
- `target_cluster`: Name of the target cluster

## Logging

All scripts create detailed logs in the `logs` directory with timestamps. Each log file contains:
- API endpoint and cluster information
- Environment processing details
- Operation results
- Any errors or warnings encountered

## Directory Structure

```
.
├── custom-scripts/
│   ├── catalog-reference-update/
│   │   └── update_catalog_references.sh
│   ├── env_to_catalog_migration/
│   │   └── migrate_env_apps_to_catalog.sh
│   └── environment-restore/
│       └── restore_env_settings.sh
└── logs/
    └── *.log
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request 