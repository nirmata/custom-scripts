#!/usr/bin/bash

kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns='KIND:kind,NAMESPACE:metadata.namespace,NAME:metadata.name,SERVICE_ACCOUNTS:subjects[?(@.kind=="ServiceAccount")].name,ATTACHED_NS:subjects[?(@.kind=="ServiceAccount")].namespace,KIND:roleRef.kind,NAME:roleRef.name' | grep -v "SERVICE_ACCOUNTS" > abc


echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf '%-40s %-40s %-40s %-20s %-60s %-12s %-40s\n' NAMESPACE APP SERVICEACCOUNT ATTACHED_NS BINDINGTYPE BINDINGNAME ROLETYPE ROLENAME
echo "---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"


while read -r line;
do
        svcaccount=""
        app=""
        namespace=""
        bindingtype=""
        bindingname=""
        rtype=""
        rname=""
        attachecns=""

        namespace=$(echo $line | awk '{print $2}')
        svcaccount=$(echo $line | awk '{print $4}')
        bindingtype=$(echo $line | awk '{print $1}')
        bindingname=$(echo $line | awk '{print $3}')
        rtype=$(echo $line | awk '{print $6}')
        rname=$(echo $line | awk '{print $7}')
        attachedns=$(echo $line | awk '{print $5}')

        if [[ "$svcaccount" = "<none>" ]]; then
                app="any"
        else
                app=$(kubectl get deployments,sts,ds,cronjob -n $namespace -o=jsonpath='{range .items[?(@.spec.template.spec.serviceAccountName=="'$svcaccount'")]}{.metadata.name}{"\n"}{end}')
                if [[ -z "$app" ]]; then
                        app="any"
                fi
        fi
        printf '%-40s %-40s %-40s %-20s %-60s %-12s %-40s\n' $namespace $app $svcaccount $attachedns $bindingtype $bindingname $rtype $rname

done < abc
