#!/bin/bash

kubectl get deployment -A -o jsonpath="{range .items[*]}{.metadata.namespace}{'\t'}{.metadata.name}{'\t'}{.spec.template.spec.serviceAccount}{'\n'}{end}" > deploy-serva
kubectl get sts -A -o jsonpath="{range .items[*]}{.metadata.namespace}{'\t'}{.metadata.name}{'\t'}{.spec.template.spec.serviceAccount}{'\n'}{end}" >> deploy-serva
kubectl get ds -A -o jsonpath="{range .items[*]}{.metadata.namespace}{'\t'}{.metadata.name}{'\t'}{.spec.template.spec.serviceAccount}{'\n'}{end}" >> deploy-serva
kubectl get cronjob -A -o jsonpath="{range .items[*]}{.metadata.namespace}{'\t'}{.metadata.name}{'\t'}{.spec.template.spec.serviceAccount}{'\n'}{end}" >> deploy-serva
echo
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
printf '%-40s %-40s %-40s %-40s\n' NAMESPACE APP SERVICEACCOUNT CLUSTERROLE
echo "------------------------------------------------------------------------------------------------------------------------------------------------------"

while read -r line;
do
        svcaccount=""
        deployment=""
        clusterrole=""
        namespace=""
        namespace=$(echo $line | awk '{print $1}')
        svcaccount=$(echo $line | awk '{print $3}')
        deployment=$(echo $line | awk '{print $2}')
        if [[ -z $svcaccount ]]; then
                continue
        fi
        #clusterrole=$(kubectl get clusterrolebinding --all-namespaces -o jsonpath='{range .items[?(@.subjects[0].name=="'$svcaccount'")]}[{.subjects[0].kind},{.subjects[0].name},{.roleRef.kind},{.roleRef.name}]{end}' | cut -d "," -f 4 | sed 's/]//g')
        clusterrole=$(kubectl get clusterrolebinding --all-namespaces -o jsonpath='{range .items[?(@.subjects[0].name=="'$svcaccount'")]}[{.roleRef.name}]{end}' | tr '][' '\n' | sed '/^$/d')
        for cr in $clusterrole
        do
            printf '%-40s %-40s %-40s %-40s\n' $namespace $deployment $svcaccount $cr
        done
done < deploy-serva

echo "------------------------------------------------------------------------------------------------------------------------------------------------------"
echo
