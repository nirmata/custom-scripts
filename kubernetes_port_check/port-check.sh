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
    local service=$3
    if (echo > /dev/tcp/$host/$port) &>/dev/null; then
        good "Connection to $host:$port ($service) successful via telnet."
    else
        warn "Connection to $host:$port ($service) failed via telnet."
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

echo "Node Type: $NODE_TYPE"

# Perform checks based on node type

if [ "$NODE_TYPE" == "master" ]; then
    # Master node checks

    # 1. Telnet master IP 6443 (API Server)
    echo "Checking port 6443 (Kubernetes API Server)..."
    check_telnet "$MASTER_IP" 6443 "Kubernetes API Server"

    # 2. Telnet master IP 2379 (etcd)
    echo "Checking port 2379 (etcd)..."
    check_telnet "$MASTER_IP" 2379 "etcd"

    # 3. Telnet 10259 (KubeScheduler) and 10257 (Controller-Manager)
    echo "Checking ports 10259 (KubeScheduler) and 10257 (Controller-Manager)..."
    check_telnet "$MASTER_IP" 10259 "KubeScheduler"
    check_telnet "$MASTER_IP" 10257 "Controller-Manager"

    # 4. Random NodePort check (30000-32767)
    RANDOM_PORT=$((30000 + RANDOM % 2768))
    echo "Checking random NodePort $RANDOM_PORT..."
    check_telnet "$MASTER_IP" "$RANDOM_PORT" "NodePort"

elif [ "$NODE_TYPE" == "worker" ]; then
    # Worker node checks

    # 1. Telnet master IP 6443 (API Server)
    echo "Checking port 6443 (Kubernetes API Server) from worker..."
    check_telnet "$MASTER_IP" 6443 "Kubernetes API Server"

    # 2. Telnet master IP 2379 (etcd) from worker
    echo "Checking port 2379 (etcd) from worker..."
    check_telnet "$MASTER_IP" 2379 "etcd"

    # 3. Telnet 10250 (kubelet) Worker to Master and Worker to Worker
    echo "Checking port 10250 (kubelet)..."
    check_telnet "$MASTER_IP" 10250 "kubelet (master to worker)"
    check_telnet "$WORKER_IP" 10250 "kubelet (worker to worker)"

    # 4. Telnet 10256 (kube-proxy) Worker to Master and Worker to Worker
    echo "Checking port 10256 (kube-proxy)..."
    check_telnet "$MASTER_IP" 10256 "kube-proxy (master to worker)"
    check_telnet "$WORKER_IP" 10256 "kube-proxy (worker to worker)"

    # 5. Random NodePort check (30000-32767)
    RANDOM_PORT=$((30000 + RANDOM % 2768))
    echo "Checking random NodePort $RANDOM_PORT..."
    check_telnet "$WORKER_IP" "$RANDOM_PORT" "NodePort"
fi
