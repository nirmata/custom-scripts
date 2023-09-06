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

