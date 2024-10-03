#!/bin/bash
# Nirmata cluster cleanup script for podman

# Stop and remove any running podman containers
sudo podman stop $(sudo podman ps | grep "flannel" | gawk '{print $1}')
sudo podman stop $(sudo podman ps | grep "nirmata" | gawk '{print $1}')
sudo podman stop $(sudo podman ps | grep "kube" | gawk '{print $1}')
sudo podman rm $(sudo podman ps -a | grep "Exited" | gawk '{print $1}')

#Stop and remove any running containerd containers

sudo ctr -n k8s.io task ls | awk '{print $1}' | xargs -t -I % sh -c '{ sudo ctr -n k8s.io task pause %;}'
sudo ctr -n k8s.io task ls | awk '{print $1}' | xargs -t -I % sh -c '{ sudo ctr -n k8s.io task kill -s SIGKILL %;}'
sudo ctr -n k8s.io c ls | awk '{print $1}' | xargs -t -I % sh -c '{ sudo ctr -n k8s.io c rm %;}'

# Remove any cni plugins
sudo rm -rf /etc/cni/*
sudo rm -rf /opt/cni/*

# Clear IP Tables
sudo iptables -P INPUT ACCEPT
sudo iptables -P FORWARD ACCEPT
sudo iptables -P OUTPUT ACCEPT
sudo iptables -F
sudo iptables -X
sudo iptables -Z
sudo iptables -t nat -F
sudo iptables -t nat -X
sudo iptables -t mangle -F
sudo iptables -t mangle -X
sudo iptables -t raw -F
sudo iptables -t raw -X

# Restart Podman service if necessary (depending on your OS, Podman may not require this)
sudo systemctl stop podman
sudo systemctl start podman
sudo podman ps

# Deletes the CNI interface
sudo ifconfig cni0 down
sudo brctl delbr cni0
sudo ifconfig kube-bridge down
sudo ifconfig flannel.1 down
sudo ifconfig | grep cali | awk -F ':' '{print $1}' | xargs -t -I % sh -c '{ ifconfig % down;}'
sudo ip link | grep cali | awk '{print $2}' | awk -F '@' '{print $1}' | xargs -t -I % sh -c '{ ip link delete %;}'
sudo ifconfig set dev tunl0 down
sudo ifconfig tunl0 delete
sudo ifconfig | grep tunl | awk -F ':' '{print $1}' | xargs -t -I % sh -c '{ ifconfig % down;}'
sudo ifconfig | grep tunl | awk -F ':' '{print $1}' | xargs -t -I % sh -c '{ ip link delete %;}'
sudo ip link | grep tunl | awk '{print $2}' | awk -F '@' '{print $1}' | xargs -t -I % sh -c '{ ip link delete %;}'
sudo ip link delete kube-bridge
sudo ip link delete cni0
sudo ip link delete flannel.1

# Remove cluster database
sudo rm -rf /data/fixtures
sudo rm -rf /data/member
