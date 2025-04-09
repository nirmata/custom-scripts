#!/usr/bin/bash


kubectl get rolebindings,clusterrolebindings --all-namespaces -o custom-columns='KIND:kind,NAME:metadata.name,NAMESPACE:metadata.namespace,SERVICE_ACCOUNTS:subjects[?(@.kind=="ServiceAccount")].name,ATTACHED_NS:subjects[?(@.kind=="ServiceAccount")].namespace,KIND:roleRef.kind,NAME:roleRef.name,GROUP_NAME:subjects[?(@.kind=="Group")].name' | grep -v "SERVICE_ACCOUNTS" > abc


echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
printf '%-20s %-60s %-20s %-30s %-40s %-12s %-40s %-8s %-40s\n' NAMESPACE PODNAME PSP-ANNOTATION SERVICEACCOUNT ATTACHED_NS BINDINGTYPE BINDINGNAME ROLETYPE ROLENAME
echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"


while read -r line;
do
        svcaccount=""
        namespace=""
        bindingtype=""
        bindingname=""
        rtype=""
        rname=""

        namespace=$(echo $line | awk '{print $3}')
        svcaccount=$(echo $line | awk '{print $4}')
        bindingtype=$(echo $line | awk '{print $1}')
        bindingname=$(echo $line | awk '{print $2}')
        rtype=$(echo $line | awk '{print $6}')
        rname=$(echo $line | awk '{print $7}')
        attachedns=$(echo $line | awk '{print $5}')
        groupname=$(echo $line | awk '{print $8}')



        if [[ $bindingtype = RoleBinding ]]; then
                bindingtype="rb"
        else
                bindingtype="crb"
        fi

        if [[ $rtype = Role ]]; then
                rtype="r"
        else
                rtype="cr"
        fi


        if [[ "$svcaccount" = "<none>" ]] && [[ "$groupname" = "<none>" ]]; then
                continue
        elif [[ "$svcaccount" != "<none>" ]] && [[ "$groupname" = "<none>" ]]; then
                pods=$(kubectl get po -n $attachedns -o=jsonpath='{range .items[?(@.spec.serviceAccountName=="'$svcaccount'")]}{.metadata.name}{"\n"}{end}')
                for pod in $pods
                do

                    annotation_value=$(kubectl get pod $pod -n $attachedns -o jsonpath='{.metadata.annotations.kubernetes\.io/psp}')
                    annotation="${annotation_value:-NA}"
                    attachedns_tmp="${attachedns:-NA}"

                    printf '%-20s %-60s %-20s %-30s %-40s %-12s %-40s %-8s %-40s\n' $namespace $pod $annotation $svcaccount $attachedns_tmp $bindingtype $bindingname $rtype $rname

                done
        elif [[ "$svcaccount" = "<none>" ]] && [[ "$groupname" != "<none>" ]]; then
                #continue

                temppods=""
                tempns=$(echo "$groupname" | grep "system:serviceaccounts:" | awk -F: '{ print $NF}')

                if [[ ! -z $tempns ]]; then
                    for svct in $(kubectl get sa -n $tempns -o custom-columns=NAME:.metadata.name --no-headers); do
                            temppods=$(kubectl get po -n $tempns -o=jsonpath='{range .items[?(@.spec.serviceAccountName=="'$svct'")]}{.metadata.name}{"\n"}{end}')
                            for temppod in $temppods
                            do
                                    annotation_value=$(kubectl get pod $temppod -n $tempns -o jsonpath='{.metadata.annotations.kubernetes\.io/psp}')
                                    annotation="${annotation_value:-NA}"
                                    attachedns_tmp="${attachedns:-NA}"

                                    printf '%-20s %-60s %-20s %-30s %-40s %-12s %-40s %-8s %-40s\n' $namespace $temppod $annotation $svct $attachedns_tmp $bindingtype $bindingname $rtype $rname
                            done
                    done
                else
                        continue
                fi
        fi


done < abc

        echo
        echo "-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------"
        echo
