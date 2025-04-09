# Log Capture Script for Kubernetes Deployments/StatefulSets

This script captures logs from all pods associated with one or more Kubernetes `Deployments` or `StatefulSets` in a specified namespace for a defined duration. It saves the logs into a directory and compresses them into a ZIP file in the current working directory.

## Features

- Supports capturing logs from multiple `Deployments` or `StatefulSets` in one go.
- Captures logs for a default duration of 10 minutes.
- Logs are stored in a timestamped folder and compressed into a zip file.
- Handles manual interruption and ensures logs are still saved if the process is interrupted.

## Prerequisites

- Kubernetes cluster accessible via `kubectl`.
- Proper permissions to read logs in the provided namespace.
- Bash shell.

## Usage

```bash
./capture_logs.sh <deploy|sts> <namespace> <resource-name1> [<resource-name2> ...]
```

### Arguments

- `<deploy|sts>`: Specify whether the resources are Deployments (`deploy`) or StatefulSets (`sts`).
- `<namespace>`: The namespace where the resources are running.
- `<resource-name1>`: The name of the first StatefulSet or Deployment.
- `[<resource-name2> ...]`: (Optional) Additional names of StatefulSets or Deployments to capture logs from.

### Example

To capture logs from two StatefulSets (`mongodb`, `postgres`) in the `pe420` namespace:

```bash
./capture_logs.sh sts pe420 mongodb postgres
```

### Log Files

- The logs are captured for 10 minutes by default.
- After capturing, the logs are saved into a directory named `logs_<timestamp>`.
- The directory is compressed into a `logs.zip` file in the same directory where the script is executed.

### Handling Manual Interruptions

If the script is interrupted manually (e.g., with `Ctrl+C`), the logs captured until that point are still saved and compressed into the zip file.

### Example Output

```
Starting log capture for sts mongodb in pe420 for 10 minutes...
Starting log capture for sts postgres in pe420 for 10 minutes...
Log capture interrupted. Zipping collected logs so far...
Logs are saved and zipped at /path/to/logs.zip
```
