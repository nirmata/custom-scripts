# Nirmata Cluster Details Extractor

A shell script for extracting and reporting Kubernetes cluster information from the Nirmata API.

## Overview

This script connects to the Nirmata API and generates detailed reports about your Kubernetes clusters, including:

- Cluster information (name, version, status, nodes, etc.)
- Pod counts
- Application counts (deployments, statefulsets, daemonsets)
- Namespace information
- Node details

## Usage

```bash
./get_cluster_details.sh <API_ENDPOINT> <API_TOKEN> [ENV_NAME] [test_mode]
```

### Parameters

- `API_ENDPOINT`: Your Nirmata API endpoint (e.g., https://pe420.nirmata.co)
- `API_TOKEN`: Your Nirmata API token
- `ENV_NAME` (optional): Filter by environment type (DEV, PROD, QA, etc.)
- `test_mode` (optional): Generate sample data for testing purposes

### Example

```bash
./get_cluster_details.sh https://pe420.nirmata.co "YOUR_API_TOKEN"
```

To filter for production environments only:

```bash
./get_cluster_details.sh https://pe420.nirmata.co "YOUR_API_TOKEN" PROD
```

To generate test data:

```bash
./get_cluster_details.sh https://example.nirmata.co "dummy_token" test_mode
```

## Output Files

The script generates several CSV files with timestamps in their names:

1. **cluster_summary_TIMESTAMP.csv** - One line per cluster with high-level metrics (executive view)
2. **cluster_consolidated_TIMESTAMP.csv** - One line per cluster with all details
3. **cluster_details_TIMESTAMP.csv** - One line per namespace (technical view)
4. **application_details_TIMESTAMP.csv** - Detailed application information
5. **pod_details_TIMESTAMP.csv** - Detailed pod information
6. **node_details_TIMESTAMP.csv** - Detailed node information

## Key Features

- Retrieves real-time data from Nirmata API
- Handles disconnected clusters gracefully
- Provides multiple levels of detail in different output files
- Counts applications and pods across different resource types
- Includes fallback methods to ensure accurate reporting
- Test mode for generating sample data

## Requirements

- bash
- curl
- jq (for JSON parsing)
- Internet access to your Nirmata API endpoint

## Troubleshooting

If the CSV files contain minimal data, this could indicate:
1. The API credentials are incorrect or have insufficient permissions
2. There are no clusters or environments in the Nirmata instance
3. The API endpoint format is incorrect

## License

MIT 