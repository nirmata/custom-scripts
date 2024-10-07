#!/bin/bash
# Nirmata cleanup script

# Functions to display status
good() { echo -e "\e[32m[GOOD]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

# Stop and remove any running containers
sudo docker stop $(sudo docker ps | grep “flannel” | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "nirmata" | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "kube" | gawk '{print $1}')
sudo docker rm  $(sudo docker ps -a | grep "Exit" |gawk '{print $1}')

sudo podman stop $(sudo podman ps -a | grep "flannel" | gawk '{print $1}')
sudo podman stop $(sudo podman ps -a | grep "nirmata" | gawk '{print $1}')
sudo podman stop $(sudo podman ps -a | grep "kube" | gawk '{print $1}')
sudo podman rm $(sudo podman ps -a | grep -E "Exited|Created" | awk '{print $1}')


# Remove any cni plugins
sudo rm -rf /etc/cni/*
sudo rm -rf /opt/cni/*

# Clear IP Tables
sudo iptables --flush
sudo iptables -tnat --flush

# Restart Docker
sudo systemctl stop docker
sudo systemctl start docker
sudo docker ps

# Restart Podman
sudo systemctl stop podman
sudo systemctl start podman
sudo podman ps

# Deletes the CNI interface
sudo ifconfig cni0 down
sudo brctl delbr cni0
sudo ifconfig flannel.1 down
sudo ip link delete cni0
sudo ip link delete flannel.1

# Remove cluster database
sudo rm -rf /data

# Remove Nirmata dir
sudo rm -rf /opt/nirmata

# Clean Nirmata agent
sudo systemctl stop nirmata-agent.service
sudo systemctl disable nirmata-agent.service
sudo rm -rf /etc/systemd/system/nirmata-agent.service


# Function to check if all containerd tasks and containers are removed
check_containerd_cleanup() {
    echo "Verifying containerd cleanup..."

    # Check for any remaining tasks in the k8s.io namespace
    if [ -z "$(sudo ctr -n k8s.io task ls | awk 'NR>1')" ]; then
        good "All containerd tasks in the k8s.io namespace are removed."
    else
        warn "Some containerd tasks are still present in the k8s.io namespace."
    fi

    # Check for any remaining containers in the k8s.io namespace
    if [ -z "$(sudo ctr -n k8s.io c ls | awk 'NR>1')" ]; then
        good "All containerd containers in the k8s.io namespace are removed."
    else
        warn "Some containerd containers are still present in the k8s.io namespace."
    fi
}

# Call the function to perform the check
check_containerd_cleanup

if [ "$(ls -A /etc/cni 2>/dev/null)" ]; then
    warn "/etc/cni is not empty."
else
    good "/etc/cni is empty."
fi

if [ "$(ls -A /opt/cni 2>/dev/null)" ]; then
    warn "/opt/cni is not empty."
else
    good "/opt/cni is empty."
fi

# 2. Verify IP tables are cleared
if sudo iptables -L -n | grep -qi "cali"; then
    warn "IP tables are not fully cleared."
else
    good "IP tables are cleared."
fi

if sudo iptables -t nat -L -n | grep -q "cali"; then
    warn "NAT IP tables are not fully cleared."
else
    good "NAT IP tables are cleared."
fi

# 3. Verify Docker is running without specific containers
if sudo docker ps | grep -q "flannel\|nirmata\|kube"; then
    warn "Some containers related to flannel, nirmata, or kube are still running."
else
    good "No flannel, nirmata, or kube containers are running."
fi

# 4. Verify CNI interfaces are deleted
if ip link show cni0 &>/dev/null; then
    warn "CNI interface cni0 still exists."
else
    good "CNI interface cni0 is deleted."
fi

if ip link show flannel.1 &>/dev/null; then
    warn "CNI interface flannel.1 still exists."
else
    good "CNI interface flannel.1 is deleted."
fi

# 5. Verify /data directory does not exist
if [ -d /data ]; then
    warn "/data directory still exists."
else
    good "/data directory is removed."
fi

# 6. Verify Nirmata directory and agent are removed
if [ -d /opt/nirmata ]; then
    warn "/opt/nirmata directory still exists."
else
    good "/opt/nirmata directory is removed."
fi

if systemctl is-enabled nirmata-agent.service &>/dev/null; then
    warn "nirmata-agent.service is still enabled."
else
    good "nirmata-agent.service is disabled."
fi

if [ -f /etc/systemd/system/nirmata-agent.service ]; then
    warn "nirmata-agent.service file still exists."
else
    good "nirmata-agent.service file is removed."
fi

# 7. Additional process verification
ps -ef | grep -E 'kube-proxy|kube-apiserver|kubelet|kube-scheduler|kube-controller-manager|etcd|kube-scheduler' | grep -v grep &>/dev/null
if [ $? -eq 0 ]; then
    warn "Processes related to kube components are still running. Please remove them manually."
else
    good "No processes related to kube components are running."
fi
