#!/bin/bash
# check if containerd is installed

echo "==============================================="
echo "Checking if containerd is installed"
echo "==============================================="
if ! command -v containerd > /dev/null; then
  echo "Containerd is not installed, installing now..."
  # install containerd based on the OS
  if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y containerd
  elif [ -f /etc/redhat-release ]; then
    sudo yum install -y containerd
  fi
fi
# check for the latest version of Docker
echo "==============================================="
echo "Checking if docker is up-to-date"
echo "==============================================="
current_version=$(docker version --format '{{.Client.Version}}')
latest_version=$(curl --silent https://download.docker.com/linux/static/stable/x86_64/ | grep -o "docker-[0-9.]*\.tgz" | sort -V | tail -n 1 | cut -d '-' -f 2 | cut -d '.' -f 1,2)
if [ "$current_version" != "$latest_version" ]; then
  echo "Docker is not up-to-date, upgrading now..."
  # upgrade Docker based on the OS
  if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get upgrade -y docker
  elif [ -f /etc/redhat-release ]; then
    sudo yum upgrade -y docker
  fi
fi
# remove config.toml file
echo "==============================================="
echo "Removing containerd config.toml file"
echo "==============================================="
sudo rm -f /etc/containerd/config.toml
# restart containerd
echo "==============================================="
echo "Resarting Containerd"
echo "==============================================="
sudo systemctl restart containerd
# check the status of containerd
echo "==============================================="
echo "Checking containerd status"
echo "==============================================="
status=$(sudo systemctl status containerd | grep "Active:" | awk '{print $2}')
echo "Containerd status: $status"