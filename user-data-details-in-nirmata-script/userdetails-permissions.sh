#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: <script> <Nirmata-API-Token> <NirmataURL>"
	echo ""
	echo "Eg: <script> <Nirmata-API-Token> https://www.nirmata.io"
else
	TOKEN=$1
	NIRMATAURL=$2
	echo "====================="
	echo "Fetching User Details"
	echo "====================="
	curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/User?fields=id,name,email" | jq -r '.[] | "Username: \(.name)\nEmail: \(.email)"' > user_details.txt
	cat user_details.txt
	echo "=============================================================================="	
	echo "Fetching Cluster and Environment Permissions for the DevOps and Platform Users" 
	echo "=============================================================================="
	curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/user?fields=id,name,role" | jq -r '.[] | select(.role == "devops" or .role == "platform").id' > cluster_aclids.txt
	for claclid in $(cat cluster_aclids.txt)
        do
		curl -s --location 'https://nirmata.io/cluster/api/entityPermissions?entityType=user&entityId='"$claclid"'' --header "Authorization: NIRMATA-API $TOKEN" | jq -r '.permissions | "username: \(.entityName)\n" + (.clusters[] | "clustername: \(.clusterName)\ncluster permission: \(.clusterPermission)\nEnvironment name: \(.environments[].environmentName)\nenvironment permission: \(.environments[].environmentPermission)\n")'
	done
fi
	
