#!/bin/bash
# Nirmata PE verifier -- 1/28/2019
docker_fs="/var/lib/docker"

# Check for swap and output findings;
cat /proc/swaps
read -p "Press enter to continue if swap is good"

# Confirm docker is installed and output version + proxy info
docker info | grep 'Version\|HTTP Proxy\|HTTPS Proxy'
read -p "Press enter to continue if Docker looks good"

# Check export and look for proxy settings
export | grep 'http_proxy\|https_proxy\|no_proxy'
read -p "Press enter to continue if export is good"

# Check for seperate filesystem for docker (/var/lib/docker)
if mountpoint -q "$docker_fs"; then
    echo "$docker_fs is a mountpoint"
else
    echo "$docker_fs is not a mountpoint"
fi
read -p "Press enter to continue if mountpoint is good"

# Check Docker configuration for log rotation
cat /etc/docker/daemon.json | grep log-opts
read -p "Press enter to continue if logs are good"
echo "Please review the data"
