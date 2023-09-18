#!/bin/bash

# Initialize counters
TOTAL_RUNS=0
TERMINATING_INCIDENTS=0

# Define the number of times to execute the workflow
NUM_RUNS=$1
KUBECONFIG_PATH=$2
CLUSTER_NAME=$3
NIRMATA_API_TOKEN=$4
NIRMATA_URL=$5
TERRAFORM_SCRIPT_PATH=$6
NIRMATA_CLEANUP_SCRIPT_PATH=$7
MAX_WAIT_SECONDS=$8 # User-defined maximum waiting time in seconds

# Function to check and print namespace statuses
function check_namespace_statuses() {
    local check_interval=10 # Adjust the interval as needed (in seconds)
    local max_checks=$((MAX_WAIT_SECONDS / check_interval))

    for ((i = 1; i <= max_checks; i++)); do
        echo "Namespace statuses (Check $i/$max_checks):"
        kubectl get namespaces
        echo "Waiting for pods in nirmata to be in the 'Running' state..."
        sleep $check_interval
    done
}

# Function to check if any namespaces are terminating
function check_terminating_namespaces() {
    local check_interval=10 # Adjust the interval as needed (in seconds)
    local max_checks=$((MAX_WAIT_SECONDS / check_interval))

    for ((i = 1; i <= max_checks; i++)); do
        echo "Checking for namespace termination (Check $i/$max_checks):"

        if kubectl get namespaces | grep -q Terminating; then
            echo "Incident reported: Some namespaces are in terminating state."
            TERMINATING_INCIDENTS=$((TERMINATING_INCIDENTS + 1))
        else
            echo "No incident reported: All namespaces are stable."
        fi

        sleep $check_interval
    done
}

# Function to run the entire workflow
function run_workflow() {
    TOTAL_RUNS=$((TOTAL_RUNS + 1))
    echo "Run $TOTAL_RUNS of $NUM_RUNS"

    # Step 1: Run the Terraform script
    echo "Running Terraform script..."
    $TERRAFORM_SCRIPT_PATH

    echo "Waiting for a minute to deploy all the resources and ensure cluster onboarding"
    sleep 120

    # Step 2: Wait for pods to be in the "Running" state
    CHECK_INTERVAL=5 # Interval for checking pod status in seconds
    start_time=$(date +%s)

    while true; do
        current_time=$(date +%s)
        elapsed_time=$((current_time - start_time))

        # Check if all pods are in the "Running" state
        if [[ "$(kubectl get pods -n nirmata -o 'jsonpath={..status.phase}' | tr ' ' '\n' | sort | uniq)" == "Running" ]]; then
            echo "All pods in nirmata are in the 'Running' state."
            break
        fi

        # Check if the maximum waiting time has been reached
        if [ "$elapsed_time" -ge "$MAX_WAIT_SECONDS" ]; then
            echo "Maximum waiting time reached. Some pods may not be in the 'Running' state."
            break
        fi

        echo "Waiting for pods in nirmata to be in the 'Running' state..."
        sleep $CHECK_INTERVAL
    done

    # Step 3: Perform Nirmata cleanup
    echo "Performing Nirmata cleanup..."
    CLUSTER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $NIRMATA_API_TOKEN" -X GET "$NIRMATA_URL/cluster/api/KubernetesCluster?fields=id,name" | jq -r ".[] | select( .name == \"$CLUSTER_NAME\" ).id")
    echo $CLUSTER_ID >clusterid_$CLUSTER_NAME
    for cluster_id in $(cat clusterid_$CLUSTER_NAME); do
        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $NIRMATA_API_TOKEN" -X DELETE "$NIRMATA_URL/cluster/api/KubernetesCluster/$cluster_id?action=remove"
        if [[ $? -eq 0 ]]; then
            echo "$CLUSTER_NAME is Deleted Successfully"
        fi
    done

    # Step 4: Wait for a specified duration
    echo "Waiting for $MAX_WAIT_SECONDS seconds..."
    check_namespace_statuses # Continuously print namespace statuses

    # Step 5: Run the Nirmata cleanup script
    echo "Running Nirmata cleanup script..."
    $NIRMATA_CLEANUP_SCRIPT_PATH $KUBECONFIG_PATH $CLUSTER_NAME $NIRMATA_API_TOKEN $NIRMATA_URL nirmata-kyverno-operator kyverno nirmata 
}

# Loop to run the workflow multiple times
for ((run = 1; run <= NUM_RUNS; run++)); do
    run_workflow
done

# Print a summary
echo "Script execution completed."
echo "Total runs: $TOTAL_RUNS"
echo "Namespace termination incidents: $TERMINATING_INCIDENTS"
