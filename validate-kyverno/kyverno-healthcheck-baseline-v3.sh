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


getkyvernoreplicas() {

# Define the namespace
NAMESPACE="$1"

# Get the list of deployments in the specified namespace
deployments=$(kubectl get deployments -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

# Loop through each deployment
for deployment in $deployments; do
  # Get the number of replicas for the current deployment
  replicas=$(kubectl get deployment $deployment -n $NAMESPACE -o jsonpath='{.spec.replicas}')

  # Print the deployment name and number of replicas
  #echo "- $deployment: $replicas"
  echo "- Deployment name: $deployment, No of replicas: $replicas"

  # Check if the deployment is kyverno or kyverno-admission-controller and if replicas are less than 3
  if [[ ($deployment == "kyverno" || $deployment == "kyverno-admission-controller") && $replicas -lt 3 ]]; then
    echo -e "\t- It is recommended to deploy $deployment in HA Mode with 3 or replicas"
  fi
done

}

getkyvernologs(){

# Specify the namespace
NAMESPACE="$1"

# Get the list of pods in the specified namespace
pods=$(kubectl get pods -n $NAMESPACE -o jsonpath='{.items[*].metadata.name}')

# Loop through each pod
for pod in $pods; do
  # Get the list of containers within the current pod
  containers=$(kubectl get pod $pod -n $NAMESPACE -o jsonpath='{.spec.containers[*].name}')

  # Loop through each container
  for container in $containers; do
    # Define the log file name
    log_file="kyverno/logs/${pod}-${container}.log"

    # Capture the logs and save them to the log file
    kubectl logs $pod -c $container -n $NAMESPACE > $log_file
  done
done



}

etcdmessage() {

if [[ $? != 0 ]]; then
    echo "Unable to fetch data. Please run \"kubectl get --raw /metrics\" and check if you get any output"
fi

}

report() {

k8s_version=$(kubectl version | grep "Server Version" | awk '{ print $NF }')
k8s_version_tmp=$(kubectl get nodes --no-headers | awk '{print $5}' | uniq | sed 's/v//g')
#k8s_version_tmp=$(kubectl get nodes --no-headers | awk '{print $5}' | uniq | sed 's/v//g' | awk -F'-' '{print $1}')
ky_deploy=$(kubectl get pods -n $KYVERNO_NAMESPACE --no-headers | grep -v cleanup | wc -l)


echo
echo "========================================="
echo "Current Kyverno Deployment Status        "
echo "========================================="
echo
echo "Kubernetes Version: $k8s_version"
echo
echo "Kyverno Deployment Version"
for i in $(kubectl get deploy -n $KYVERNO_NAMESPACE -o yaml | grep "image: " | awk -F/ '{ print $NF}' | grep -v "pre")
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

if [[ $awscount != *0 ]]; then
        cloudprovider="AWS"
elif [[ $azurecount != *0 ]]; then
        cloudprovider="Azure"
elif [[ $gkecount != *0 ]]; then
        cloudprovider="Google Cloud"
elif [[ $oraclecount != *0 ]]; then
        cloudprovider="Oracle"
else
        cloudprovider="Other"
fi

echo "Cloud Provider/Infrastructure: $cloudprovider"
#echo "---------------------------"
echo
echo "Total size of the etcd database file physically allocated in bytes:"
if [[ $k8s_version_tmp > 1.22.0 && $k8s_version_tmp < 1.26.0 ]]; then
        kubectl get --raw /metrics 2> /dev/null | grep "etcd_db_total_size_in_bytes" | grep -v "^#"
elif [[ $k8s_version_tmp > 1.26.0 && $k8s_version_tmp < 1.28.0 ]]; then
        kubectl get --raw /metrics 2> /dev/null | grep "apiserver_storage_db_total_size_in_bytes" | grep -v "^#"
elif [[ $k8s_version_tmp > 1.28.0 ]]; then
        kubectl get --raw /metrics 2> /dev/null | grep "apiserver_storage_size_bytes" | grep -v "^#"
else
        echo "Unable to fetch data. Please run \"kubectl get --raw /metrics\" and check if you get any output"
fi
etcdmessage
echo
echo "Top objects in etcd:"
#echo "---------------------------"
if [[ $k8s_version_tmp > 1.22.0 ]]; then
        kubectl get --raw=/metrics > /dev/null 2>&1
        if [[ $? != 0 ]]; then
                echo "Unable to fetch data. Please run \"kubectl get --raw /metrics\" and check if you get any output"
        else
                kubectl get --raw=/metrics 2> /dev/null | grep apiserver_storage_objects |awk '$2>100' |sort -g -k 2
        fi


else
        echo "- Objects in ETCD:"
        kubectl get --raw=/metrics > /dev/null 2>&1
        if [[ $? != 0 ]]; then
                echo "Unable to fetch data. Please run \"kubectl get --raw /metrics\" and check if you get any output"
        else
                kubectl get --raw=/metrics 2> /dev/null | grep etcd_object_counts |awk '$2>100' |sort -g -k 2
        fi
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
if [[ "$OSTYPE" == "darwin"* ]]; then
        du -sh * | sort -hr
else
        du -h --max-depth=0 * | sort -hr
fi

#du -h --max-depth=0 * | sort -hr

for res in $kobjects
do
        rm -rf $res
done

echo
no_of_kyreplicas=$(kubectl get pods -n $KYVERNO_NAMESPACE  --no-headers | egrep -v 'background-controller|cleanup-controller|reports-controller' | wc -l)
echo
echo "Kyverno Replicas:"
getkyvernoreplicas $KYVERNO_NAMESPACE
#echo "------------------------"
#echo "Kyverno Deployment Customization: ==============="
#echo "Kyverno Resource manifests ========================"
#echo "------------------------"
#echo "Kyverno Resource Review:"
#echo "------------------------"
echo
echo "Kyverno Pod status:"
#echo "-------------------"
kubectl get pods -n $KYVERNO_NAMESPACE
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
pdb_count=$(kubectl get pdb -n $KYVERNO_NAMESPACE 2> /dev/null | wc -l)
if [[ $pdb_count = 0 ]]; then
        echo "- No matching pdb found for Kyverno. It is recommended to deploy a pdb with minimum replica of 1"
else
        echo
        kubectl get pdb -n $KYVERNO_NAMESPACE
fi
echo
echo "System Namespaces excluded in webhook:"

kyvernocm=$(kubectl get cm -n kyverno --no-headers | awk '{ print $1 }' | grep "kyverno$")
if [[ ! -z ${kyvernocm} ]]; then

	for r in $(kubectl get configmap ${kyvernocm} -n $KYVERNO_NAMESPACE -o jsonpath='{.data.webhooks}' | jq -r '.namespaceSelector.matchExpressions[].values[]')
	do
        	echo "- $r"
	done
	echo
else
	echo "Kyverno configMap not found"
fi

#echo "-------------------------"
#echo "`kubectl get cm kyverno -oyaml -n $KYVERNO_NAMESPACE  | grep resourceFilters`"
#echo "-------------------------------------------"
echo "Memory and CPU consumption of Kyverno pods:"
#echo "-------------------------------------------"
metrics_count=$(kubectl get deploy metrics-server -n kube-system --no-headers 2> /dev/null | wc -l)
if [[ $metrics_count = 0 ]]; then
        echo " - Metrics server not installed. Cannot pull the memory and CPU consumption of Kyverno Pods"
else
kubectl top pods -n $KYVERNO_NAMESPACE
fi
echo
echo "Collecting the manifests for cluster policies,Kyverno deployments and ConfigMaps"
mkdir -p kyverno/{manifests,logs}

kubectl get deploy,svc,cm -n $KYVERNO_NAMESPACE -o yaml > kyverno/manifests/kyverno.yaml 2> /dev/null
kubectl get validatingwebhookconfigurations kyverno-policy-validating-webhook-cfg kyverno-resource-validating-webhook-cfg -o yaml > kyverno/manifests/validatingwebhooks.yaml 2> /dev/null
kubectl get mutatingwebhookconfigurations kyverno-policy-mutating-webhook-cfg kyverno-resource-mutating-webhook-cfg kyverno-verify-mutating-webhook-cfg -o yaml > kyverno/manifests/mutatingwebhooks.yaml 2> /dev/null
kubectl get cpol -o yaml > kyverno/manifests/cpols.yaml 2> /dev/null
kubectl get policyreport -A -o yaml > kyverno/manifests/policyreportyaml.yaml 2> /dev/null
#kubectl get policyreport -A kyverno/manifests/policyreport.yaml 2> /dev/null
#kubectl get crd -n $KYVERNO_NAMESPACE -o yaml kyverno/manifests/crd.yaml 2> /dev/null
kubectl get crd | egrep 'kyverno|wgp' > kyverno/manifests/crd.yaml 2> /dev/null

echo " - Manifests are collected in \"kyverno/manifests\" folder"
echo
echo "Collecting the logs for all the Kyverno pods"

getkyvernologs "$KYVERNO_NAMESPACE"

echo " - Logs are collected in \"kyverno/logs\" folder. The log file format is <pod-name>-<container-name>.log"

echo
echo "Verifying Kyverno Metrics"
if kubectl get svc kyverno-svc-metrics -n $KYVERNO_NAMESPACE >/dev/null 2>&1; then
        #metrics_port=$(kubectl get svc kyverno-svc-metrics -n $KYVERNO_NAMESPACE --no-headers | awk '{ print $5}')
        echo "- Kyverno Metrics are exposed on this cluster"
        echo
        kubectl get svc kyverno-svc-metrics -n $KYVERNO_NAMESPACE
else
        echo "- Kyverno Metrics are not exposed. It is recommended to expose Kyverno metrics!"
fi
echo
count=$(kubectl get cpol -o jsonpath='{range .items[*]}{.status.ready}{"\n"}{end}' | grep false | wc -l)
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
        echo -e "\nBaseline report \"baselinereport.tar\" generated successfully in the current directory under temp"
else
        echo -e "\nSomething went wrong generating the baseline report. Please check!"
fi


}
## main

#Check the operating system
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" ]]; then
  echo -e "\nScript cannot be run on a Windows machine. Exiting...\n"
  exit 1
fi


if [[ $# != 3 ]]; then
        echo -e "\nUsage: $0 <Servicemonitor name for Kyverno> <Prometheus EP (IP:PORT)> <KYVERNO-NAMESPACE>>"
        echo -e "\nExample: $0 service-monitor-kyverno-service 10.14.1.73:9090 kyverno"
        echo -e "\nNote: Please refer to the README if you are not sure where to find the Prometheus EP\n"
        exit 1
fi

KYSVCMONITOR=$1
prom_url=$2
KYVERNO_NAMESPACE=$3

mkdir temp 2> /dev/null
cd temp
rm -rf BaselineReport.txt kyverno baselinereport.tar 2> /dev/null

report 2>&1 | tee -a BaselineReport.txt

#read -p 'Enter name of the servicemonitor defined for Kyverno: ' KYSVCMONITOR
#echo

if kubectl get servicemonitor -A 2> /dev/null | grep $KYSVCMONITOR 1> /dev/null; then
            echo -e "---------------------------------------------------" | tee -a BaselineReport.txt
            echo  "Prometheus ServiceMonitor for Kyverno found!" | tee -a BaselineReport.txt
            echo -e "---------------------------------------------------\n" | tee -a BaselineReport.txt

            if [[ -z $prom_url ]]; then
                echo -e "Prometheus EP is null. Prometheus metrics for Kyverno will not be fetched!\n" | tee -a BaselineReport.txt
            fi

            curl -s http://$prom_url/api/v1/query?query=kyverno_policy_rule_info_total > /dev/null

            if [[ $? = 0 ]]; then
                    prometheusmetrics 2>&1 | tee -a BaselineReport.txt
                    tarreport
            else
                    echo -e "\nUnable to fetch Kyverno metrics from Prometheus EP provided. This could be due one of the following reasons\n- Prometheus endpoint provided could be wrong.\n- Prometheus endpoint could be unreachable for any reasons.\n- Misconfiguration in the Kyverno servicemonitor.\n\nPlease try to query the Kyverno metrics directly from Prometheus and confirm that servicemonitor is working correctly.\n" | tee -a BaselineReport.txt
                    tarreport
            fi

else
    echo "The servicemonitor provided does not exist. Prometheus metrics for Kyverno will not be fetched!" | tee -a BaselineReport.txt
    tarreport

fi
