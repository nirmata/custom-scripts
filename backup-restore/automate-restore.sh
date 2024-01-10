#!/bin/bash
  echo "==========================================================="
  echo "----Checking the count of pods to scale up for Nirmata services after mongodb cleanup---"

  # Check the number of pods for the deployment and store it in a variable
  # pods_count1=$(kubectl get deploy -n nirmata --output=jsonpath='{.items[*].status.replicas}')
  # pods_count1=$(kubectl get deploy -n nirmata --output=jsonpath='{.items[*].spec.replicas}')

  # Store the deployment names in an array
  deployment_names=($(kubectl get deploy -n nirmata --output=jsonpath='{.items[*].metadata.name}'))
  replica_counts=()

      echo "==========================================================="

    echo "---------Storing Current Replica Counts------------"
    # Iterate over the deployment names and store the current replica counts
    for deployment_name in "${deployment_names[@]}"; do
        # Get the current replica count for the deployment
        pods_count1=$(kubectl get deploy "$deployment_name" -n nirmata --output=jsonpath='{.spec.replicas}')
        echo "Nirmata Service count for $deployment_name: $pods_count1"

        # Store the replica count in the array
        replica_counts+=("$pods_count1")
    done

  echo "==========================================================="

  echo "--------Scaling down Nirmata services--------"

  # Scale down all Nirmata services to 0 replicas
  kubectl scale deploy --all -n nirmata --replicas=0
  sleep 90

  echo "==========================================================="

  echo "--------Checking if the Nirmata Services are down------"

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

  sleep 30
  echo "==========================================================="


  echo "--------Scaling down the shared service (Tunnel)--------"

  # Scale down the Tunnel StatefulSet to 0 replicas
  kubectl scale sts tunnel -n nirmata --replicas=0

  echo "Waiting for 90 seconds..."
  sleep 90

  echo "--------Checking if the Tunnel Service is down------"

  # Check the pod count for the Tunnel StatefulSet in the nirmata namespace
  pod_count=$(kubectl get sts tunnel -n nirmata --output=jsonpath='{.status.replicas}')

  if [ "$pod_count" -eq 0 ]; then
      echo "The Tunnel Service is down. Pod count: $pod_count"
  else
      echo "The Tunnel Service is still running. Pod count: $pod_count"
  fi

  sleep 30
  echo "==========================================================="

  echo "--------Scaling down the shared service (kafka)--------"

  # Scale down the kafka StatefulSet to 0 replicas
  kubectl scale sts kafka -n nirmata --replicas=0

  echo "Waiting for 90 seconds..."
  sleep 90

  echo "--------Checking if the kafka Service is down------"

  # Check the pod count for the kafka StatefulSet in the nirmata namespace
  pod_count=$(kubectl get sts kafka -n nirmata --output=jsonpath='{.status.replicas}')

  if [ "$pod_count" -eq 0 ]; then
      echo "The kafka Service is down. Pod count: $pod_count"
  else
      echo "The kafka Service is still running. Pod count: $pod_count"
  fi

echo "==========================================================="
  echo "--------Scaling down the shared service (zk)--------"

  # Scale down the ZK StatefulSet to 0 replicas
  kubectl scale sts zk -n nirmata --replicas=0

  echo "Waiting for 90 seconds..."
  sleep 90

  echo "--------Checking if the zk Service is down------"

  # Check the pod count for the ZK StatefulSet in the nirmata namespace
  pod_count=$(kubectl get sts zk -n nirmata --output=jsonpath='{.status.replicas}')

  if [ "$pod_count" -eq 0 ]; then
      echo "The zk Service is down. Pod count: $pod_count"
  else
      echo "The zk Service is still running. Pod count: $pod_count"
  fi

#   echo "==========================================================="

#   echo "The size of mongodb before backup-restore processes : "
#   mongo_commands=$(kubectl exec -n nirmata -it mongodb-0 -- mongo --quiet <<EOF
#   db.adminCommand("listDatabases")
#   exit
# EOF
# )

#   echo "$mongo_commands"
#   echo "$mongo_commands" > mongo_initial.txt
#   echo "MongoDB commands executed and output saved to mongo_initial.txt"


  echo "==========================================================="

  echo "--------Taking the Mongo backup--------"
  valid_path=false

  while [ "$valid_path" = false ]; do
      # Check if the "./backup" file exists in the specified directory
      if [ -f "backup-mongo.sh" ]; then
          valid_path=true
      else
          echo "Error: The backup file does not exist."
      fi
  done
  echo "==========================================================="

  echo "all" | ./backup-mongo.sh | while read -r line; do
      echo "$line"
      # Add any additional processing if needed
  done
  backup_directory=$(awk -F': ' '{split($2, a, "/"); path=""; for (i=1; i<length(a); i++) path=path a[i] "/"; print path}' nirmata_backup_directory_path_details.txt)
  backup_directory="${backup_directory}nirmata-backups"
  # Now $backup_directory contains the result of the awk command
  echo "Backup directory is:  ${backup_directory}"

  echo "checking the status of backup if that done successfully"
  echo $?

  echo "==========================================================="

  echo "--------Verifying if the backup size is good--------"

  # Verify if the backup size is good
  ls -lrth "$backup_directory"



  echo "--------Scaling down the shared service (MongoDB)--------"

  # Scale down the MongoDB StatefulSet to 0 replicas
  kubectl scale sts mongodb -n nirmata --replicas=0

  echo "Waiting for 90 seconds..."
  sleep 90

  echo "--------Checking if the MongoDB Service is down------"

  # Check the pod count for the MongoDB StatefulSet in the nirmata namespace
  pod_count=$(kubectl get sts mongodb -n nirmata --output=jsonpath='{.status.replicas}')

  if [ "$pod_count" -eq 0 ]; then
      echo "The MongoDB Service is down. Pod count: $pod_count"
  else
      echo "The MongoDB Service is still running. Pod count: $pod_count"
  fi

  sleep 20
  echo "==========================================================="

  echo "------Listing MongoDB PVCs---------"
  mongodb_pvc=$(kubectl get pvc -n nirmata | grep -i mongodb)

  echo "MongoDB PVCs:"
  echo "$mongodb_pvc"

      echo "==========================================================="

  echo "-------Deleting PVCs of MongoDB---------"
  # Extract the PVC names from the stored output
  pvc_names=$(echo "$mongodb_pvc" | awk '{print $1}')

  # Loop through each PVC name and remove finalizer before deleting
  for pvc_name in $pvc_names; do
    # Remove the finalizer from PVC
    echo "Removing the finalizer from PVC"
    kubectl patch pvc $pvc_name -n nirmata -p '{"metadata":{"finalizers": []}}' --type=merge

    # Delete the PVC
    echo "Deleting the PVC"
    kubectl delete pvc $pvc_name -n nirmata
  done

      echo "==========================================================="

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

  echo "------Listing MongoDB PVs---------"
  mongodb_pv=$(kubectl get pv -n nirmata | grep -i mongodb)

  echo "MongoDB PVs:"
  echo "$mongodb_pv"

      echo "==========================================================="

  echo "-------Deleting PVs for MongoDB---------"
  # Extract the PV names from the stored output
  pv_names=$(echo "$mongodb_pv" | awk '{print $1}')

  # Loop through each PV name and remove finalizer before deleting
  for pv_name in $pv_names; do
    # Remove the finalizer from PV
    kubectl patch pv $pv_name -p '{"metadata":{"finalizers": []}}' --type=merge

    # Delete the PV
    kubectl delete pv $pv_name -n nirmata
  done
  echo "==========================================================="
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

  echo "-------Scaling up the MongoDB services to count 3---------"
  # Scale up the MongoDB services to count 3 replicas
  max_attempts=3
  attempt=1
  while [ "$attempt" -le "$max_attempts" ]; do
    echo "Attempt $attempt: Scaling up the MongoDB services..."

    kubectl scale sts mongodb -n nirmata --replicas=3

    # Wait for a few seconds before checking the pod count
    sleep 120

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
      sleep 20
    else
      echo "Failed to scale up MongoDB pods within the specified time."
      exit 1  # Exit the script with a non-zero status indicating failure
    fi
  done
  echo "==========================================================="


  echo "--------Restoring MongoDB----------"
  current_directory=$(pwd)
  echo "Current directory: $current_directory"

  echo "Using existing path of the backup directory:"

  echo "y"  | ./restore.sh "${backup_directory}"
  restore_status=$?

  echo "==========================================================="

  echo "-------Verify the Restoration is done successfully-------"
  if [ "$restore_status" -eq 0 ]; then
    echo "MongoDB restoration completed successfully."
  else
    echo "MongoDB restoration failed. Please check and ensure proper restoration."
  fi

  cd "$current_directory" || exit

  sleep 30
#   echo "==========================================================="

#   echo "-------The size of mongodb before backup-restore processes ------- "
#   echo "$(cat mongo_initial.txt)"
#   echo " "
#   echo "-------The size of mongodb after backup-restore processes ------- "

#   mongo_commands=$(kubectl exec -n nirmata -it mongodb-0 -- mongo --quiet <<EOF
#  db.adminCommand("listDatabases")
#   exit
# EOF
# )

#   echo "$mongo_commands" > mongo_final.txt
#   echo " "
#   echo "$(cat mongo_final.txt)"
#   echo "MongoDB commands executed and output saved to mongo_final.txt"

#   echo "Waiting for 120 seconds..."
#   sleep 120

  echo "==========================================================="
 echo "-------Scaling up the zk services to count 3---------"
  # Scale up the zk services to count 3 replicas
  max_attempts=3
  attempt=1
  while [ "$attempt" -le "$max_attempts" ]; do
    echo "Attempt $attempt: Scaling up the zk services..."

    kubectl scale sts zk -n nirmata --replicas=3

    # Wait for a few seconds before checking the pod count
    sleep 120

    # Check the pod count for zk pods
    zk_pods=$(kubectl get pods -n nirmata -l app=zk)
    zk_pod_count=$(echo "$zk_pods" | grep -c Running)

    if [ "$zk_pod_count" -eq 3 ]; then
      # Check if all pods are in the Running state
      running_pods=$(echo "$zk_pods" | grep -c Running)

      if [ "$running_pods" -eq 3 ]; then
        echo "zk pods are scaled up and running."
        break  # Exit the loop since scaling up is successful
      else
        echo "zk pods are not all in the Running state. Retrying after 10 seconds..."
      fi
    else
      echo "zk pods are not scaled up properly. Retrying after 10 seconds..."
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -le "$max_attempts" ]; then
      sleep 20
    else
      echo "Failed to scale up zk pods within the specified time."
      exit 1  # Exit the script with a non-zero status indicating failure
    fi
  done
  echo "==========================================================="

   echo "-------Scaling up the kafka services to count 3---------"
  # Scale up the kafka services to count 3 replicas
  max_attempts=3
  attempt=1
  while [ "$attempt" -le "$max_attempts" ]; do
    echo "Attempt $attempt: Scaling up the kafka services..."

    kubectl scale sts kafka -n nirmata --replicas=3

    # Wait for a few seconds before checking the pod count
    sleep 120

    # Check the pod count for kafka pods
    kafka_pods=$(kubectl get pods -n nirmata -l app=kafka)
    kafka_pod_count=$(echo "$kafka_pods" | grep -c Running)

    if [ "$kafka_pod_count" -eq 3 ]; then
      # Check if all pods are in the Running state
      running_pods=$(echo "$kafka_pods" | grep -c Running)

      if [ "$running_pods" -eq 3 ]; then
        echo "kafka pods are scaled up and running."
        break  # Exit the loop since scaling up is successful
      else
        echo "kafka pods are not all in the Running state. Retrying after 10 seconds..."
      fi
    else
      echo "kafka pods are not scaled up properly. Retrying after 10 seconds..."
    fi

    attempt=$((attempt + 1))
    if [ "$attempt" -le "$max_attempts" ]; then
      sleep 20
    else
      echo "Failed to scale up kafka pods within the specified time."
      exit 1  # Exit the script with a non-zero status indicating failure
    fi
  done
  echo "==========================================================="

  echo "-------Scale up the Tunnel service to count 2---------"
  kubectl scale sts tunnel -n nirmata --replicas=2

  echo "==========================================================="

  echo "--------Verify if the Tunnel pods are scaled up and running--------"
  tunnel_pods=$(kubectl get pods -n nirmata -l nirmata.io/statefulset.name=tunnel)
  tunnel_pod_count=$(echo "$tunnel_pods" | grep -c Running)

  sleep 30

  if [ "$tunnel_pod_count" -eq 2 ]; then
    echo "Tunnel pods are scaled up and running."
  else
    echo "Tunnel pods are not scaled up properly. Please check and ensure proper scaling."
    echo "$tunnel_pods"
  fi

  sleep 20
  echo "==========================================================="

  echo "---------Scale up the Nirmata Services------------"
  # Iterate over the deployment names and scale up the respective deployments
  for i in "${!deployment_names[@]}"; do
    deployment_name=${deployment_names[i]}
    replica_count=${replica_counts[i]}
    kubectl scale deploy "$deployment_name" -n nirmata --replicas="$replica_count"
  done
  sleep 120
  echo "==========================================================="

  echo "------Listing MongoDB new PVs---------"
  mongodb_pvs=$(kubectl get pv -n nirmata | grep -i mongodb)

  echo "MongoDB PVs:"
  echo "$mongodb_pvs"

  echo "==========================================================="

  echo "--------Setting up Retain state to MongoDB PVs--------"
  # Extract the PV names from the stored output
  pv_names=$(echo "$mongodb_pvs" | awk '{print $1}')

  # Set the reclaim policy to "Retain" for MongoDB PVs
  kubectl patch pv $pv_names -n nirmata -p '{"spec":{"persistentVolumeReclaimPolicy":"Retain"}}'

  echo "==========================================================="

  echo "Checking pod statuses..."

  # Get the pod statuses
  kubectl get pods -n nirmata --no-headers=true -o=custom-columns='POD:metadata.name,STATUS:status.phase' | awk '{print $1, $2}'
  pod_statuses=$(kubectl get pods -n nirmata --no-headers=true | awk '{print $3}')

  echo "Current pod statuses:"
  echo "$pod_statuses"


  sleep 10
      echo "==========================================================="
  echo "-------Wait for 2 minutes----------"
  sleep 120  # Sleep for 5 minutes (300 seconds)
    # Function to check and display the names of non-ready pods
    check_non_ready_pods() {
        local namespace=$1
        local attempts=0

        while [ $attempts -lt 3 ]; do
            non_ready_pods=($(kubectl get pods -n "$namespace" --no-headers=true --field-selector=status.phase!=Running --output=jsonpath='{.items[*].metadata.name}'))

            if [ ${#non_ready_pods[@]} -eq 0 ]; then
                echo "All pods are running."
                return 0
            else
                echo "Found the following non-ready pod(s):"
                for pod_name in "${non_ready_pods[@]}"; do
                    echo "- $pod_name"
                    echo "Deleting pod: $pod_name"
                    kubectl delete pod "$pod_name" -n "$namespace"
                done
                echo "Waiting for 60 seconds before retrying..."
                sleep 60
                attempts=$((attempts + 1))
            fi
        done

        echo "Failed to bring all pods into the running state after multiple retries. Please fix the pods."
        exit 1
    }

    # Store the namespace in a variable
    namespace="nirmata"

    # Check for non-ready pods
    check_non_ready_pods "$namespace"

  echo "==========================================================="


  echo " Mongodb Cleanup is done"
  echo "Please do verify by running the Health Script"
  echo "Please check from UI side: Nirmata is up? Clusters are ready? Env is showing up ? Users can log in?"
