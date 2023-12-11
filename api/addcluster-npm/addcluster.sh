#!/usr/bin/bash


if [[ $# = 0 ]]; then
        echo "Uage: $0 <cluster-name>"
        exit 1
fi

# cleanup files from previous runs

rm -f register-cluster.json controller.json nirmata-kube-controller-*.yaml

CLUSTERNAME=$1
TOKEN="<api-token>"
NIRMATAURL="https://nirmata.io"

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/cluster/api/txn" -d "
{
  \"create\": [
    {
      \"mode\": \"discovered\",
      \"name\": \"$CLUSTERNAME\",
      \"typeSelector\": \"default-policy-manager-type\",
      \"isKyvernoAutoInstall\": true,
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

if [[ $? = 0 ]]; then
        echo -e "\nCluster added to NPM successfully\n"
else
        echo -e "\nOops something went wrong. Please check!\n"
fi
