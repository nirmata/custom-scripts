#!/bin/bash

if [ $# -lt 2 ]; then
    echo "Usage: <script> clustername <Nirmata-API-Token>"
    echo ""
    echo "* clustername: Clustername in nirmata UI"
    echo ""
    echo "Eg: <script> test-cluster <Nirmata-API-Token>"
else
        TOKEN=$2
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
