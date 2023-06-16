#!/bin/bash

set -e

installjq() {

        # Check the operating system
        if [[ "$(uname)" == "Darwin" ]]; then
                # Mac OS X
                brew install jq
        elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
                # Linux
                if [[ -n "$(command -v yum)" ]]; then
                        # CentOS, RHEL, Fedora
                        sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
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
DOCKER_CONFIG="/etc/sysconfig/docker"
SYSTEMD_SERVICE="/usr/lib/systemd/system/docker.service"

if [[ -n "$(command -v jq)" ]]; then
    echo "jq is installed."
    jq --version
else
    echo -e "\njq is not installed. Installing jq ...\n"
    installjq
    echo "jq is installed successfully"
fi


echo "========================================="
echo "Removing log driver configuration from /etc/sysconfig/docker"
echo "========================================="
if grep -q "^OPTIONS=.*--log-driver" "$DOCKER_CONFIG"; then
    sed -i '/--log-driver/d' "$DOCKER_CONFIG"
    echo "Removed log driver configuration from /etc/sysconfig/docker successfully"
fi


echo "========================================="
echo "Updating log driver configuration in /etc/docker/daemon.json"
echo "========================================="
if [ -s "$FILENAME" ]; then
        cp $FILENAME /etc/docker/daemon.json.bak
        jq '. + {"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "10"}}' $FILENAME > /etc/docker/daemon.tmp && mv /etc/docker/daemon.tmp $FILENAME
        echo "========================================="
    echo "Checking if cgroupdriver option is already configured in the docker systemd service file"
    echo "========================================="
    if ! grep -q "native.cgroupdriver" $SYSTEMD_SERVICE; then
    echo "========================================="
        echo "As it's not configured, adding it to daemon.json file"
        echo "========================================="
        echo '{"exec-opts": ["native.cgroupdriver=systemd"]}' >> $FILENAME
        echo "Updated log driver configuration in /etc/docker/daemon.json successfully"
    fi
else
    sudo mkdir -p /etc/docker
    # echo '{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "10"}, "exec-opts": ["native.cgroupdriver=systemd"]}' | sudo tee $FILENAME > /dev/null
    echo '{"log-driver": "json-file", "log-opts": {"max-size": "10m", "max-file": "10"}}' | sudo tee $FILENAME > /dev/null
    echo "As Docker Daemon file is not present so now creating & updating log driver configuration in /etc/docker/daemon.json successfully"
fi


echo "========================================="
echo "Reloading systemd configuration and restarting Docker daemon"
echo "========================================="
sudo systemctl daemon-reload
sudo systemctl restart docker
echo "Docker restarted successfully"

echo "========================================="
echo "checking for cgroupdriver opts in /usr/lib/systemd/system/docker.service"
echo "========================================="
if grep -q "native.cgroupdriver" $SYSTEMD_SERVICE; then
    sudo sed -i '/native.cgroupdriver/d' $SYSTEMD_SERVICE
fi

echo "========================================="
echo  "Updating cgroupdriver configuration in /etc/docker/daemon.json if it's not already set in docker.service file"
echo "========================================="

if ! grep -q "native.cgroupdriver" $SYSTEMD_SERVICE; then
    cp $FILENAME /etc/docker/daemon.json.bak
    jq '. + {"exec-opts": ["native.cgroupdriver=systemd"]}' $FILENAME > /etc/docker/daemon.tmp && mv /etc/docker/daemon.tmp $FILENAME
fi

echo "========================================="
echo "Restarting Docker daemon again to apply changes"
echo "========================================="
sudo systemctl daemon-reload
sudo systemctl restart docker
echo "Docker restarted successfully"

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

if [ -s "$FILENAME" ]; then
    cp $FILENAME /etc/docker/daemon.json.bak
    jq '. + {"exec-opts": ["native.cgroupdriver=systemd"]}' $FILENAME > /etc/docker/daemon.tmp && mv /etc/docker/daemon.tmp $FILENAME
else
    sudo mkdir -p /etc/docker
    echo '{ "exec-opts": ["native.cgroupdriver=systemd"] }' | sudo tee $FILENAME > /dev/null
fi
