#!/bin/bash

if [ $# -lt 1 ]; then
    echo "Usage: $0 clustername"
    echo ""
    echo "* clustername: Clustername in nirmata UI"
    echo ""
    echo "Eg: $0 test-cluster"
else
	TOKEN=<Add Nirmata API Token Here>
	NIRMATAURL=https://www.nirmata.io
	CLUSTERNAME=$1
	CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" | jq -r ".[] | select( .name == \"$CLUSTERNAME\" ).id")
	echo $CLUSTERID > clusterid_$CLUSTERNAME
	for clusterid in `cat clusterid_$CLUSTERNAME`         
    	do
	        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X DELETE "$NIRMATAURL/cluster/api/KubernetesCluster/$clusterid?action=remove"
        	if [[ $? -eq 0 ]]; then
			echo "$CLUSTERNAME is Deleted Successfully"
        	fi
    	done   
fi

