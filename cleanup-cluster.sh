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

# Restart Docker
sudo systemctl stop docker
sudo systemctl start docker
sudo docker ps

# Deletes the CNI interface
sudo ifconfig cni0 down
sudo brctl delbr cni0
sudo ifconfig kube-bridge down
sudo ifconfig flannel.1 down
sudo ifconfig | grep tunl | awk -F ':' '{print $1}' | xargs -t -I % sh -c '{ ifconfig % down;}'
sudo ifconfig | grep tunl | awk -F ':' '{print $1}' | xargs -t -I % sh -c '{ ip link delete %;}'
sudo ip link | grep tunl | awk '{print $2}' | awk -F '@' '{print $1}' | xargs -t -I % sh -c '{ ip link delete %;}'
sudo ip link delete kube-bridge
sudo ip link delete cni0
sudo ip link delete flannel.1

# Remove cluster database
sudo rm -rf /data/fixtures
sudo rm -rf /data/member
