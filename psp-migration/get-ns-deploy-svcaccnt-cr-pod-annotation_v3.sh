#!/usr/bin/bash

kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns='KIND:kind,NAMESPACE:metadata.namespace,NAME:metadata.name,SERVICE_ACCOUNTS:subjects[?(@.kind=="ServiceAccount")].name,ATTACHED_NS:subjects[?(@.kind=="ServiceAccount")].namespace,KIND:roleRef.kind,NAME:roleRef.name' | grep -v "SERVICE_ACCOUNTS" > abc


echo "------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf '%-40s %-40s %-40s %-20s %-60s %-40s %-40s %-40s %-40s %-40s\n' NAMESPACE APP SERVICEACCOUNT ATTACHED_NS BINDINGTYPE BINDINGNAME ROLETYPE ROLENAME PODNAME PSP_ANNOTATION_EXISTS
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
        tvar=""
        annotationexists=""

        namespace=$(echo $line | awk '{print $2}')
        svcaccount=$(echo $line | awk '{print $4}')
        bindingtype=$(echo $line | awk '{print $1}')
        bindingname=$(echo $line | awk '{print $3}')
        rtype=$(echo $line | awk '{print $6}')
        rname=$(echo $line | awk '{print $7}')
        attachedns=$(echo $line | awk '{print $5}')

        if [[ "$svcaccount" = "<none>" ]]; then
                app="any"
                tvar="NA"
                annotationexists="NA"
                printf '%-40s %-40s %-40s %-20s %-60s %-40s %-40s %-40s %-40s %-10s\n' $namespace $app $svcaccount $attachedns $bindingtype $bindingname $rtype $rname $tvar $annotationexists
        else

                app=$(kubectl get deployments,sts,ds,cronjob -n $namespace -o=jsonpath='{range .items[?(@.spec.template.spec.serviceAccountName=="'$svcaccount'")]}{.metadata.name}{"\n"}{end}')
                if [[ -z "$app" ]]; then
                        app="any"
                        tvar="NA"
                        annotationexists="NA"
                        printf '%-40s %-40s %-40s %-20s %-60s %-40s %-40s %-40s %-40s %-10s\n' $namespace $app $svcaccount $attachedns $bindingtype $bindingname $rtype $rname $tvar $annotationexists
                else
                        podname=""
                        podname=$(kubectl get pods -n $namespace -o custom-columns=NAME:.metadata.name --no-headers | grep "${app}-")
                        for tvar in $podname
                        do
                                annotation_value=$(kubectl get pod $tvar -n $namespace -o jsonpath='{.metadata.annotations.kubernetes\.io/psp}')
                                if [ -n "$annotation_value" ]; then
                                        annotationexists="Yes"
                                        printf '%-40s %-40s %-40s %-20s %-60s %-40s %-40s %-40s %-40s %-10s\n' $namespace $app $svcaccount $attachedns $bindingtype $bindingname $rtype $rname $tvar $annotationexists
                                else
                                        annotationexists="No"
                                        printf '%-40s %-40s %-40s %-20s %-60s %-40s %-40s %-40s %-40s %-10s\n' $namespace $app $svcaccount $attachedns $bindingtype $bindingname $rtype $rname $tvar $annotationexists
                                fi
                        done

                fi
        fi

done < abc
