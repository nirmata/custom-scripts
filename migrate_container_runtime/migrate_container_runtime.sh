#!/bin/bash

set -e

echo "========================================="
		echo "Configure containerd to use version 1.6.19"
echo "========================================="
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
sudo yum install -y containerd.io-1.6.19
sudo systemctl start containerd


echo "========================================="
		echo "Verifying containerd  version 1.6.19"
echo "========================================="
if rpm -q containerd.io-1.6.19; then
echo "========================================="
  echo "containerd version v1.6.19 installed successfully"
echo "========================================="
  # proceed with the next step
else
echo "========================================="
  echo "Failed to install containerd version v1.6.19"
echo "========================================="
  exit 1 
fi

echo "========================================="
  echo "Copying config.toml file"
echo "========================================="
cp config.toml /etc/containerd/config.toml
chmod 644 /etc/containerd/config.toml

echo "========================================="
                echo "Restart containerd to apply the changes"
echo "========================================="
sudo systemctl restart containerd
if [ $? -eq 0 ]; then
echo "========================================="
echo "containerd restarted successfully."
echo "========================================="
else
echo "========================================="
echo "Failed to restart containerd."
echo "========================================="
fi
