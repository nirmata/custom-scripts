# Kyverno Policy Generator

This Bash script generates a Kyverno policy YAML file based on data from a CSV file. The generated policy includes only pods that do not have a "restricted-v2" SECURITY_CONTEXT_CONSTRAINT.

## Prerequisites

Before using this script, ensure you have the following:

- A Bash shell environment.
- A CSV file named `kyverno-resource-data.csv` with the following columns:
  - NAMESPACE
  - POD_NAME
  - SERVICEACCOUNT
  - SECURITY_CONTEXT_CONSTRAINT

## Usage

1. Place your CSV file with the required data in the same directory as this script.

2. Execute the script:

   ```bash
   ./generate-kyverno-policy.sh
   ```

3. The script will create a Kyverno policy YAML file named `kyverno.yaml` in the same directory.

## Kyverno Policy Generation

The script reads data from the CSV file and generates a Kyverno policy that includes the following:

- `apiVersion` and `kind` for Kyverno ClusterPolicy.
- A rule named `include-pods-non-restricted-v2` to match resources of kind `Pod`.

For each entry in the CSV file that does not have "restricted-v2" in the SECURITY_CONTEXT_CONSTRAINT column, the script appends a resource block to the Kyverno policy YAML. This block specifies the namespace and pod name to include.

## Output

The generated Kyverno policy is saved to a file named `kyverno.yaml` in the same directory as the script.

## Troubleshooting

If the CSV file (`kyverno-resource-data.csv`) is not found in the script's directory, an error message will be displayed.

Make sure to create a CSV file named `kyverno-resource-data.csv` in the same directory as the script, and ensure that it has the specified columns (NAMESPACE, POD_NAME, SERVICEACCOUNT, SECURITY_CONTEXT_CONSTRAINT) before running the script.