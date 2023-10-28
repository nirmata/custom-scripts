#!/bin/bash
# Nirmata cleanup script

# Stop and remove any running containers
sudo docker stop $(sudo docker ps | grep “flannel” | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "nirmata" | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "kube" | gawk '{print $1}')
sudo docker system prune --volumes -f
sudo docker image prune -f

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
