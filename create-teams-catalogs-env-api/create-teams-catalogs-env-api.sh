#!/usr/bin/bash


if [[ $# != 3 ]]; then
        echo -e "\nUsage: $0 <Nirmata URL> <filename> <cluster-name>"
        echo -e "\nExamples:\n$0 https://nirmata.io namespaces.txt testcluster1\n$0 https://pe31.nirmata.co /tmp/mynslist.txt testcluster2\n$0 https://pe35.nirmata.co project.txt devekscluster\n"
        exit 1
fi

STRING="ea1qa"
NIRMATAURL=$1
FILENAME=$2
CLUSTERNAME=$3

echo -e "\nEnter the Nirmata API token: \n"
read -s "TOKEN"

for team in $(cat $FILENAME)
do

        TEAM_EXISTS=""
        TEAM_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$team-$STRING\" ).id" | sed "s/\"//g")
        if [[ ! -z $TEAM_EXISTS ]]; then
                echo "Team \"$team-$STRING\" already exists"
                continue
        fi
        curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/users/api/txn" -d "
        {
          \"create\": [
            {
              \"name\": \"$team-$STRING\",
              \"description\": \"$team-$STRING\",
              \"users\": [],
              \"modelIndex\": \"Team\"
            }
          ],
          \"update\": [],
          \"delete\": []
        }"
        if [[ $? = 0 ]]; then
                echO "Team \"$team-$STRING\" created successfully"
        else
                echo "Something went wrong when creating team \"$team-$STRING\""
        fi
done


for catalog in $(cat $FILENAME)
do

        CATALOG_EXISTS=""
        CATALOG_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/catalog/api/catalogs?fields=id,name" | jq ".[] | select( .name == \"$catalog-$STRING\" ).id" | sed "s/\"//g")
        if [[ ! -z $CATALOG_EXISTS ]]; then
                echo "Catalog \"$catalog-$STRING\" already exists"
                continue
        fi
        OWNER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$catalog-$STRING\" ).id" | sed "s/\"//g")

        curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/catalog/api/txn" -d "

        {
          \"create\": [
            {
              \"name\": \"$catalog-$STRING\",
              \"description\": \"$catalog-$STRING\",
              \"labels\": {},
              \"modelIndex\": \"Catalogs\",
              \"accessControlList\": [
                {
                  \"ownerType\": \"team\",
                  \"ownerId\": \"$OWNER_ID\",
                  \"ownerName\": \"$catalog-$STRING\",
                  \"modelIndex\": \"AccessControlList\",
                  \"enabled\": true
                }
              ]
            }
          ],
          \"update\": [],
          \"delete\": []
        }"
        if [[ $? = 0 ]]; then
                echO "Catlog \"$catalog-$STRING\" created successfully"
        else
                echo "Something went wrong when creating catalog \"$catalog-$STRING\""
        fi
done


for environment in $(cat $FILENAME)
do

        CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" | jq ".[] | select( .name == \"$CLUSTERNAME\" ).id" | sed "s/\"//g")

        ENVIRONMENT_EXISTS=""
        ENVIRONMENT_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/environments?fields=id,name" | jq ".[] | select( .name == \"$environment-$STRING\" ).id" | sed "s/\"//g")
        if [[ ! -z $ENVIRONMENT_EXISTS ]]; then
                echo "Environment \"$environment-$STRING\" already exists"
                continue
        fi
        OWNER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$environment-$STRING\" ).id" | sed "s/\"//g")

        curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/environments/api/txn" -d "

        {
          \"create\": [
            {
              \"name\": \"$environment-$STRING\",
              \"resourceType\": \"medium\",
              \"hostCluster\": {
                \"service\": \"Cluster\",
                \"modelIndex\": \"KubernetesCluster\",
                \"id\": \"$CLUSTERID\"
              },
              \"namespace\": \"$environment\",
              \"labels\": {},
              \"modelIndex\": \"Environment\",
              \"accessControlList\": [
                {
                  \"ownerType\": \"team\",
                  \"ownerId\": \"$OWNER_ID\",
                  \"ownerName\": \"$environment-$STRING\",
                  \"modelIndex\": \"AccessControlList\"
                }
              ]
            }
          ],
          \"update\": [],
          \"delete\": []

        }"
        if [[ $? = 0 ]]; then
                echO "Environment \"$environment-$STRING\" created successfully"
        else
                echo "Something went wrong when creating environment \"$environment-$STRING\""
        fi

done
