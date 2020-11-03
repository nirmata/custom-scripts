#!/bin/bash -x 
sudo -i

# Setup Firewall
#systemctl disable firewalld
firewall-cmd --permanent --add-port=2379-2380/tcp
firewall-cmd --permanent --add-port=8472/udp
firewall-cmd --permanent --add-port=30000-32767/tcp
firewall-cmd --add-masquerade --permanent

# Node ports
firewall-cmd --permanent --add-port=10250-10255/tcp

# Really only the master nodes
firewall-cmd --permanent --add-port=6443/tcp

# Setup repos
yum-config-manager --add-repo https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64
yum-config-manager --enable rhel-7-server-extras-rpms
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo
yum-config-manager --add-repo https://packages.cloud.google.com/yum/repos/kubernetes-el7-x86_64

yum install -y yum-utils device-mapper-persistent-data lvm2 yum-plugin-versionlock containerd.io docker-ce kubectl 
yum update -y
# Automatic upgrades of docker = cluster death
yum versionlock docker-ce-*

# kubeadm cluster
#yum install -y yum-utils device-mapper-persistent-data   lvm2 yum-plugin-versionlock containerd.io docker-ce kubelet-1.16.15 kubeadm-1.16.15 kubectl-1.16.15 
# Automatic upgrades of docker and K8 = cluster death
#yum versionlock kubelet-* kubeadm-* kubectl-* docker-ce-*

# Basic Linux Kernel settings
echo br_netfilter > /etc/modules-load.d/br_netfilter
modprobe br_netfilter
sysctl -w net.ipv4.ip_forward=1
echo ‘net.ipv4.ip_forward=1’ >> /etc/sysctl.conf

# Turning off selinux is generally required to make things work.
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=permissive/' /etc/selinux/config

#In case you altered docker in some way.
systemctl reload docker
systemctl start docker
systemctl enable docker
