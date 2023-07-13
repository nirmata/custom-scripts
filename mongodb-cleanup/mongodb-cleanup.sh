#!/bin/bash

if [ "$#" -ne 2 ]; then
  echo "Usage: $0 nadm_directory backup_directory"
  exit 1
fi

# Run the health script and capture the output
health_output=$(./health_script.sh)
 
echo "Output of the health script:"
echo "---------------------------"
echo "$health_output"
echo "---------------------------"

# Check if the desired string is present in the output
if [[ $health_output == *"Warn: WiredTiger"* ]]; then
  echo "Executing script because 'Warn: WiredTiger' was found in the health script output"

    nadm_directory=$1
    backup_directory=$2

    echo "--------Take the Mongo backup--------"

    echo "Using nadm directory: $nadm_directory"
    echo "Using backup directory: $backup_directory"

    cd "$nadm_directory"

    # echo "==========================================================="

    # echo "all" | ./nadm backup -d "$backup_directory" -n nirmata | while read -r line; do
    #     echo "$line"
    #     # Add any additional processing if needed
    # done

    # #check the status of backup if that done successfully
    # echo $?

    # echo "--------Verify if the backup size is good--------"

    # ls -lrth "$backup_directory"


    echo "--------Take the Mongo backup--------"

    valid_path=false

    while [ "$valid_path" = false ]; do
        #read -p "Please enter the path to the nadm directory: " nadm_directory

        # Check if the "./nadm" file exists in the specified directory
        if [ -f "$nadm_directory/nadm" ]; then
            valid_path=true
        else
            echo "Error: The nadm directory or the nadm file does not exist."
        fi
    done

    cd "$nadm_directory"

    echo "==========================================================="

    #read -p "Enter the backup directory: " backup_directory
    echo "all" | ./nadm backup -d "$backup_directory" -n nirmata | while read -r line; do
        echo "$line"
        # Add any additional processing if needed
    done

    #check the status of backup if that done successfully
    echo $?

    echo "--------Verify if the backup size is good--------"

    #read -p "Please enter the path to the backup directory: " backup_directory

    # Verify if the backup size is good
    ls -lrth "$backup_directory"

    echo "==========================================================="

    echo "----Check the count of pods scale up for Nirmata services---"

    # Check the number of pods for the deployment and store it in a variable
    # pods_count1=$(kubectl get deploy -n nirmata --output=jsonpath='{.items[*].status.replicas}')
    pods_count1=$(kubectl get deploy -n nirmata --output=jsonpath='{.items[*].spec.replicas}')

    # Store the deployment names in an array
    deployment_names=($(kubectl get deploy -n nirmata --output=jsonpath='{.items[*].metadata.name}'))

    echo "Number of pods for Nirmata services: $pods_count1"
    echo "Deployment names:"
    for deployment in "${deployment_names[@]}"; do
        echo "$deployment"
    done

    sleep 5

    echo "==========================================================="

    echo "--------Scale down Nirmata services--------"

    # Scale down all Nirmata services to 0 replicas
    kubectl scale deploy --all -n nirmata --replicas=0
    sleep 30


    echo "--------Check if the Nirmata Services are down------"

    # Check the pod count for all deployments in the nirmata namespace
    pod_count=$(kubectl get deploy -n nirmata --output=jsonpath='{range .items[*]}{.metadata.name}={.status.replicas}{"\n"}{end}')

    echo "Pod count for Nirmata services:"
    echo "$pod_count"

    # Iterate over the pod count for each deployment
    zero_pod_count=true
    while read -r line; do
        deployment=${line%%=*}
        replicas=${line#*=}
       # Handle empty replicas value by assigning 0 as default
        replicas=${replicas:-0}
        if [ "$replicas" -ne 0 ]; then
            zero_pod_count=false
            echo "Deployment '$deployment' has $replicas running pods."
        fi
    done <<< "$pod_count"

    # Check if all deployments have 0 replicas
    if [ "$zero_pod_count" = true ]; then
        echo "All deployments have 0 replicas. Nirmata services are down."
    else
        echo "Nirmata services are still running."
    fi

    sleep 10
    echo "==========================================================="


    echo "--------Scaled down the shared service (Tunnel)--------"

    # Scale down the Tunnel StatefulSet to 0 replicas
    kubectl scale sts tunnel -n nirmata --replicas=0

    echo "Waiting for 10 seconds..."
    sleep 10

    echo "--------Check if the Tunnel Service is down------"

    # Check the pod count for the Tunnel StatefulSet in the nirmata namespace
    pod_count=$(kubectl get sts tunnel -n nirmata --output=jsonpath='{.status.replicas}')

    if [ "$pod_count" -eq 0 ]; then
        echo "The Tunnel Service is down. Pod count: $pod_count"
    else
        echo "The Tunnel Service is still running. Pod count: $pod_count"
    fi

    sleep 5
    echo "==========================================================="



    echo "--------Scaled down the shared service (MongoDB)--------"

    # Scale down the MongoDB StatefulSet to 0 replicas
    kubectl scale sts mongodb -n nirmata --replicas=0

    echo "Waiting for 20 seconds..."
    sleep 20

    echo "--------Check if the MongoDB Service is down------"

    # Check the pod count for the MongoDB StatefulSet in the nirmata namespace
    pod_count=$(kubectl get sts mongodb -n nirmata --output=jsonpath='{.status.replicas}')

    if [ "$pod_count" -eq 0 ]; then
        echo "The MongoDB Service is down. Pod count: $pod_count"
    else
        echo "The MongoDB Service is still running. Pod count: $pod_count"
    fi

    sleep 5
    echo "==========================================================="

    echo "------List MongoDB PVCs---------"
    mongodb_pvc=$(kubectl get pvc -n nirmata | grep -i mongodb)

    echo "MongoDB PVCs:"
    echo "$mongodb_pvc"

    echo "-------Delete PVCs of MongoDB---------"
    # Extract the PVC names from the stored output
    pvc_names=$(echo "$mongodb_pvc" | awk '{print $1}')

    # Loop through each PVC name and remove finalizer before deleting
    for pvc_name in $pvc_names; do
      # Remove the finalizer from PVC
      kubectl patch pvc $pvc_name -n nirmata -p '{"metadata":{"finalizers": []}}' --type=merge

      # Delete the PVC
      kubectl delete pvc $pvc_name -n nirmata
    done

    echo "--------Verifying if the PVCs were removed-------"
    mongodb_pvc_check=$(kubectl get pvc -n nirmata | grep -i mongodb)

    if [ -z "$mongodb_pvc_check" ]; then
      echo "No MongoDB PVCs found. PVCs were successfully removed."
    else
      echo "MongoDB PVCs still exist. Please check and ensure proper removal."
      echo "$mongodb_pvc_check"
    fi

    sleep 5
    echo "==========================================================="

    echo "------List MongoDB PVs---------"
    mongodb_pv=$(kubectl get pv -n nirmata | grep -i mongodb)

    echo "MongoDB PVs:"
    echo "$mongodb_pv"

    echo "-------Delete PVs for MongoDB---------"
    # Extract the PV names from the stored output
    pv_names=$(echo "$mongodb_pv" | awk '{print $1}')

    # Loop through each PV name and remove finalizer before deleting
    for pv_name in $pv_names; do
      # Remove the finalizer from PV
      kubectl patch pv $pv_name -p '{"metadata":{"finalizers": []}}' --type=merge

      # Delete the PV
      kubectl delete pv $pv_name -n nirmata
    done

    echo "--------Verifying if the PVs were removed-------"
    mongodb_pv_check=$(kubectl get pv -n nirmata | grep -i mongodb)

    if [ -z "$mongodb_pv_check" ]; then
      echo "No MongoDB PVs found. PVs were successfully removed."
    else
      echo "MongoDB PVs still exist. Please check and ensure proper removal."
      echo "$mongodb_pv_check"
    fi

    sleep 5
    echo "==========================================================="

    echo "-------Scale up the MongoDB services to count 3---------"
    # Scale up the MongoDB services to count 3 replicas
    max_attempts=3
    attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
      echo "Attempt $attempt: Scaling up the MongoDB services..."

      kubectl scale sts mongodb -n nirmata --replicas=3

      # Wait for a few seconds before checking the pod count
      sleep 5

      # Check the pod count for MongoDB pods
      mongodb_pods=$(kubectl get pods -n nirmata -l app=mongodb)
      mongodb_pod_count=$(echo "$mongodb_pods" | grep -c Running)

      if [ "$mongodb_pod_count" -eq 3 ]; then
        # Check if all pods are in the Running state
        running_pods=$(echo "$mongodb_pods" | grep -c Running)

        if [ "$running_pods" -eq 3 ]; then
          echo "MongoDB pods are scaled up and running."
          break  # Exit the loop since scaling up is successful
        else
          echo "MongoDB pods are not all in the Running state. Retrying after 10 seconds..."
        fi
      else
        echo "MongoDB pods are not scaled up properly. Retrying after 10 seconds..."
      fi

      attempt=$((attempt + 1))
      if [ "$attempt" -le "$max_attempts" ]; then
        sleep 10
      else
        echo "Failed to scale up MongoDB pods within the specified time."
        exit 1  # Exit the script with a non-zero status indicating failure
      fi
    done
    echo "==========================================================="

    echo "--------Restore MongoDB----------"
    current_directory=$(pwd)
    echo "Current directory: $current_directory"
    echo "Using existing path of the ./nadm directory:"
    # echo "Please provide the path to the ./nadm directory:"
    # read -r nadm_directory
    echo "Using existing path of the backup directory (gzip present):"
    # echo "Please provide the path to the backup directory (gzip present):"
    # read -r backup_directory

    # cd "$nadm_directory" || exit
    # ./nadm restore -d "$backup_directory" -n nirmata
    # restore_status=$?

    cd "$nadm_directory" || exit
    echo "y"  | ./nadm restore -d "$backup_directory" -n nirmata
    restore_status=$?


    echo "-------Verify the Restoration is done successfully-------"
    if [ "$restore_status" -eq 0 ]; then
      echo "MongoDB restoration completed successfully."
    else
      echo "MongoDB restoration failed. Please check and ensure proper restoration."
    fi

    cd "$current_directory" || exit

    sleep 5
    echo "==========================================================="

    echo "-------Scale up the Tunnel service to count 2---------"
    kubectl scale sts tunnel -n nirmata --replicas=2

    echo "--------Sleeping for 10 seconds--------"
    sleep 10

    echo "--------Verify if the Tunnel pods are scaled up and running--------"
    tunnel_pods=$(kubectl get pods -n nirmata -l nirmata.io/statefulset.name=tunnel)
    tunnel_pod_count=$(echo "$tunnel_pods" | grep -c Running)

    sleep 5

    if [ "$tunnel_pod_count" -eq 2 ]; then
      echo "Tunnel pods are scaled up and running."
    else
      echo "Tunnel pods are not scaled up properly. Please check and ensure proper scaling."
      echo "$tunnel_pods"
    fi

    sleep 5
    echo "==========================================================="

    echo "---------Scale up the Nirmata Services------------"
    #use the count from the previous output we had to scal down deploy in nirmata service

    # ./nadm scale --replicas=2 --nirmata
    # # if this doesn't work then run below command
    # kubectl scale deploy --all -n nirmata --replicas=2 #Note it should only scale up the count same as previous

    echo "---------Scale up the Nirmata Services------------"
    # Iterate over the deployment names and scale up the respective deployments
    for deployment_name in "${deployment_names[@]}"; do
        # Get the current replica count for the deployment
        current_replicas=$(kubectl get deploy "$deployment_name" -n nirmata --output=jsonpath='{.spec.replicas}')
        echo "current deployment replicas"
        echo $current_replicas

        # Scale up the deployment using the current replica count
        # kubectl scale deploy "$deployment_name" -n nirmata --replicas="$current_replicas"
        #kubectl scale deploy "$deployment_name" -n nirmata --replicas="$pods_count1"
        kubectl scale deploy "$deployment_name" -n nirmata --replicas=1
    done

    sleep 5
    echo "==========================================================="

    echo "------List MongoDB new PVs---------"
    mongodb_pvs=$(kubectl get pv -n nirmata | grep -i mongodb)

    echo "MongoDB PVs:"
    echo "$mongodb_pvs"

    echo "--------Set Retain state to MongoDB PVs--------"
    # Extract the PV names from the stored output
    pv_names=$(echo "$mongodb_pvs" | awk '{print $1}')

    # Set the reclaim policy to "Retain" for MongoDB PVs
    kubectl patch pv $pv_names -n nirmata -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'


    echo "Checking pod statuses..."

    # Get the pod statuses
    pod_statuses=$(kubectl get pods -n nirmata --no-headers=true | awk '{print $3}')

    echo "Current pod statuses:"
    echo "$pod_statuses"

    # # Check if any pod has an error status
    # if [[ $pod_statuses =~ ^(Pending|ImagePullBackOff|Failed|Error|CrashLoopBackOff) ]]; then
    #     echo "Found pod(s) with an error status. Deleting the failed pod..."
    #     # Get the name of the failed pod
    #     failed_pod=$(kubectl get pods -n nirmata --no-headers=true | awk '{ if ($3 == "Error") print $1 }')

    #     # Delete the failed pod
    #     kubectl delete pod $failed_pod -n nirmata
    #     echo "Deleted the failed pod: $failed_pod"
    # fi

    sleep 5
    echo "-------Wait for 5 minutes----------"
    #sleep 300  # Sleep for 5 minutes (300 seconds)

    echo "==========================================================="

    echo "---Running Health Check Script to verify Nirmata Shared Services Health---"


    echo "Some Test cases: Nirmata is up? Clusters are ready? Env is showing up ? Users can log in? --- (you can ask them to perform this manually or add it in the script as test cases)"
else
  echo "'Warn: WiredTiger' not found in the health script output. Exiting."
fi
