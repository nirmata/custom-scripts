#!/bin/bash

# Functions to print status
good() {
    echo -e "[\e[32mGOOD\e[0m] $1"
}

warn() {
    echo -e "[\e[33mWARN\e[0m] $1"
}

# Function to check if a port is open via telnet
check_telnet() {
    local host=$1
    local port=$2
    local component=$3
    local node_type=$4
    if (echo > /dev/tcp/$host/$port) &>/dev/null; then
        good "Connection to $host:$port ($component) successful via telnet from the $node_type node."
    else
        warn "Connection to $host:$port ($component) failed via telnet from the $node_type node."
    fi
}

# Check if master and worker IPs are passed as arguments
if [ $# -ne 2 ]; then
    echo "Usage: $0 <master-ip> <worker-ip>"
    exit 1
fi

MASTER_IP=$1
WORKER_IP=$2

echo "Master IP: $MASTER_IP"
echo "Worker IP: $WORKER_IP"

# Detect if the script is running on the master or worker node
NODE_TYPE=""

# Check if current IP matches the master or worker IP
CURRENT_IP=$(hostname -I | awk '{print $1}')

if [ "$CURRENT_IP" == "$MASTER_IP" ]; then
    NODE_TYPE="master"
elif [ "$CURRENT_IP" == "$WORKER_IP" ]; then
    NODE_TYPE="worker"
else
    echo "Unable to determine if this is master or worker node based on the provided IPs."
    exit 1
fi

echo "Running on the $NODE_TYPE node."

# Ports and components for master and worker nodes
declare -A MASTER_PORTS=(
    [6443]="Kubernetes API Server"
    [2379]="etcd"
    [10259]="KubeScheduler"
    [10257]="Controller-Manager"
)

declare -A WORKER_PORTS=(
    [10250]="kubelet"
    [10256]="kube-proxy"
)

declare -A COMMON_PORTS=(
    [179]="BGP"
    [9099]="Custom Service"
    [4789]="VXLAN"
)

# Perform checks based on node type
if [ "$NODE_TYPE" == "worker" ]; then
    echo "Performing checks from the worker node..."

    # Check only master-related ports from worker to master
    for port in "${!MASTER_PORTS[@]}"; do
        component=${MASTER_PORTS[$port]}
        echo "Checking $component on port $port from worker to master..."
        check_telnet "$MASTER_IP" "$port" "$component" "worker to master"
    done

    # Check worker-related ports on both worker to master and worker to worker
    for port in "${!WORKER_PORTS[@]}"; do
        component=${WORKER_PORTS[$port]}
        echo "Checking $component on port $port from worker to master..."
        check_telnet "$MASTER_IP" "$port" "$component" "worker to master"
        echo "Checking $component on port $port from worker to worker..."
        check_telnet "$WORKER_IP" "$port" "$component" "worker to worker"
    done

    # Check common ports (BGP, Custom Service, VXLAN) on both worker to master and worker to worker
    for port in "${!COMMON_PORTS[@]}"; do
        component=${COMMON_PORTS[$port]}
        echo "Checking $component on port $port from worker to master..."
        check_telnet "$MASTER_IP" "$port" "$component" "worker to master"
        echo "Checking $component on port $port from worker to worker..."
        check_telnet "$WORKER_IP" "$port" "$component" "worker to worker"
    done

    # Random NodePort check (30000-32767)
    RANDOM_PORT=$((30000 + RANDOM % 2768))
    echo "Checking random NodePort $RANDOM_PORT on the worker node..."
    check_telnet "$WORKER_IP" "$RANDOM_PORT" "NodePort" "worker"
    echo "Checking random NodePort $RANDOM_PORT on the master node..."
    check_telnet "$MASTER_IP" "$RANDOM_PORT" "NodePort" "worker"

elif [ "$NODE_TYPE" == "master" ]; then
    echo "Performing checks from the master node..."

    # Check master-related ports from the master node
    for port in "${!MASTER_PORTS[@]}"; do
        component=${MASTER_PORTS[$port]}
        echo "Checking $component on port $port from master to master..."
        check_telnet "$MASTER_IP" "$port" "$component" "master"
    done

    # Check kubelet and proxy ports from master to master and worker
    for port in "${!WORKER_PORTS[@]}"; do
        component=${WORKER_PORTS[$port]}
        echo "Checking $component on port $port from master to master..."
        check_telnet "$MASTER_IP" "$port" "$component" "master"
        echo "Checking $component on port $port from master to worker..."
        check_telnet "$WORKER_IP" "$port" "$component" "master"
    done

    # Check common ports (BGP, Custom Service, VXLAN) from master to master and worker
    for port in "${!COMMON_PORTS[@]}"; do
        component=${COMMON_PORTS[$port]}
        echo "Checking $component on port $port from master to master..."
        check_telnet "$MASTER_IP" "$port" "$component" "master"
        echo "Checking $component on port $port from master to worker..."
        check_telnet "$WORKER_IP" "$port" "$component" "master"
    done

    # Random NodePort check (30000-32767)
    RANDOM_PORT=$((30000 + RANDOM % 2768))
    echo "Checking random NodePort $RANDOM_PORT on the master node..."
    check_telnet "$MASTER_IP" "$RANDOM_PORT" "NodePort" "master"
    echo "Checking random NodePort $RANDOM_PORT on the worker node..."
    check_telnet "$WORKER_IP" "$RANDOM_PORT" "NodePort" "master"
fi
