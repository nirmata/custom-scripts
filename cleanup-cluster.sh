#!/bin/bash
# Nirmata cluster cleanup script

# Stop and remove any running docker containers
sudo docker stop $(sudo docker ps | grep "flannel" | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "nirmata" | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "kube" | gawk '{print $1}')
sudo docker rm $(sudo docker ps -a | grep "Exit" | gawk '{print $1}')

# Stop and remove any running podman containers
sudo podman stop $(sudo podman ps -a | grep "flannel" | gawk '{print $1}')
sudo podman stop $(sudo podman ps -a | grep "nirmata" | gawk '{print $1}')
sudo podman stop $(sudo podman ps -a | grep "kube" | gawk '{print $1}')
sudo podman rm $(sudo podman ps -a | grep -E "Exited|Created" | awk '{print $1}')

# Stop and remove any running containerd containers
sudo ctr -n k8s.io task ls | awk '{print $1}' | xargs -t -I % sh -c '{ sudo ctr -n k8s.io task pause %;}'
sudo ctr -n k8s.io task ls | awk '{print $1}' | xargs -t -I % sh -c '{ sudo ctr -n k8s.io task kill -s SIGKILL %;}'
sudo ctr -n k8s.io c ls | awk '{print $1}' | xargs -t -I % sh -c '{ sudo ctr -n k8s.io c rm %;}'

# Remove any CNI plugins
sudo rm -rf /etc/cni/*
sudo rm -rf /opt/cni/*

# Clear IP Tables
# sudo iptables -P INPUT ACCEPT
# sudo iptables -P FORWARD ACCEPT
# sudo iptables -P OUTPUT ACCEPT
# sudo iptables -F
# sudo iptables -X
# sudo iptables -Z
# sudo iptables -t nat -F
# sudo iptables -t nat -X
# sudo iptables -t mangle -F
# sudo iptables -t mangle -X
# sudo iptables -t raw -F
# sudo iptables -t raw -X


# Flush rules in Kubernetes chains
iptables -F KUBE-PROXY-FIREWALL
iptables -F KUBE-NODEPORTS
iptables -F KUBE-EXTERNAL-SERVICES
iptables -F KUBE-FIREWALL
iptables -F KUBE-FORWARD
iptables -F KUBE-SERVICES

# Delete the Kubernetes chains
iptables -X KUBE-PROXY-FIREWALL
iptables -X KUBE-NODEPORTS
iptables -X KUBE-EXTERNAL-SERVICES
iptables -X KUBE-FIREWALL
iptables -X KUBE-FORWARD
iptables -X KUBE-SERVICES
iptables -X KUBE-KUBELET-CANARY
iptables -X KUBE-PROXY-CANARY

# Remove references in parent chains
iptables -D INPUT -j KUBE-PROXY-FIREWALL
iptables -D INPUT -j KUBE-NODEPORTS
iptables -D INPUT -j KUBE-EXTERNAL-SERVICES
iptables -D INPUT -j KUBE-FIREWALL
iptables -D FORWARD -j KUBE-FORWARD
iptables -D FORWARD -j KUBE-SERVICES
iptables -D FORWARD -j KUBE-EXTERNAL-SERVICES
iptables -D OUTPUT -j KUBE-PROXY-FIREWALL
iptables -D OUTPUT -j KUBE-SERVICES
iptables -D OUTPUT -j KUBE-FIREWALL

# Flush rules in Calico chains
iptables -F cali-INPUT
iptables -F cali-OUTPUT
iptables -F cali-FORWARD
iptables -F cali-PREROUTING
iptables -F cali-POSTROUTING

# Delete all Calico chains
iptables -X cali-INPUT
iptables -X cali-OUTPUT
iptables -X cali-FORWARD
iptables -X cali-PREROUTING
iptables -X cali-POSTROUTING


# Flush Kubernetes-related chains
iptables -F KUBE-SERVICES
iptables -F KUBE-POSTROUTING
iptables -F KUBE-FORWARD
iptables -F KUBE-INPUT

# Flush CNI-related chains (specific to Calico or other CNI plugins)
iptables -F CNI-FORWARD
iptables -F CNI-ADMIN

# Delete Kubernetes-related chains
iptables -X KUBE-SERVICES
iptables -X KUBE-POSTROUTING
iptables -X KUBE-FORWARD
iptables -X KUBE-INPUT

# Delete CNI-related chains
iptables -X CNI-FORWARD
iptables -X CNI-ADMIN


# Delete dynamic Calico chains (e.g., cali-tw-, cali-fw-)
for chain in $(iptables -L | grep cali- | awk '{print $1}'); do
    iptables -F "$chain"
    iptables -X "$chain"
done

# Remove references to Calico chains in parent chains
iptables -D INPUT -j cali-INPUT
iptables -D OUTPUT -j cali-OUTPUT
iptables -D FORWARD -j cali-FORWARD
iptables -D PREROUTING -t nat -j cali-PREROUTING
iptables -D POSTROUTING -t nat -j cali-POSTROUTING


# Restart Docker
sudo systemctl stop docker
sudo systemctl start docker
sudo docker ps

# Restart Podman service if necessary (depending on your OS, Podman may not require this)
sudo systemctl stop podman
sudo systemctl start podman
sudo podman ps

# Deletes the CNI interfaces
sudo ifconfig cni0 down
sudo brctl delbr cni0
sudo ifconfig kube-bridge down
sudo ifconfig flannel.1 down
sudo ifconfig | grep cali | awk -F ':' '{print $1}' | xargs -t -I % sh -c '{ sudo ifconfig % down;}'
sudo ip link | grep cali | awk '{print $2}' | awk -F '@' '{print $1}' | xargs -t -I % sh -c '{ sudo ip link delete %;}'
sudo ifconfig tunl0 down
sudo ip link delete tunl0

# Remove cluster database
sudo rm -rf /data/fixtures
sudo rm -rf /data/member

# -------------------------
# Verification Section
# -------------------------

echo "Verifying cleanup..."

# Check if Docker, Podman, and containerd containers are still running
if [ -z "$(sudo docker ps -q)" ] && [ -z "$(sudo podman ps -q)" ] && [ -z "$(sudo ctr -n k8s.io c ls | grep -v 'ID')" ]; then
    echo "[GOOD] No running containers found."
else
    echo "[ERROR] Some containers are still running."
fi

# Check if CNI plugins and interfaces are removed
if [ ! -d "/etc/cni" ] && [ ! -d "/opt/cni" ] && ! ifconfig | grep -q "cni0\|kube-bridge\|flannel.1\|cali"; then
    echo "[GOOD] CNI plugins and interfaces are removed."
else
    echo "[ERROR] CNI plugins or interfaces still present."
fi

# Check if iptables rules are cleared
if [ -z "$(sudo iptables -L -n | grep -v 'Chain' | grep -v 'target')" ] && [ -z "$(sudo iptables -t nat -L -n | grep -v 'Chain' | grep -v 'target')" ]; then
    echo "[GOOD] iptables rules are cleared."
else
    echo "[ERROR] Some iptables rules still exist."
fi

# Check if Docker and Podman services are active
docker_status=$(sudo systemctl is-active docker)
podman_status=$(sudo systemctl is-active podman)
if [ "$docker_status" == "active" ]; then
    echo "[GOOD] Docker service is running."
else
    echo "[ERROR] Docker service is not active."
fi

if [ "$podman_status" == "active" ]; then
    echo "[GOOD] Podman service is running."
else
    echo "[ERROR] Podman service is not active."
fi

# Additional process verification
ps -ef | grep -E 'kube-proxy|kube-apiserver|kubelet|kube-scheduler|kube-controller-manager|etcd|kube-scheduler' | grep -v grep &>/dev/null
if [ $? -eq 0 ]; then
    echo "[WARN] Processes related to kube components are still running. Please remove them manually."
else
    echo "[GOOD] No processes related to kube components are running."
fi

# Final message
echo "Cleanup and verification complete."
