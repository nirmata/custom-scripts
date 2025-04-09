#!/bin/bash

kubectl get pods -A -o jsonpath="{range .items[*]}{.metadata.namespace}{'\t'}{.metadata.name}{'\t'}{.spec.serviceAccount}{'\t'}{.metadata.annotations.openshift\.io\/scc}{'\n'}" | sed '/^[[:space:]]*$/d' > list

echo
echo "--------------------------------------------------------------------------------------------------------------------------------"
printf '%-25s %-45s %-35s %-35s %-35s %-35s %-35s\n' NAMESPACE POD_NAME SERVICEACCOUNT SECURITY_CONTEXT_CONSTRAINT
echo "--------------------------------------------------------------------------------------------------------------------------------"

while read -r line;
do
        namespace=""
        podname=""
        svcaccount=""
        scc=""
        namespace=$(echo $line | awk '{print $1}')
        svcaccount=$(echo $line | awk '{print $3}')
        podname=$(echo $line | awk '{print $2}')
        scc=$(echo $line | awk '{print $4}')

        if [[ -z $svcaccount ]]; then
                svcaccount=default
        fi
        printf '%-40s %-45s %-45s %-45s %-45s %-345s %-45s\n' $namespace $podname $svcaccount $scc


done < list

echo "--------------------------------------------------------------------------------------------------------------------------------"
echo
