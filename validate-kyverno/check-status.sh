#!/bin/bash

report() {

k8s_version=$(kubectl get nodes --no-headers | awk '{print $5}' | uniq)
k8s_version_tmp=$(kubectl get nodes --no-headers | awk '{print $5}' | uniq | sed 's/v//g')
ky_deploy=$(kubectl get pods -n kyverno --no-headers | grep -v cleanup | wc -l)


echo
echo "========================================="
echo "Current Kyverno Deployment Status        "
echo "========================================="
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
echo
no_of_kyreplicas=$(kubectl get pods -n kyverno  --no-headers | egrep -v 'background-controller|cleanup-controller|reports-controller' | wc -l)
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

echo " - Manifests are collected in \"kyverno/manifests\" folder"
echo
echo "Collecting the logs for all the Kyverno pods"

for ipod in $(kubectl get pods -n kyverno --no-headers | awk '{ print $1}'); do kubectl logs $ipod -n kyverno > kyverno/logs/$ipod.log;done
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
}

rm -rf BaselineReport.txt kyverno
report 2>&1 | tee -a BaselineReport.txt

tar -cvf baselinereport.tar BaselineReport.txt kyverno 1> /dev/null
if [[ $? = 0 ]]; then
        echo -e "\nBaseline report \"baselinereport.tar\" generated successfully in the current directory"
else
        echo -e "\nSomething went wrong generating the baseline report. Please check!"
fi
