# Catalog Reference Update Script

This script updates catalog references for applications in restored environments after a cluster migration. It handles various application types and naming patterns, ensuring proper catalog references are maintained.

## Features

- Updates catalog references for all applications in restored environments
- Handles PVC (Persistent Volume Claim) applications by matching them with their parent application catalogs
- Supports multiple environment naming patterns (with and without cluster suffixes)
- Automatically skips system environments
- Provides detailed logging of all operations
- Handles error conditions gracefully

## Usage

```bash
./update_catalog_references.sh <api_endpoint> <token> <source_cluster> <target_cluster>
```

### Parameters

- `api_endpoint`: The Nirmata API endpoint (e.g., https://pe420.nirmata.co)
- `token`: API token for authentication
- `source_cluster`: Source cluster name (e.g., 123-app-migration)
- `target_cluster`: Target cluster name (e.g., 129-app-migration)

### Example

```bash
./update_catalog_references.sh https://pe420.nirmata.co "YOUR_API_TOKEN" "123-app-migration" "129-app-migration"
```

## How It Works

1. **Environment Detection**:
   - Looks for the restored environment using the pattern `nginx-<source_cluster>-<target_cluster>`
   - Also checks for environments with matching cluster names
   - Handles environments with null clusterName by checking if the name contains the cluster name

2. **Application Processing**:
   - Processes all applications in the restored environment
   - For each application, tries multiple catalog application lookup strategies:
     1. Exact match with cluster suffix (e.g., `app-123-app-migration`)
     2. Exact match without suffix
     3. For PVC applications, tries the base name without the `-pvc` suffix

3. **System Environment Handling**:
   - Automatically skips system environments like:
     - kube-system
     - kube-public
     - kube-node-lease
     - nirmata
     - ingress-haproxy
     - velero
     - default

4. **Logging**:
   - Creates detailed logs in the `logs` directory
   - Logs all operations, including:
     - Environment discovery
     - Application processing
     - Catalog reference updates
     - Errors and warnings

## Error Handling

- Validates API responses and JSON parsing
- Continues processing even if some steps fail
- Provides clear error messages in logs
- Handles missing catalog applications gracefully

## Logs

Logs are stored in the `logs` directory with timestamps in the filename:
```
logs/catalog_reference_update_YYYYMMDD_HHMMSS.log
```

## Notes

- The script is designed to be idempotent - running it multiple times is safe
- It automatically handles PVC applications by looking for their parent application catalogs
- No hardcoded application names or patterns - everything is discovered dynamically
- The script handles environments where the clusterName field is null by checking if the environment name contains the cluster name
- For PVC applications, the script tries to find a catalog application with the same base name (without the -pvc suffix) 