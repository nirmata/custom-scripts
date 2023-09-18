# Kubernetes Workflow Automation Script

This Bash script automates a Kubernetes workflow involving Terraform provisioning, resource monitoring, and Nirmata cluster cleanup. It is designed to be run multiple times, and it continuously checks for the status of namespaces and reports incidents if any are in the terminating state.

## Prerequisites

Before using this script, make sure you have the following prerequisites:

- [kubectl](https://kubernetes.io/docs/tasks/tools/)
- [Terraform](https://learn.hashicorp.com/tutorials/terraform/install-cli)
- [jq](https://stedolan.github.io/jq/download/)
- [Nirmata API Token](https://docs.nirmata.io/docs/en/accounts/api_tokens.html)
- Access to a Kubernetes cluster
- Necessary configuration files for Terraform and Nirmata

## Usage

```bash
./workflow.sh <NUM_RUNS> <KUBECONFIG_PATH> <CLUSTER_NAME> <NIRMATA_API_TOKEN> <NIRMATA_URL> <TERRAFORM_SCRIPT_PATH> <NIRMATA_CLEANUP_SCRIPT_PATH> <MAX_WAIT_SECONDS>
```

- `NUM_RUNS`: Number of times to execute the workflow.
- `KUBECONFIG_PATH`: Path to your Kubernetes configuration file (KUBECONFIG).
- `CLUSTER_NAME`: Name of the Kubernetes cluster.
- `NIRMATA_API_TOKEN`: Your Nirmata API token.
- `NIRMATA_URL`: URL for the Nirmata API.
- `TERRAFORM_SCRIPT_PATH`: Path to your Terraform script.
- `NIRMATA_CLEANUP_SCRIPT_PATH`: Path to your Nirmata cleanup script.
- `MAX_WAIT_SECONDS`: Maximum waiting time in seconds.

## Workflow Steps

1. Run the Terraform script to provision resources.
2. Wait for pods in the "Running" state.
3. Perform Nirmata cleanup.
4. Continuously print namespace statuses and report incidents if any namespaces are in the terminating state.
5. Wait for a specified duration.
6. Run the Nirmata cleanup script.

## Example

```bash
./workflow.sh 5 /path/to/kubeconfig.yaml my-cluster YOUR_NIRMATA_API_TOKEN https://nirmata-api-url.com /path/to/terraform/script.sh /path/to/nirmata/cleanup/script.sh 3600
```

This example runs the workflow 5 times with the specified parameters.

## Summary

This script provides a streamlined way to manage Kubernetes resources, monitor namespaces, and perform cleanup tasks with Nirmata. It automates repetitive tasks and ensures the stability of your Kubernetes cluster.

