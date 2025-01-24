#!/bin/bash

# Check if the required arguments are provided
if [ $# -lt 3 ]; then
  echo "Usage: $0 <deploy|sts> <namespace> <resource-name1> [<resource-name2> ...]"
  exit 1
fi

# Assign variables based on the arguments
resource_type=$1
namespace=$2
shift 2
resources=("$@")  # Store all remaining arguments as resource names
log_duration=10 # Set the default log capture duration in minutes

# Create a directory for logs in the current working directory (PWD)
log_dir="$(pwd)/logs_$(date +'%Y%m%d_%H%M%S')"
mkdir -p $log_dir

# Function to capture logs for a given resource
capture_logs() {
  resource_name=$1
  pods=$(kubectl get pods -n $namespace -l app=$resource_name --no-headers -o custom-columns=":metadata.name")

  if [ -z "$pods" ]; then
    echo "No pods found for the $resource_type $resource_name in namespace $namespace."
    return
  fi

  echo "Starting log capture for $resource_type $resource_name in $namespace for $log_duration minutes..."
  
  for pod in $pods; do
    kubectl logs -n $namespace $pod > $log_dir/${pod}_logs.txt &
  done
}

# Trap to handle manual interruption and still zip logs
trap 'echo "Log capture interrupted. Zipping collected logs so far..."; zip -r $(pwd)/logs.zip $log_dir; exit' SIGINT SIGTERM

# Start log capture for each resource provided
for resource_name in "${resources[@]}"; do
  capture_logs $resource_name
done

# Wait for the duration and capture logs
sleep "${log_duration}m"

# After completion, create a zip file of the logs
echo "Log capture completed. Creating zip file..."
zip_file="$(pwd)/logs.zip"
zip -r $zip_file $log_dir
echo "Logs are saved and zipped at $zip_file"
