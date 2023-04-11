#!/bin/bash

installjq() {

        # Check the operating system
        if [[ "$(uname)" == "Darwin" ]]; then
                # Mac OS X
                brew install jq
        elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
                # Linux
                if [[ -n "$(command -v yum)" ]]; then
                        # CentOS, RHEL, Fedora
                        sudo yum install -y jq
                elif [[ -n "$(command -v apt-get)" ]]; then
                        # Debian, Ubuntu, Mint
                        sudo apt-get update
                        sudo apt-get install -y jq
                elif [[ -n "$(command -v zypper)" ]]; then
                        # OpenSUSE
                        sudo zypper install -y jq
                elif [[ -n "$(command -v pacman)" ]]; then
                        # Arch Linux
                        sudo pacman -S --noconfirm jq
                else
                        echo "Error: Unsupported Linux distribution."
                        exit 1
                fi
        else
                echo "Error: Unsupported operating system."
                exit 1
        fi

        # Print the version of jq installed
        jq --version

}

## main

FILENAME="/etc/docker/daemon.json"

if [[ -n "$(command -v jq)" ]]; then
    echo "jq is installed."
    jq --version
else
    echo -e "\njq is not installed. Installing jq ...\n"
    installjq
fi


echo "========================================="
                echo "Configure Docker to use systemd"

echo "========================================="

#echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' | sudo tee /etc/docker/daemon.json

if [ -s "$FILENAME" ]; then
    cp $FILENAME /etc/docker/daemon.json.bak
    jq '. + {"exec-opts": ["native.cgroupdriver=systemd"]}' $FILENAME > /etc/docker/daemon.tmp && mv /etc/docker/daemon.tmp $FILENAME
else
    sudo mkdir -p /etc/docker
    echo '{ "exec-opts": ["native.cgroupdriver=systemd"] }' | sudo tee $FILENAME > /dev/null
fi

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


#echo "========================================="
#                echo "Create the default config.toml file for containerd"
#echo "========================================="
#sudo containerd config default | sudo tee /etc/containerd/config.toml
#
#echo "========================================="
#                echo "Remove the systemd_group configuration from the CRI plugin section"
#echo "========================================="
#sudo sed -i '/systemd_cgroup/d' /etc/containerd/config.toml
#
#echo "========================================="
#                echo "Enable SystemdCgroup option in the Runc runtime section"
#echo "========================================="
#sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/g' /etc/containerd/config.toml
#
#echo "========================================="
#echo "Set max_size argument for containerd logs"
#sudo sed -i '/\[plugins."io.containerd.grpc.v1.cri".containerd.default_runtime\]/a\ \ \ \ \ \ \ \ [plugins."io.containerd.grpc.v1.cri".containerd.default_runtime.logs]\n\ \ \ \ \ \ \ \ \ \ max_size = "100m"' /etc/containerd/config.toml
#echo "========================================="

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

#echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' | sudo tee /etc/docker/daemon.json

if [ -s "$FILENAME" ]; then
    cp $FILENAME /etc/docker/daemon.json.bak
    jq '. + {"exec-opts": ["native.cgroupdriver=systemd"]}' $FILENAME > /etc/docker/daemon.tmp && mv /etc/docker/daemon.tmp $FILENAME
else
    sudo mkdir -p /etc/docker
    echo '{ "exec-opts": ["native.cgroupdriver=systemd"] }' | sudo tee $FILENAME > /dev/null
fi
