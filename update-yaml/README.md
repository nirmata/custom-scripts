READme for Kubernetes Pod Configuration Updater
Overview

This Bash script is designed to update the configuration of a Kubernetes pod by modifying a specified YAML file. It retrieves resource specifications (such as CPU and memory requests/limits) from an existing pod in the specified namespace and applies them to the provided YAML file. Additionally, it replaces specific image and version references in the file.


PREREQUISITES

Before using this script, ensure the following prerequisites are met:

    kubectl is installed and configured to connect to the target Kubernetes cluster.
    The script is executed with appropriate permissions to read pod details and modify the specified YAML file.


USAGE

./script.sh <yaml_file> <new_image> <pod_name>

Where
    <yaml_file>: Path to the YAML file that needs to be updated.
    <new_image>: The new container image reference.
    <pod_name>: Name of the existing pod in the Kubernetes cluster (in the specified namespace).


Script Actions

    Update Image Reference:
        Replaces image of "index.docker.io" in the YAML file with the provided <new_image>.

    Update Version Reference:
        Replaces version of "pe-3.5.4" in the YAML file with "4.3.1".

    Update CPU and Memory Specifications:
        Modifies the YAML file to set CPU and memory requests/limits based on the values obtained from the existing pod.




Note

    Ensure that the provided YAML file is properly formatted and adheres to the Kubernetes pod specification.
    This script is intended for updating simple pod configurations and may need modification for more complex scenarios.