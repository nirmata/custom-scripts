 # Upgrade Kubernetes Node Container Runtime via Bash Script

### This Script will help you to complete the pre-requisites to upgrade the container runtime from docker to containerd.

#### NOTE: 
    - This script works only on RPM and Debian flavors.
    - This script needs to run on all the nodes.

#### Steps:
1. Clone/Download Script from repo.\
    `git clone https://github.com/nirmata/custom-scripts.git `
2.  navigate to container_runtime_upgrade_script folder\
    `cd custom-scripts/container_runtime_upgrade_script`
3.  add excute permission to script.\
    `chmod +x container_runtime_upgrade_script`
4.  run the script.
        `./container_runtime_upgrade_script`

### Now after upgradation of cluster/nodes to v1.24 or later version, we should see the containerd as a container runtime.
