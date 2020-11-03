#!/bin/bash
# Nirmata cleanup script
if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi


# Clean Nirmata agent
systemctl stop nirmata-agent.service
systemctl disable nirmata-agent.service
rm -rf /etc/systemd/system/nirmata-agent.service

# Cleanup docker 
docker rm -f $(docker ps -qa)
docker volume rm $(docker volume ls -q)

# Clean anything that could possible leave stuff behind.
cleanupdirs="/var/lib/etcd /etc/kubernetes /etc/cni /opt/cni /var/lib/cni /var/run/calico /opt/rke /etc/cni/ /opt/cni/ /data /opt/nirmata"
for dir in $cleanupdirs; do
  echo "Removing $dir"
  rm -rf $dir
done


# Disable and cleanup Kubelet 
systemctl disable kubelet
kubeadm reset -f
microk8s reset --destroy-storage 
microk8s stop


# Clear IP Tables
iptables --flush
iptables -tnat --flush

# Restart Docker
# sudo systemctl restart docker

# Deletes the CNI interface
#sudo ifconfig cni0 down
#sudo brctl delbr cni0
#sudo ifconfig flannel.1 down
#sudo ip link delete cni0
#sudo ip link delete flannel.1

echo Rebooting System to flush kernel, and any hung containers.
reboot

