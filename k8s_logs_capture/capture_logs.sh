#!/bin/bash

# Check if the required arguments are provided
if [ $# -ne 3 ]; then
  echo "Usage: $0 <deploy|sts> <resource-name> <namespace>"
  exit 1
fi

# Assign variables based on the arguments
resource_type=$1
resource_name=$2
namespace=$3
log_duration=10 # Set the default log capture duration in minutes

# Create a directory for logs in the current working directory (PWD)
log_dir="$(pwd)/${resource_name}_logs"
mkdir -p $log_dir

# Function to capture logs
capture_logs() {
  pods=$(kubectl get pods -n $namespace -l app=$resource_name --no-headers -o custom-columns=":metadata.name")

  if [ -z "$pods" ]; then
    echo "No pods found for the $resource_type $resource_name in namespace $namespace."
    exit 1
  fi

  echo "Starting log capture for $resource_type $resource_name in $namespace for $log_duration minutes..."
  
  for pod in $pods; do
    kubectl logs -n $namespace $pod > $log_dir/${pod}_logs.txt &
  done

  # Wait for the duration and capture logs
  sleep "${log_duration}m"

  echo "Log capture completed. Creating zip file..."

  zip_file="$(pwd)/${resource_name}_logs.zip"
  zip -r $zip_file $log_dir
  echo "Logs are saved and zipped at $zip_file"
}

# Trap to handle manual interruption and still zip logs
trap 'echo "Log capture interrupted. Zipping collected logs so far..."; zip -r $(pwd)/${resource_name}_logs.zip $log_dir; exit' SIGINT SIGTERM

# Start log capture
capture_logs

