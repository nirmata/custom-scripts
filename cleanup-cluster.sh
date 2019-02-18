#!/bin/bash
# Nirmata cleanup script

# Stop and remove any running containers
sudo docker stop $(sudo docker ps | grep “flannel” | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "nirmata" | gawk '{print $1}')
sudo docker stop $(sudo docker ps | grep "kube" | gawk '{print $1}')
sudo docker rm  $(sudo docker ps -a | grep "Exit" |gawk '{print $1}')

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
