#!/bin/bash

# check if containerd is installed
echo "==============================================="
echo "Checking if containerd is installed"
echo "==============================================="
if command -v containerd &> /dev/null; then
  echo "Containerd is already installed"
else
  echo "Containerd is not installed, installing now..."
  # install containerd based on the OS
  if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y containerd
  elif [ -f /etc/redhat-release ]; then
    sudo yum install -y containerd
  fi
fi

# configure Docker repository
echo "==============================================="
echo "Configuring Docker repository"
echo "==============================================="
if [ -f /etc/debian_version ]; then
  sudo apt-get update
  sudo apt-get install -y apt-transport-https ca-certificates curl gnupg-agent software-properties-common
  curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -
  sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"
elif [ -f /etc/redhat-release ]; then
  sudo yum install -y yum-utils
  sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
fi

# upgrade Docker to latest version
echo "==============================================="
echo "Upgrading Docker to the latest version"
echo "==============================================="
if [ -f /etc/debian_version ]; then
  sudo apt-get update
  sudo apt-get upgrade -y docker-ce docker-ce-cli containerd.io
elif [ -f /etc/redhat-release ]; then
  sudo yum upgrade -y docker-ce docker-ce-cli containerd.io
fi

# check for the latest version of Docker
echo "==============================================="
echo "Checking if Docker is up-to-date"
echo "==============================================="
current_version=$(sudo docker version --format '{{.Client.Version}}')
latest_version=$(curl --silent https://download.docker.com/linux/static/stable/x86_64/ | grep -o "docker-[0-9.]*\.tgz" | sort -V | tail -n 1 | cut -d '-' -f 2 | cut -d '.' -f 1-3
)
if [ "$current_version" != "$latest_version" ]; then
  echo "Docker upgrade failed, current version: $current_version, latest version: $latest_version"
else
  echo "Docker upgrade succeeded, current version: $current_version, latest version: $latest_version"
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
