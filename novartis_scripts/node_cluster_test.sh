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
    paths=("/var/lib/docker" "/etc/containerd" "/app/nirmata")

    for path in "${paths[@]}"; do
    if df -h | grep -q "$path"; then
        good "Space allocation for $path:"
        df -h | grep "$path"
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

    # Test for nirmata services
       dns_error=0
    for ns in $namespaces;do
        echo Testing $ns namespace
    for pod in $(kubectl -n $ns get pods -l app=net-test-all-app --no-headers |grep Running |awk '{print $1}');do
        echo Testing "$(kubectl -n $ns get pods $pod -o wide --no-headers| awk '{print $7}') Namespace $ns"
        if  kubectl exec $pod -- nslookup $DNSTARGET 2>&1|grep -e can.t.resolve -e does.not.resolve -e can.t.find -e No.answer;then
            warn "Can not resolve external DNS name $DNSTARGET on $pod."
            kubectl -n $ns get pod $pod -o wide
            kubectl -n $ns exec $pod -- sh -c "nslookup $DNSTARGET"
            echo
        else
            good "DNS test $DNSTARGET on $pod suceeded."
        fi
        #kubectl -n $ns exec $pod -- nslookup $SERVICETARGET
        if kubectl -n $ns exec $pod -- nslookup $SERVICETARGET 2>&1|grep -e can.t.resolve -e does.not.resolve -e can.t.find -e No.answer;then
            warn "Can not resolve $SERVICETARGET service on $pod"
            echo 'Debugging info:'
            kubectl get pod $pod -o wide
            dns_error=1
            kubectl -n $ns exec $pod -- nslookup $DNSTARGET
            kubectl -n $ns exec $pod -- nslookup $SERVICETARGET
            kubectl -n $ns exec $pod -- cat /etc/resolv.conf
            error "DNS test failed to find $SERVICETARGET service on $pod"
        else
            good "DNS test $SERVICETARGET on $pod suceeded."
        fi
        if [[ $curl -eq 0 ]];then
             if [[ $http -eq 0 ]];then
                 if  kubectl -n $ns exec $pod -- sh -c "if curl --max-time 5 http://$SERVICETARGET; then exit 0; else exit 1; fi" 2>&1|grep -e 'command terminated with exit code 1';then
                     error "http://$SERVICETARGET failed to respond to curl in 5 seconds!"
                 else
                     good "HTTP test $SERVICETARGET on $pod suceeded."
                 fi
             else
                 if  kubectl -n $ns exec $pod -- sh -c "if curl --max-time 5 -k https://$SERVICETARGET; then exit 0; else exit 1; fi" 2>&1|grep -e 'command terminated with exit code 1';then
                     error "https://$SERVICETARGET failed to respond to curl in 5 seconds!"
                 else
                     good "HTTPS test $SERVICETARGET on $pod suceeded."
                 fi
             fi
        fi

    done
    done

}

# Start the main script
if [[ $run_cluster_test -eq 0 ]];then
    cluster_test
fi

if [[ $run_node_test -eq 0 ]]; then
    node_test
fi