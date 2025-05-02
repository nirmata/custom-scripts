# Nirmata Cluster Extractor

A bash script to extract and report Kubernetes cluster information from the Nirmata API.

## Overview

This utility generates comprehensive reports about Kubernetes clusters managed by Nirmata, including:

- Cluster metadata (name, type, region, status)
- Node information (count, types, capacity)
- Application/controller details (deployments, statefulsets)
- Pod information
- Environment/namespace details

## Output Files

The script generates multiple CSV files:

- **cluster_summary_{timestamp}.csv**: One line per cluster with essential metrics (executive view)
- **cluster_consolidated_{timestamp}.csv**: Comprehensive single-line summary per cluster
- **cluster_details_{timestamp}.csv**: Detailed view with one line per namespace
- **application_details_{timestamp}.csv**: Information about deployments, statefulsets, etc.
- **pod_details_{timestamp}.csv**: Pod-level details
- **node_details_{timestamp}.csv**: Node-level information

## Usage

```bash
./get_cluster_details.sh <API_ENDPOINT> <API_TOKEN> [ENV_NAME] [test_mode]
```

### Parameters:

- **API_ENDPOINT**: Your Nirmata API endpoint (e.g., https://pe420.nirmata.co)
- **API_TOKEN**: Your Nirmata API token
- **ENV_NAME** (optional): Filter results to a specific environment (e.g., DEV, PROD)
- **test_mode** (optional): Generate sample data instead of querying the API

### Examples:

```bash
# Query all environments
./get_cluster_details.sh https://pe420.nirmata.co YOUR_API_TOKEN

# Filter for production environments only
./get_cluster_details.sh https://pe420.nirmata.co YOUR_API_TOKEN PROD

# Generate test data
./get_cluster_details.sh https://pe420.nirmata.co YOUR_API_TOKEN test_mode
```

## Requirements

- bash
- curl
- jq
- bc (for calculations)

## Installation

1. Clone this repository or download the script
2. Make the script executable: `chmod +x get_cluster_details.sh`
3. Run the script with appropriate parameters

## Notes

- The API token requires sufficient permissions to access cluster, namespace, and pod information
- For larger clusters, the script may take some time to run due to multiple API calls
- The test_mode parameter can be used to verify the script functionality without accessing the API

## Key Features

- Retrieves real-time data from Nirmata API
- Handles disconnected clusters gracefully
- Provides multiple levels of detail in different output files
- Counts pods, containers, and applications across different resource types
- Includes fallback methods to ensure accurate reporting
- Test mode for generating sample data

## Troubleshooting

If the CSV files contain minimal data, this could indicate:
1. The API credentials are incorrect or have insufficient permissions
2. There are no clusters or environments in the Nirmata instance
3. The API endpoint format is incorrect

## License

MIT 