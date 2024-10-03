#!/bin/bash
# Nirmata cleanup script

# Stop and remove any running containers
sudo podman stop $(sudo podman ps | grep “flannel” | gawk '{print $1}')
sudo podman stop $(sudo podman ps | grep "nirmata" | gawk '{print $1}')
sudo podman stop $(sudo podman ps | grep "kube" | gawk '{print $1}')
sudo podman rm  $(sudo podman ps -a | grep "Exit" |gawk '{print $1}')

# Remove any cni plugins
sudo rm -rf /etc/cni/*
sudo rm -rf /opt/cni/*

# Clear IP Tables
sudo iptables --flush
sudo iptables -tnat --flush

# Restart podman
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
