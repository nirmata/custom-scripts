#!/bin/bash

file=$1
image=$2
pod_name=$3

new_request_memory=$(kubectl get pods "$pod_name" -n nirmata -o jsonpath='{.spec.containers[0].resources.requests.memory}')
new_cpu=$(kubectl get pods "$pod_name" -n nirmata -o jsonpath='{.spec.containers[0].resources.requests.cpu}')
new_limit_memory=$(kubectl get pods "$pod_name" -n nirmata -o jsonpath='{.spec.containers[0].resources.limits.memory}')

sed -i "s/index\.docker\.io/${image}/g" "$file"
sed -i 's/pe-3\.5\.4/4.3.1/g' "$file"

sed -i "/requests:/,/cpu:/ s/cpu:.*/cpu: ${new_cpu}/" $file
sed -i "/requests:/,/memory:/ s/memory:.*/memory: ${new_request_memory}/" $file
sed -i "/limits:/,/memory:/ s/memory:.*/memory: ${new_limit_memory}/" $file

echo "Done"