#!/usr/bin/bash

TOKEN="<api-token>"
NIRMATAURL="https://nirmata.io"

POLICYSET_NAME=$1
CLUSTERNAME=$2


usage() {

        echo -e "\nUsage: $0 <policyset-name> <cluster-name>"
        echo -e "\n***** POLICYSETS DEPLOYED ***** \n"
        curl -s -X OPTIONS -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/PolicyGroup?fields=name" | jq .[].name | sed "s/\"//g"
        echo  -e "\n****** CLUSTERS INSTALLED *****\n"
        curl -s -X OPTIONS -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=name" | jq .[].name | sed "s/\"//g"
	echo
}

if [[ $# = 0 ]]; then
        usage
        exit 0
fi

CLUSTER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" 2>&1 | jq ".[] | select( .name == \"$CLUSTERNAME\" ).id" | sed "s/\"//g")

#echo $CLUSTER_ID

POLICYSET_ID=$(curl -s -X OPTIONS -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/PolicyGroup?fields=id,name" | jq ".[] | select( .name == \"$POLICYSET_NAME\" ).id" | sed "s/\"//g")

#echo $POLICYSET_ID

if [[ -z $POLICYSET_ID ]] || [[ -z $CLUSTER_ID ]]; then
        echo -e "\nThe policySet name or the Cluster name is not correct"
        exit 1
fi

curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/cluster/api/txn" -d "
{
  \"create\": [
    {
      \"parent\": \"$POLICYSET_ID\",
      \"modelIndex\": \"PolicyGroupCluster\",
      \"name\": \"$CLUSTERNAME\",
      \"clusterRef\": {
        \"service\": \"Cluster\",
        \"modelIndex\": \"KubernetesCluster\",
        \"id\": \"$CLUSTER_ID\"
      }
    }
  ],
  \"update\": [],
  \"delete\": []
}"
if [[ $? = 0 ]]; then
        echo -e "\nPolicySet '$POLICYSET_NAME' was deployed successfully on '$CLUSTERNAME'"
else
        echo -e "\nSomething went wrong. Please check!"
fi
