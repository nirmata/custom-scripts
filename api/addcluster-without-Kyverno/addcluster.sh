#!/usr/bin/bash


if [[ $# != 2 ]]; then
        echo -e "\nUsage: $0 <cluster-name> <Nirmata-URL>\n"
        exit 1
fi

CLUSTERNAME=$1
NIRMATAURL="$2"

echo -e "\nEnter the Nirmata API token: \n"
read -s TOKEN

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/cluster/api/txn" -d "
{
  \"create\": [
    {
      \"mode\": \"discovered\",
      \"name\": \"$CLUSTERNAME\",
      \"typeSelector\": \"default-policy-manager-type\",
      \"isKyvernoAutoInstall\": false,
      \"isKyvernoExist\": true,
      \"modelIndex\": \"KubernetesCluster\",
      \"config\": [
        {
          \"endpoint\": \"\",
          \"cloudProvider\": \"Other\",
          \"modelIndex\": \"ClusterConfig\",
          \"overrideValues\": null
        }
      ],
      \"accessControlList\": [
        {
          \"modelIndex\": \"AccessControlList\"
        }
      ]
    }
  ],
  \"update\": [],
  \"delete\": []
}" | jq . > register-cluster.json

CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" 2>&1 | jq ".[] | select( .name == \"$CLUSTERNAME\" ).id" | sed "s/\"//g")
#echo $CLUSTERID

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster/$CLUSTERID/yaml" | jq '."nirmata-kube-controller.yaml"' > controller.json
yq -P '.' controller.json > nirmata-kube-controller-$CLUSTERNAME.yaml
#cat nirmata-kube-controller-$CLUSTERNAME.yaml

kubectl apply -f nirmata-kube-controller-$CLUSTERNAME.yaml 1> /dev/null
kubectl apply -f nirmata-kube-controller-$CLUSTERNAME.yaml 1> /dev/null

sleep 20

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/cluster/api/KubernetesCluster/$CLUSTERID/kyverno-addon" 1> /dev/null
