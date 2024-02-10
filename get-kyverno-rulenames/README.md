## Kyverno Rule Name Lister
This script retrieves and lists all rule names defined within Kyverno cluster policies deployed on your Kubernetes cluster.

## Requirements
- kubectl: kubectl CLI: https://kubernetes.io/docs/reference/kubectl/
- jq: jq (JSON processor): https://stedolan.github.io/jq/
## Usage
1. Clone this repository or download the script directly.
2. Make the script executable: chmod +x list_kyverno_rules.sh
3. Run the script: ./list_kyverno_rules.sh

The script will list all Kyverno rule names from your cluster policies
