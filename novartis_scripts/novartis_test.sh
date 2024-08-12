#!/bin/bash

run_node_test=1
run_cluster_test=1

#function to print red text
error(){
    error=1
    # shellcheck disable=SC2145
    echo -e "\e[31m${@}\e[0m"
    if [ "$CONTINUE" = "no" ];then
        echo -e "\e[31mContinue is not set exiting on error!\e[0m"
       namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
       for ns in $namespaces;do
          kubectl --namespace=$ns delete ds net-test-all --ignore-not-found=true &>/dev/null
        done
        # THIS EXITS THE SCRIPT
        exit 1
    fi
}
#function to print yellow text
warn(){
    warn=1
    # shellcheck disable=SC2145
    echo -e "\e[93m${@}\e[0m"
}
good(){
    if [ ! "$QUIET" = "yes" ];then
        # shellcheck disable=SC2145
        echo -e "\e[32m${@}\e[0m"
    fi
}
helpfunction(){
    echo "Usage: $0"
    echo '--cluster                   Commence cluster specific checks.'
    echo '--node                      Commence node specific checks.'
    echo "--repository                Repository to check image pull. Ex. ghcr.io"
}

# deal with args
for i in "$@";do
    case $i in
        --node)
            script_args=" $script_args $1 "
            run_node_test=0
            run_cluster_test=1
            shift
        ;;
        --cluster)
            script_args=" $script_args $1 "
            run_cluster_test=0
            run_node_test=1
            shift
        ;;
        --repository)
            script_args=" $script_args $1 $2 "
            repository=$2
            shift
            shift
        ;;
        -h|--help)
            helpfunction
            exit 0
        ;;
    esac
done

node_test(){

    # Test if containerd directory exists
    if [ -d '/etc/containerd' ]; then
        good "/etc/containerd is correctly mounted."
    else
        warn "/etc/containerd is not mounted."
    fi

    # Test if docker directory exists
    if [ -d '/var/lib/docker' ]; then
        good "/var/lib/docker exists."
    else
        warn "/var/lib/docker does not exist."
    fi

    # Test for zk, kafka and mongodb directory exists
    dirs=("/app/nirmata/zk" "/app/nirmata/kafka" "/app/nirmata/mongodb")

    for dir in "${dirs[@]}"; do
        if [ -d $dir ]; then
            good "$dir is correctly mounted."
        else
            warn "$dir is not mounted."
        fi
    done

    # Test for Node Space Allocation (To be modified)
    paths="/var/nirmata"

    for path in $paths; do
        if df -h | grep -q "$path"; then
            space_used=$(df -h | grep "$path" | awk '{print $5}' | sed 's/%//')
            if [ "$space_used" -gt 50 ]; then
                warn "Space usage for $path is at $space_used%, which exceeds the 50% threshold."
            else
                good "Space allocation for $path is at $space_used%, which is within the 50% threshold."
            fi
        else
            warn "$path is not found."
        fi
    done

    # Test for repository access
    repository_url=$repository
    pullRes=$(docker pull "$repository_url" 2>&1)

    if [ $? -eq 0 ]; then
        good "Access to the repository is available and Docker can pull the image."
    else
        warn "Cannot access the repository or pull the image."
    fi

    # Test for docker proxy
    proxy_conf="/etc/systemd/system/docker.service.d/http-proxy.conf"

    if [ -f "$proxy_conf" ]; then
        good "Docker is configured to use the proxy."
    else
        warn "Docker proxy configuration not found."
    fi

}

cluster_test(){

    # Test if metrics service is enabled
    if kubectl get deployment -n kube-system metrics-server > /dev/null 2>&1; then
        good "Metric server is installed."
    else
        warn "Metric server is not installed."
    fi

    NAMESPACE="devtest5"

    # Get all deployments in the specified namespace
    deployments=$(kubectl get deployments -n "$NAMESPACE" -o json)

    # Check if there are any deployments
    if [[ $(echo "$deployments" | jq '.items | length') -eq 0 ]]; then
        echo "No deployments found in namespace $NAMESPACE."
        exit 0
    fi

    # Initialize a flag to track the status
    all_deployments_ok=true

    # Loop through each deployment
    echo "$deployments" | jq -c '.items[]' | while read -r deployment; do
        name=$(echo "$deployment" | jq -r '.metadata.name')
        desired_replicas=$(echo "$deployment" | jq -r '.spec.replicas')

        # Get the pods associated with the deployment
        pods=$(kubectl get pods -n "$NAMESPACE" -l app="$name" -o json)

        # Check if all pods are ready
        all_pods_ready=true
        echo "$pods" | jq -c '.items[]' | while read -r pod; do
            pod_name=$(echo "$pod" | jq -r '.metadata.name')
            pod_status=$(echo "$pod" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')

            if [[ "$pod_status" != "True" ]]; then
                echo "Pod $pod_name in deployment $name is not ready."
                all_pods_ready=false
            fi
        done

        if [[ "$all_pods_ready" == true ]]; then
            echo "All pods in deployment $name are ready."
        else
            all_deployments_ok=false
        fi
    done

    # Exit with a status based on the deployments' health
    if [ "$all_deployments_ok" = true ]; then
        good "All deployments in namespace $NAMESPACE are fully functional."
    else
        warn "Some deployments in namespace $NAMESPACE are not fully functional."
    fi

}

# Start the main script
if [[ $run_cluster_test -eq 0 ]];then
    cluster_test
fi

if [[ $run_node_test -eq 0 ]]; then
    node_test
fi