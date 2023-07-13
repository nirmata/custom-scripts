#!/bin/bash

if [ $# -lt 2 ]; then
	echo "Usage: <script> <Nirmata-API-Token <NirmataURL>"
	echo ""
	echo "Eg: <script> <Nirmata-API-Token> https://www.nirmata.io"
else
	TOKEN=$1
	NIRMATAURL=$2
	echo "====================="
	echo "Fetching User Details"
	echo "====================="
        echo Username,Email > user_details_devops.csv
	curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/User?fields=id,name,email,role" | \
jq -r 'map(select(.role == "devops")) | .[] | [.name, .email] | @csv' >> user_details_devops.csv
	echo "=============================================================================="	
	echo "Fetching Cluster and Environment Permissions for the DevOps Users" 
	echo "=============================================================================="
	curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/user?fields=id,name,role" | jq -r '.[] | select(.role == "devops").id' > cluster_aclids.txt
        echo "Username,Environment Name,Environment Permission" > output.csv
	for claclid in $(cat cluster_aclids.txt)
        do
		curl -s --location "https://nirmata.io/cluster/api/entityPermissions?entityType=user&entityId=$claclid" --header "Authorization: NIRMATA-API $TOKEN" | \
jq -r '.permissions | .entityName as $username | .clusters[] |
       [$username] +
       (.environments[]? | [.environmentName, .environmentPermission]) |
       @csv' | tr -d '"' >> output.csv
	done
fi
