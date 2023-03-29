 # Upgrade Kubernetes Node Container Runtime via Bash Script

### This Script will help you to complete the prerequisites to upgrade the container runtime from docker to containerd.

#### NOTE:
    - This script works only on RPM flavors.
    - This script needs to run on all the nodes.

#### Steps:
1. Clone/Download Script from the repo.\
    `git clone https://github.com/nirmata/custom-scripts.git `
2.  navigate to migrate_container_runtime folder\
    `cd custom-scripts/migrate_container_runtime`
3.  add execute permission to the script.\
    `chmod +x migrate_container_runtime.sh`
4.  run the script.
        `./migrate_container_runtime`

### Now after the upgradation of cluster/nodes to v1.24 or a later version, we should see the containerd as a container runtime.
