#!/bin/bash

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
echo "Top objects in etcd"
#echo "---------------------------"
if [[ $k8s_version_tmp > 1.22.0 ]]; then
        # echo " - Objects in ETCD:"
        # for k in $()
        kubectl get --raw=/metrics | grep apiserver_storage_objects |awk '$2>100' |sort -g -k 2
        #do
        #       echo "   - $k"
        #done
else
        echo "- Objects in ETCD:"
        #for p in $()
        kubectl get --raw=/metrics | grep etcd_object_counts |awk '$2>100' |sort -g -k 2
        #do
        #       echo "   - $p"
        #done
fi
echo
no_of_kyreplicas=$(kubectl get pods -n kyverno --no-headers | grep -v cleanup | wc -l)

if [[ $no_of_kyreplicas -lt 3 ]]; then
        echo "$no_of_kyreplicas replicas of Kyverno found. It is recommended to deploy kyverno in HA Mode with 3 replicas"
else
        echo "No of Kyverno replicas: $no_of_kyreplicas"
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
echo "$(kubectl top pods -n kyverno)"
echo
