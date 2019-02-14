#!/bin/bash
# Nirmata Host Verifier

output=$(sestatus | grep "Current mode" 2>&1)

    if [[ $output == *"permissive"* || *"disabled"* ]]; then
         echo "SELinux disabled!"
    else
         echo WARNING:SELinux enabled.
    fi

output=$(cat /prox/swaps 2>&1)

    if [[ $output == *"partition"* ]]; then
         echo "WARNING:swap enabled. Please disable swap ($swapoff -a)"
    else
         echo swap disabled!
    fi


output=$(docker info 2>&1)

    if [[ $output == *"Containers"* ]]; then
         echo docker installed!
    else
         echo WARNING:docker not installed.
    fi

    if [[ $output == *"is not a mountpoint"* ]]; then
         echo WARNING:Docker does not have its own mountpoint
    else
         echo Docker has it own mounpoint!
    fi

output=$(cat /etc/systemd/system/docker.service.d/http-proxy.conf 2>&1 | grep proxy)

    if [[ $output == *"proxy"* || *"PROXY"* ]]; then
         echo Docker proxy configured
    else
         echo docker proxy not configured.
    fi

    
    if [[ $output == *"WARNING: bridge-nf-call-iptables is disabled"* ]]; then
         echo "WARNING:bridge-nf-call-iptables is disabled ($sysctl net.bridge.bridge-nf-call-iptables=1)"
    else 
         echo "net.bridge.bridge-nf-call-iptables=1"
    fi

output=$(export | grep 'http_proxy\|https_proxy\|no_proxy' 2>&1)

    if [[ $output == *"proxy"* ]]; then
         echo proxy configured.
    else
         echo not proxy configured.
    fi

output=$(cat */etc/docker/daemon.json 2>&1 | grep "log-driver")

    if [[ $output == *"log-driver"* ]]; then
         echo log rotation configured!
    else
         echo WARNING:log rotation not configured. configure log rotation
    fi

output=$(ls -al /opt/cni/bin/ 2>&1 | grep "bridge")

    if [[ $output == *"bridge"* ]]; then
         echo CNI installed!
    else
         echo WARNING:CNI not installed. Kubernetes networking may not work properly. 
    fi

output=$(systemctl status kubelet 2>&1)

    if [[ $output == *"kubelet1.service could not be found"* ]]; then
         echo WARNING:kubelet not found

    elif [[ $output == *"255"* ]]; then
         echo WARNING:kubelet inactive
    else 
         echo kubelet Active!

    fi 
