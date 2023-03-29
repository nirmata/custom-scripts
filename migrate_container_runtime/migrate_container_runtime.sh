#!/bin/bash

echo "========================================="
		echo "Configure Docker to use systemd"
echo "========================================="
echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' | sudo tee /etc/docker/daemon.json
sudo systemctl daemon-reload
sudo systemctl restart docker

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
		echo "Create the default config.toml file for containerd"
echo "========================================="
sudo containerd config default | sudo tee /etc/containerd/config.toml

echo "========================================="
		echo "Remove the systemd_group configuration from the CRI plugin section"
echo "========================================="
sudo sed -i '/systemd_cgroup/d' /etc/containerd/config.toml

echo "========================================="
		echo "Enable SystemdCgroup option in the Runc runtime section"
echo "========================================="
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml

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
