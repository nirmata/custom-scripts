#!/bin/bash -x 
# Install Docker 
sudo yum update -y 

sudo tee /etc/yum.repos.d/docker.repo <<-'EOF'
[dockerrepo]
name=Docker Repository
baseurl=https://yum.dockerproject.org/repo/main/centos/7/
enabled=1
gpgcheck=1
gpgkey=https://yum.dockerproject.org/gpg 
EOF

sudo mount -o remount,rw '/sys/fs/cgroup' 
sudo ln -s /sys/fs/cgroup/cpu,cpuacct /sys/fs/cgroup/cpuacct,cpu 

sudo yum install -y docker-engine
sudo systemctl enable docker.service
sudo systemctl start docker