#!/bin/bash

urlencode() {
    # urlencode <string>
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}



report() {

k8s_version=$(kubectl get nodes --no-headers | awk '{print $5}' | uniq)
k8s_version_tmp=$(kubectl get nodes --no-headers | awk '{print $5}' | uniq | sed 's/v//g')
ky_deploy=$(kubectl get pods -n kyverno --no-headers | grep -v cleanup | wc -l)


echo
echo "========================================="
echo "Current Kyverno Deployment Status        "
echo "========================================="
echo
echo "Kubernetes Version: $k8s_version"
echo
echo "Kyverno Deployment Version"
#echo "--------------------------"
for i in $(kubectl get deploy -n kyverno -o yaml | grep "image: " | awk -F/ '{ print $NF}')
do
        echo " - $i"
done
echo
echo "Cluster Size Details"
echo " - Number of Nodes in the Cluster: $(kubectl get nodes --no-headers | wc -l)"
echo " - Number of Pods in the Cluster: $(kubectl get pods -A --no-headers | wc -l)"
echo
echo "Total Number of Kyverno ClusterPolicies in the Cluster: $(kubectl get cpol --no-headers 2> /dev/null | wc -l)"

awscount=$(kubectl get nodes --show-labels | awk '{ print $6 }' | grep -i aws | wc -l)
azurecount=$(kubectl get nodes --show-labels | awk '{ print $6 }' | grep -i azure | wc -l)
gkecount=$(kubectl get nodes --show-labels | awk '{ print $6 }' | grep -i gke | wc -l)
oraclecount=$(kubectl get nodes --show-labels | awk '{ print $6 }' | grep -i compartment | wc -l)

cloudprovider=""

if [[ $awscount != 0 ]]; then
        cloudprovider="AWS"
elif [[ $azurecount != 0 ]]; then
        cloudprovider="Azure"
elif [[ $gkecount != 0 ]]; then
        cloudprovider="Google Cloud"
elif [[ $oraclecount != 0 ]]; then
        cloudprovider="Oracle"
else
        cloudprovider="Other"
fi

echo "Cloud Provider/Infrastructure: $cloudprovider"
#echo "---------------------------"
echo
echo "Total size of the etcd database file physically allocated in bytes:"
kubectl get --raw /metrics 2> /dev/null | grep "etcd_db_total_size_in_bytes" | grep -v "^#"
echo
echo "Top objects in etcd:"
#echo "---------------------------"
if [[ $k8s_version_tmp > 1.22.0 ]]; then
        # echo " - Objects in ETCD:"
        # for k in $()
        kubectl get --raw=/metrics 2> /dev/null | grep apiserver_storage_objects |awk '$2>100' |sort -g -k 2
        #do
        #       echo "   - $k"
        #done
else
        echo "- Objects in ETCD:"
        #for p in $()
        kubectl get --raw=/metrics 2> /dev/null | grep etcd_object_counts |awk '$2>100' |sort -g -k 2
        #do
        #       echo "   - $p"
        #done
fi

kobjects=$(kubectl api-resources --no-headers | awk '{ print $1}' | sort | uniq)
echo
echo "Fetching object sizes of individual kubernetes objects. This may be take few minutes"
echo
for res in $kobjects
do
        mkdir $res 2> /dev/null
        kubectl get $res -A 2> /dev/null -o yaml > $res/$res.yaml
done
echo "-----------------------------------------"
echo " Individual object Sizes in etcd:        "
echo "-----------------------------------------"

du -h --max-depth=0 * | sort -hr

for res in $kobjects
do
        rm -rf $res
done

#echo
no_of_kyreplicas=$(kubectl get pods -n kyverno  --no-headers | egrep -v 'background-controller|cleanup-controller|reports-controller' | wc -l)
echo
echo "Kyverno Replicas:"
if [[ $no_of_kyreplicas -lt 3 ]]; then
        echo " - $no_of_kyreplicas replica of Kyverno found. It is recommended to deploy kyverno in HA Mode with 3 replicas"
else
        echo " - $no_of_kyreplicas replicas of Kyverno found"
fi
#echo "------------------------"
#echo "Kyverno Deployment Customization: ==============="
#echo "Kyverno Resource manifests ========================"
#echo "------------------------"
#echo "Kyverno Resource Review:"
#echo "------------------------"
echo
echo "Kyverno Pod status:"
#echo "-------------------"
kubectl get pods -n kyverno
echo
echo "Kyverno CRD's:"
for u in $(kubectl get crd | egrep 'ky|wgp' | awk '{ print $1}')
do
        echo " - $u"
done
echo
#echo "Kyverno Admission Webhooks:"
#echo "---------------------------"
echo "Kyverno ValidatingWebhook Deployed: "
for k in $(kubectl get validatingwebhookconfigurations | grep ky | awk '{ print $1}'); do echo " - $k";done
echo
echo "Kyverno MutatingWebhooks Deployed: "
for t in $(kubectl get mutatingwebhookconfigurations | grep ky | awk '{ print $1}'); do echo " - $t";done

for kycrd in $(kubectl get crd | egrep 'ky|wgp' | awk '{ print $1 }' | cut -d "." -f1)
do
        echo -e "\nFetching \"$kycrd\" for the cluster\n"; kubectl get $kycrd -A
done
echo
echo "Pod Disruption Budget Deployed:"
pdb_count=$(kubectl get pdb -n kyverno 2> /dev/null | wc -l)
if [[ $pdb_count = 0 ]]; then
        echo "- No matching pdb found for Kyverno. It is recommended to deploy a pdb with minimum replica of 1"
else
        echo
        kubectl get pdb -n kyverno
fi
echo
echo "System Namespaces excluded in webhook"
for r in $(kubectl get cm -n kyverno kyverno -o yaml | grep webhooks: | awk -F ":" '{ print $NF}' | tr -d "[]}'" | tr "," "\n")
do
        echo "- $r"
done
echo

#echo "-------------------------"
#echo "`kubectl get cm kyverno -oyaml -n kyverno  | grep resourceFilters`"
#echo "-------------------------------------------"
echo "Memory and CPU consumption of Kyverno pods:"
#echo "-------------------------------------------"
metrics_count=$(kubectl get deploy metrics-server -n kube-system --no-headers 2> /dev/null | wc -l)
if [[ $metrics_count = 0 ]]; then
        echo " - Metrics server not installed. Cannot pull the memory and CPU consumption of Kyverno Pods"
else
kubectl top pods -n kyverno
fi
echo
echo "Collecting the manifests for cluster policies,Kyverno deployments and ConfigMaps"
mkdir -p kyverno/{manifests,logs}

kubectl get deploy,svc,cm -n kyverno -o yaml > kyverno/manifests/kyverno.yaml 2> /dev/null
kubectl get validatingwebhookconfigurations kyverno-policy-validating-webhook-cfg kyverno-resource-validating-webhook-cfg -o yaml > kyverno/manifests/validatingwebhooks.yaml 2> /dev/null
kubectl get mutatingwebhookconfigurations kyverno-policy-mutating-webhook-cfg kyverno-resource-mutating-webhook-cfg kyverno-verify-mutating-webhook-cfg -o yaml > kyverno/manifests/mutatingwebhooks.yaml 2> /dev/null
kubectl get cpol -o yaml > kyverno/manifests/cpols.yaml 2> /dev/null
kubectl get policyreport -A -o yaml kyverno/manifests/policyreportyaml.yaml 2> /dev/null
kubectl get policyreport -A kyverno/manifests/policyreport.yaml 2> /dev/null
kubectl get crd -n kyverno -o yaml kyverno/manifests/crd.yaml 2> /dev/null

echo " - Manifests are collected in \"kyverno/manifests\" folder"
echo
echo "Collecting the logs for all the Kyverno pods"

for ipod in $(kubectl get pods -n kyverno --no-headers | egrep -v 'background-controller|cleanup-controller|reports-controller'| awk '{ print $1}'); do kubectl logs $ipod -c kyverno -n kyverno > kyverno/logs/$ipod.log;done
echo " - Logs are collected in \"kyverno/logs\" folder"

echo
echo "Verifying Kyverno Metrics"
if kubectl get svc kyverno-svc-metrics -n kyverno >/dev/null 2>&1; then
        #metrics_port=$(kubectl get svc kyverno-svc-metrics -n kyverno --no-headers | awk '{ print $5}')
        echo "- Kyverno Metrics are exposed on this cluster"
        echo
        kubectl get svc kyverno-svc-metrics -n kyverno
else
        echo "- Kyverno Metrics are not exposed. It is recommended to expose Kyverno metrics!"
fi
echo
count=$(kubectl get cpol 2> /dev/null| awk '{ print $1,$4}' | egrep -v 'true|NAME ACTION' | awk '{ print $1 }' | wc -l)
echo "No of Policies in \"Not Ready\" State: $count"
echo

}

prometheusmetrics() {

query1="sum(increase(kyverno_admission_requests_total{}[24h]))"
query2="sum(kyverno_admission_requests_total{resource_request_operation=\"create\"})/sum(kyverno_admission_requests_total{})"

query1_encoded=$(urlencode $query1)

query1_tmp=$(curl -s "http://$prom_url/api/v1/query?query=$query1_encoded" | jq -r ".data.result[].value[1]" | cut -d "." -f 1)

echo
echo -e "Total admission requests triggered in the last 24h:  $query1_tmp\n"

query2_encoded=$(urlencode $query2)

query2_tmp=$(curl -s "http://$prom_url/api/v1/query?query=$query2_encoded" | jq -r ".data.result[].value[1]")

echo -e "Percentage of total incoming admission requests corresponding to resource creations:  $query2_tmp"

echo -e "\nScraping Policies and Rule Counts from Prometheus"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_policy_rule_info_total | jq .
echo -e "\nScraping Policy and Rule Execution from Prometheus"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_policy_results_total | jq .
echo -e "\nScraping Policy Rule Execution Latency from Prometheus"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_policy_execution_duration_seconds  | jq .
echo -e "\nScraping Admission Review Latency from Prometheus"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_admission_review_duration_seconds | jq .
echo -e "\nScraping Admission Requests Counts from Prometheus"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_admission_requests_total | jq .
echo -e "\nScraping Policy Change Counts from Prometheus"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_policy_changes_total | jq .
echo -e "\nScraping Client Queries from Prometheus\n"
echo
curl -s http://$prom_url/api/v1/query?query=kyverno_client_queries_total | jq .
echo -e "\nAll the raw Kyverno data scraped above is dumped in BaselineReport.txt"

}


tarreport() {

tar -cvf baselinereport.tar BaselineReport.txt kyverno 1> /dev/null
if [[ $? = 0 ]]; then
        echo -e "\nBaseline report \"baselinereport.tar\" generated successfully in the current directory"
else
        echo -e "\nSomething went wrong generating the baseline report. Please check!"
fi


}
## main

rm -rf BaselineReport.txt kyverno baselinereport.tar

#Check the operating system
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  echo -e "\nScript cannot be run on a Windows machine. Exiting...\n"
  exit 1
fi

report 2>&1 | tee -a BaselineReport.txt

read -p 'Enter name of the servicemonitor defined for Kyverno: ' KYSVCMONITOR
echo

if kubectl get servicemonitor -A 2> /dev/null | grep $KYSVCMONITOR 1> /dev/null; then
    tmp1=$(kubectl get servicemonitor -A | awk -v KYSVCMONITOR="$KYSVCMONITOR" '$0 ~ KYSVCMONITOR { system("kubectl describe servicemonitor " $2 " -n " $1) }' | grep -A5 "Match Labels:" | grep "app.kubernetes.io\/name:" | grep kyverno | awk '{ print $NF }')
    #echo "tmp1: $tmp1"
    tmp2=$(kubectl get servicemonitor -A | awk -v KYSVCMONITOR="$KYSVCMONITOR" '$0 ~ KYSVCMONITOR { system("kubectl describe servicemonitor " $2 " -n " $1) }' | grep -A1 "Match Names:" | tail -1 | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    #echo "tmp2: $tmp2"

    if [[ $tmp1 = kyverno ]] && [[ $tmp2 = kyverno ]]; then
            echo -e "\n---------------------------------------------------" | tee -a BaselineReport.txt
            echo  "Prometheus ServiceMonitor for Kyverno found!" | tee -a BaselineReport.txt
            echo -e "---------------------------------------------------\n" | tee -a BaselineReport.txt
            read -p 'Enter the endpoint for Promtheus (IP:PORT): ' prom_url
            echo

            if [[ -z $prom_url ]]; then
                echo -e "Prometheus EP is null. Prometheus metrics for Kyverno will not be fetched!\n" | tee -a BaselineReport.txt
            fi

            curl -s http://$prom_url/api/v1/query?query=kyverno_policy_rule_info_total > /dev/null

            if [[ $? = 0 ]]; then
                    prometheusmetrics 2>&1 | tee -a BaselineReport.txt
                    tarreport
            else
                    echo "Prometheus EP is unreachable or incorrect. Prometheus metrics for Kyverno will not be fetched!\n"
                    tarreport
            fi

    else
            echo -e "\n---------------------------------------------------" | tee -a BaselineReport.txt
            echo -e "Prometheus ServiceMonitor for Kyverno not found or \nincorrectly configured! Please verify and try again" | tee -a BaselineReport.txt
            echo -e "---------------------------------------------------\n" | tee -a BaselineReport.txt
    fi
else
    echo "The servicemonitor provided does not exist. Prometheus metrics for Kyverno will not be fetched!" | tee -a BaselineReport.txt
    tarreport

fi
