#!/bin/bash

set -e


#!/bin/bash

echo "==============================================="
echo "Checking if containerd is installed"
echo "==============================================="

required_version="1.6.19"

if command -v containerd &> /dev/null; then
  # Check the containerd version
  installed_version=$(containerd --version | awk '{print $3}')
  required_version="1.6.19"

  if [[ $installed_version == $required_version ]]; then
    echo "Containerd $required_version is already installed"
  elif [[ $installed_version > $required_version ]]; then
    echo "Containerd is installed, but a newer version ($installed_version) is found"
    echo "Downgrading containerd to version $required_version"

    # Downgrade containerd to the required version
    if [ -f /etc/debian_version ]; then
      sudo apt-get update
      sudo apt-get install -y containerd.io="$required_version"
    elif [ -f /etc/redhat-release ]; then
      echo "========================================="
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum downgrade -y containerd.io-"$required_version"
      sudo systemctl start containerd
    fi

    echo "Containerd has been downgraded to version $required_version"
  else
    echo "Containerd is installed, but an older version ($installed_version) is found"
    echo "Upgrading containerd to version $required_version"

    # Upgrade containerd to the required version
    if [ -f /etc/debian_version ]; then
      sudo apt-get update
      sudo apt-get install -y containerd.io="$required_version"
    elif [ -f /etc/redhat-release ]; then
      echo "========================================="
      sudo yum install -y yum-utils
      sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
      sudo yum upgrade -y containerd.io-"$required_version"
      sudo systemctl start containerd
    fi

    echo "Containerd has been upgraded to version $required_version"
  fi
else
  echo "Containerd is not installed, installing now..."

  # Install containerd with the required version
  if [ -f /etc/debian_version ]; then
    sudo apt-get update
    sudo apt-get install -y containerd.io="$required_version"
  elif [ -f /etc/redhat-release ]; then
    echo "========================================="
    sudo yum install -y yum-utils
    sudo yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
    sudo yum install -y containerd.io-"$required_version"
    sudo systemctl start containerd
  fi

  echo "Containerd has been installed with version $required_version"
fi


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
