Log Capture Script
This script captures logs from all pods associated with a Kubernetes Deployment or StatefulSet for a specified duration (default: 10 minutes). The logs are saved into a directory and compressed into a ZIP file in the current working directory. The script also handles manual interruption and zips the logs on cancellation.

Prerequisites
A working Kubernetes cluster with kubectl configured to interact with it.
Bash shell (default on most Linux and macOS environments).
Permissions to access the Kubernetes cluster and view pod logs.
Usage
Download the script: Download the capture_logs.sh script from the repository or create it manually using the script provided below.

Make the script executable: After downloading or creating the script, make it executable:

bash
Copy code
chmod +x capture_logs.sh
Run the script: Run the script using the following format:

bash
Copy code
./capture_logs.sh <resource-type> <resource-name> <namespace>
Arguments:

Resource Type: Specify either deploy for Deployment or sts for StatefulSet.
Resource Name: The name of the Deployment or StatefulSet to capture logs from.
Namespace: The namespace where the resource is deployed.
Example
bash
Copy code
./capture_logs.sh sts mongodb pe420
In this example, logs will be captured for all pods associated with the mongodb StatefulSet in the pe420 namespace for 10 minutes. If manually interrupted (Ctrl+C), the script will still create a ZIP file containing the logs.

Output
Logs are saved in the current working directory in a folder named ${resource_name}_logs/.
Logs are compressed into a ZIP file stored at ${resource_name}_logs.zip in the current working directory.
Handling Interruptions
If the log capture is interrupted manually (e.g., pressing Ctrl+C), the script automatically stops and zips any logs collected up to that point.


