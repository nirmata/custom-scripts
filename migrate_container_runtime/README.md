 # Upgrade Kubernetes Node Container Runtime via Bash Script

### This Script will help you to complete the prerequisites to upgrade the container runtime from docker to containerd.

#### NOTE:
    - This script works only on RPM flavors.
    - This script needs to run on all the nodes.

#### Steps:
1. Clone/Download Script from the repo.\
    `git clone https://github.com/nirmata/custom-scripts.git `
2. Navigate to migrate_container_runtime folder\
    `cd custom-scripts/migrate_container_runtime`
3. Add execute permission to the script.\
    `chmod +x migrate_container_runtime.sh`
4. Run the script. Please note that this script has to be run all the nodes of clusters. The git repository has the updated `config.toml` file which gets copied to the node when you run this script.<br />
        `./migrate_container_runtime.sh`
5. Run the `update-kubelet-args.sh` script. Please note that this script must be run just once from anywhere you have kubectl access to the cluster. This will update the kubelet args needed for docker to containerd migration <br />
        `./update-kubelet-args.sh`

### Now after the upgradation of cluster/nodes to v1.24 or a later version, we should see the containerd as a container runtime.
