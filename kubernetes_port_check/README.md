# Port Connectivity Check Script

This script checks the connectivity of specific ports on master and worker nodes in a Kubernetes cluster. It uses `telnet` to determine if the ports are open and provides detailed feedback on connection issues.

## Script Overview

The script performs connectivity checks for various ports used by Kubernetes components, services, and common networking ports. It can run from either the master or worker node and checks both internal and external connectivity.

### Features

- **Port Checking**: Verifies if specified ports are open on master and worker nodes.
- **Detailed Output**: Captures and reports connection issues, including specific reasons for failure.
- **Random NodePort Check**: Validates connectivity to a random NodePort within the typical range.

## Prerequisites

- **telnet**: Ensure `telnet` is installed on your system. Install it using:
  ```bash
  sudo apt-get install telnet   # Debian-based distributions
  sudo yum install telnet       # RHEL-based distributions
  ```

## Usage

1. **Download the Script**:
   ```bash
   wget https://github.com/nirmata/custom-scripts/blob/master/kubernetes_port_check/port-check.sh
   chmod +x port-check.sh
   ```

2. **Run the Script**:
   ```bash
   ./port-check.sh <master-ip> <worker-ip>
   ```

   Replace `<master-ip>` and `<worker-ip>` with the IP addresses of your master and worker nodes, respectively.

## Example

To check ports with a master node IP of `172.31.13.198` and a worker node IP of `172.31.14.159`, run:
```bash
./port-check.sh 172.31.13.198 172.31.14.159
```

## Output

The script provides detailed feedback, including:
- **GOOD**: Indicates a successful connection.
- **WARN**: Shows warnings with the output of the failed connection attempts.
- **ERROR**: Specifies exact issues like connection refusal or timeouts.

Example output:
```
Checking Custom Service on port 9099 from worker to master...
[WARN] Connection to 172.31.13.198:9099 (Custom Service) failed from the worker to master node. Output: 
```

## Contribution

If you have any improvements or find issues, please feel free to contribute or open an issue on the [GitHub repository](https://github.com/nirmata/custom-scripts).
