# Catalog Reference Update Script

This repository contains scripts for managing catalog references in Nirmata environments.

## Scripts

### update_catalog_references.sh

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

#### Parameters

- `api_endpoint`: The Nirmata API endpoint URL
- `token`: Nirmata API token for authentication
- `source_cluster`: Name of the source cluster
- `target_cluster`: Name of the target cluster

#### Features

- Automatically finds matching environments between source and target clusters
- Updates catalog references for applications
- Handles both Git and catalog-based applications
- Maintains detailed logs of all operations
- Supports error handling and validation

#### Logging

The script creates detailed logs in the `logs` directory with timestamps. Each log file contains:
- API endpoint and cluster information
- Environment processing details
- Application updates and their results
- Any errors or warnings encountered

#### Error Handling

The script includes comprehensive error handling for:
- Invalid API responses
- Missing environments
- Failed application updates
- Invalid JSON responses
- Missing catalog references

## Directory Structure

```
.
├── custom-scripts/
│   └── catalog-reference-update/
│       └── update_catalog_references.sh
└── logs/
    └── catalog_reference_update_*.log
```

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a new Pull Request 