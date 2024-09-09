```markdown
# Kubernetes Port Check Script

This script performs connectivity checks between master and worker nodes in a Kubernetes cluster. It verifies if specific ports are open and reachable via `netcat` (nc) and reports the results.

## Script Download and Setup

### Download the Script

You can download the script directly using `wget`:

```bash
wget https://github.com/nirmata/custom-scripts/blob/master/kubernetes_port_check/port-check.sh
```

### Make the Script Executable

After downloading the script, make it executable with the following command:

```bash
chmod +x port-check.sh
```

## Usage

### Prerequisites

- `nc` (Netcat) must be installed on the nodes where the script will run.
- `timeout` command should be available on the system.

### Running the Script

The script requires two arguments: the IP addresses of the master and worker nodes.

#### Syntax

```bash
./port-check.sh <master-ip> <worker-ip>
```

#### Example

```bash
./port-check.sh 192.168.1.10 192.168.1.20
```

### Script Behavior

- **Node Detection**: The script determines if it is running on a master or worker node based on the provided IP addresses and the current node's IP.
- **Port Checks**: Depending on the node type, the script will check the following:
  - **Worker Node**:
    - Ports for master components (e.g., Kubernetes API Server, etcd, etc.)
    - Ports for worker components (e.g., kubelet, kube-proxy)
    - Common ports (e.g., BGP, VXLAN)
    - A random NodePort
  - **Master Node**:
    - Ports for master components
    - Ports for kubelet and proxy services to master and worker nodes
    - Common ports (e.g., BGP, VXLAN)
    - A random NodePort

### Output

- **GOOD**: Indicates successful connection.
- **WARN**: Indicates an unexpected error or issue.
- **ERROR**: Specifies a connection refusal or timeout.

### Example Output

```text
Master IP: 192.168.1.10
Worker IP: 192.168.1.20
Running on the worker node.
Checking Kubernetes API Server on port 6443 from worker to master...
[GOOD] Connection to 192.168.1.10:6443 (Kubernetes API Server) successful via netcat from the worker node.
...
Checking random NodePort 30859 on the worker node...
[WARN] Connection to 192.168.1.20:30859 (NodePort) resulted in an unexpected error: nc: connect to 192.168.1.20 port 30859 (tcp) failed: Connection refused from the worker node.
```

### Notes

- Ensure that the script is executable. You can make it executable with `chmod +x port-check.sh`.
- Adjust the port lists and node types as needed for your specific Kubernetes setup.

## Contact

For issues or questions, please open an issue on the [GitHub repository](https://github.com/nirmata/custom-scripts/issues).
```