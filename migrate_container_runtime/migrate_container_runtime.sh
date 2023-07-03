#!/bin/bash
set -e
echo "==============================================="
echo "Checking if containerd is installed"
echo "==============================================="
required_version="v1.6.19"
# Download Containerd release
echo "----- Downloading Containerd release v1.6.19------"
wget https://github.com/containerd/containerd/releases/download/v1.6.19/containerd-1.6.19-linux-amd64.tar.gz
wget https://raw.githubusercontent.com/containerd/containerd/main/containerd.service
echo "---Extracting the tarball-----"
tar -xvf containerd-1.6.19-linux-amd64.tar.gz

echo "---Moving the binaries to the appropriate directories---"
#sudo mv bin/* /usr/local/bin/
sudo /bin/cp -rf bin/* /usr/local/bin/
sudo /bin/cp -rf bin/* /usr/bin/

echo "---Setting up systemd service for Containerd---"
#sudo mkdir -p /etc/containerd
#sudo cp  containerd.service /etc/systemd/system/containerd.service
sudo systemctl disable containerd
sudo systemctl enable --now containerd
sudo systemctl is-enabled --now containerd
status=$(sudo systemctl status containerd | grep "Active:" | awk '{print $2}')
echo "Containerd status: $status"
echo "==============================================="
echo "---Clean up the downloaded files---"
rm  containerd-1.6.19-linux-amd64.tar.gz*
rm  containerd.service*
rm -rf bin*
echo "Containerd has been installed with version $required_version"
echo "========================================="
echo "Verifying containerd version v1.6.19"
echo "========================================="
installed_version=$(containerd --version | awk '{print $3}')
if [[ $installed_version == $required_version ]]; then
  echo "Containerd $required_version is already installed"
elif [[ $installed_version > $required_version ]]; then
  echo "Containerd is installed, but a newer version ($installed_version) is found"
else
  echo "Containerd is installed, but an older version ($installed_version) is found"
fi
echo "========================================="
echo "Copying config.toml file"
echo "========================================="
sudo cp config.toml /etc/containerd/config.toml
sudo chmod 644 /etc/containerd/config.toml
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
echo "Checking containerd status"
echo "==============================================="
status=$(sudo systemctl status containerd | grep "Active:" | awk '{print $2}')
echo "Containerd status: $status"
echo "==============================================="
