#!/bin/bash

action=$1
nirmata_service_type=$2
replica_count=$4

if ([[ "$action" == "start" ]] && [[ "$3" != "replicas" ]]) && [[ "$#" != 4 ]]; then
  echo "Usage: $0 <start or stop> <nirmata_service_type> <replica_count>"
  echo "Example: $0 start kafka replicas 3"
  exit 1
elif [[ "$action" == "stop" ]] && [[ "$#" !=  2 ]]; then
  echo "Usage: $0 <start or stop> <nirmata_service_type> <replica_count>"
  echo "Example: $0 stop kafka"
  exit 1
fi 

echo "==========================================================="

kubectl config set-context --current --namespace pe420

if [ "$action" = "start" ]; then
  # if [ -z "$service_name" ]; then
  #   echo "Service name not provided. Skipping shared setup."
  # else
  echo "Starting service: $nirmata_service_type..."
   case "$nirmata_service_type" in
    "mongodb")
      kubectl scale sts mongodb -n nirmata --replicas=$replica_count

       # Wait until all MongoDB pods are up and running
      for i in {0..2}; do
        pod_name="mongodb-$i"
        kubectl wait --for=condition=Ready pod/$pod_name -n nirmata --timeout=300s
      done
      ;;
    "zk")
      kubectl scale sts zk -n nirmata --replicas=$replica_count

       # Wait until all ZooKeeper pods are up and running
      for i in {0..2}; do
        pod_name="zk-$i"
        kubectl wait --for=condition=Ready pod/$pod_name -n nirmata --timeout=300s
      done
      ;;
    "kafka-controller")
      kubectl scale sts kafka-controller -n nirmata --replicas=$replica_count

       # Wait until all Kafka-controller pods are up and running
      for i in {0..2}; do
        pod_name="kafka-controller-$i"
        kubectl wait --for=condition=Ready pod/$pod_name -n nirmata --timeout=300s
      done
      ;;
    "kafka")
      kubectl scale sts kafka -n pe420 --replicas=$replica_count

       # Wait until all Kafka pods are up and running
      for i in {0..2}; do
        pod_name="kafka-$i"
        kubectl wait --for=condition=Ready pod/$pod_name -n pe420 --timeout=300s
      done
      ;;
    "tunnel")
      kubectl scale sts tunnel -n nirmata --replicas=$replica_count

       # Wait until all Kafka pods are up and running
      for i in {0..2}; do
        pod_name="tunnel-$i"
        kubectl wait --for=condition=Ready pod/$pod_name -n nirmata --timeout=300s
      done
      # Add logic for the "tunnel" service setup
      ;;
    "deploy")
      kubectl scale deploy --all -n nirmata --replicas=$replica_count

       # Wait until all pods are up and running
      for i in {0..2}; do
        pod_name="kafka-$i"
        kubectl wait --for=condition=Ready pod/$pod_name -n nirmata --timeout=300s
      done
      ;;
    *)
      echo "Invalid service name. Supported services: mongodb, zk, kafka, tunnel, kafka-controller, deploy"
      exit 1
      ;;
  esac
elif [ "$action" = "stop" ]; then
    case "$nirmata_service_type" in
      "mongodb" | "zk" | "kafka-controller" | "kafka" | "tunnel")
        echo "Scaling down StatefulSet for service: $nirmata_service_type..."
        kubectl scale sts "$nirmata_service_type" -n pe420 --replicas=0
  
        # Wait until all pods are scaled down to 0
        kubectl wait --for=delete pod -l app="$nirmata_service_type" -n pe420 --timeout=300s --all
        ;;
      "deploy")
        echo "Invalid shared service name. Supported services: mongodb, zk, kafka-controller, kafka, tunnel"
        exit 1
        ;;
      *)
        echo "Error"
        exit 1
        ;;

  # elif [ "$nirmata_service_type" = "deploy" ]; then
      echo "Scaling down all deployments in the nirmata namespace..."
      
      # Get all deployments in the nirmata namespace
      deployments=$(kubectl get deployments -n nirmata -o jsonpath='{.items[*].metadata.name}')
      
      # Scale down each deployment to 0 replicas
      for deployment in $deployments; do
        kubectl scale deployment "$deployment" -n nirmata --replicas=0
      done
      
      # Wait until all pods are scaled down to 0 for each deployment
      for deployment in $deployments; do
        kubectl wait --for=delete pod -l app="$deployment" -n nirmata --timeout=300s --all
      done
    esac
  # else
  #   echo "Invalid action for Nirmata service type. Supported actions: start, stop"
  #   exit 1
  # fi
else
  echo "Invalid action. Supported actions: start, stop"
  exit 1
fi

kubectl config set-context --current --namespace default