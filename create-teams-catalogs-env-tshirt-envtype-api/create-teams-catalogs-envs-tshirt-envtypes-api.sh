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

cat $FILENAME | grep -v Namespace > $FILENAME.temp

for team in $(cat $FILENAME.temp)
do

        TEAM_EXISTS=""
        team=$(echo $team | cut -d "," -f 1)
        TEAM_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$team-$STRING-team\" ).id" | sed "s/\"//g")
        if [[ ! -z $TEAM_EXISTS ]]; then
                echo "Team \"$team-$STRING-team\" already exists"
                continue
        fi
        curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/users/api/txn" -d "
        {
          \"create\": [
            {
              \"name\": \"$team-$STRING-team\",
              \"description\": \"$team-$STRING-team\",
              \"users\": [],
              \"modelIndex\": \"Team\"
            }
          ],
          \"update\": [],
          \"delete\": []
        }"
        if [[ $? = 0 ]]; then
                echo "Team \"$team-$STRING-team\" created successfully"
        else
                echo "Something went wrong when creating team \"$team-$STRING-team\""
        fi
done


for catalog in $(cat $FILENAME.temp)
do

        CATALOG_EXISTS=""
        catalog=$(echo $catalog | cut -d "," -f 1)
        CATALOG_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/catalog/api/catalogs?fields=id,name" | jq ".[] | select( .name == \"$catalog-$STRING-catalog\" ).id" | sed "s/\"//g")
        if [[ ! -z $CATALOG_EXISTS ]]; then
                echo "Catalog \"$catalog-$STRING-catalog\" already exists"
                continue
        fi
        OWNER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$catalog-$STRING-team\" ).id" | sed "s/\"//g")

        curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/catalog/api/txn" -d "

        {
          \"create\": [
            {
              \"name\": \"$catalog-$STRING-catalog\",
              \"description\": \"$catalog-$STRING-catalog\",
              \"labels\": {},
              \"modelIndex\": \"Catalogs\",
              \"accessControlList\": [
                {
                  \"ownerType\": \"team\",
                  \"ownerId\": \"$OWNER_ID\",
                  \"ownerName\": \"$catalog-$STRING-team\",
                  \"modelIndex\": \"AccessControlList\",
                  \"enabled\": true,
                  \"accessControls\": [
                    {
                      \"entityType\": \"team\",
                      \"entityId\": \"$OWNER_ID\",
                      \"permission\": \"edit\",
                      \"entityName\": \"$catalog-$STRING-team\",
                      \"modelIndex\": \"AccessControl\"
                    }
                  ]
                }
              ]
            }
          ],
          \"update\": [],
          \"delete\": []
        }"
        if [[ $? = 0 ]]; then
                echo "Catalog \"$catalog-$STRING-catalog\" created successfully"
        else
                echo "Something went wrong when creating catalog \"$catalog-$STRING-catalog\""
        fi
done


for environment in $(cat $FILENAME.temp)
do
        #set -x
        CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" | jq ".[] | select( .name == \"$CLUSTERNAME\" ).id" | sed "s/\"//g")

        ENVIRONMENT_TYPE_EXISTS=""
        ENVIRONMENT_TYPE=$(echo $environment | cut -d "," -f 2)
        environment=$(echo $environment | cut -d "," -f 1)
        ENVIRONMENT_EXISTS=""
        ENVIRONMENT_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/environments?fields=id,name" | jq ".[] | select( .name == \"$environment-$STRING\" ).id" | sed "s/\"//g")
        if [[ ! -z $ENVIRONMENT_EXISTS ]]; then
                echo "Environment \"$environment-$STRING\" already exists"
                continue
        fi
        ENVIRONMENT_TYPE_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/EnvironmentResourceType?fields=id,name" | jq ".[] | select( .name == \"$ENVIRONMENT_TYPE\" ).id" | sed "s/\"//g")
        if [[ -z $ENVIRONMENT_TYPE_EXISTS ]]; then
                echo "Environment \"$environment-$STRING\" cannot be created as \"$ENVIRONMENT_TYPE\" does not exist"
                continue
        fi
        OWNER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$environment-$STRING-team\" ).id" | sed "s/\"//g")

        #set +x
        curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/environments/api/txn" -d "

        {
          \"create\": [
            {
              \"name\": \"$environment-$STRING\",
              \"resourceType\": \"$ENVIRONMENT_TYPE\",
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
                  \"ownerName\": \"$environment-$STRING-team\",
                  \"modelIndex\": \"AccessControlList\",
                  \"accessControls\": [
                    {
                      \"entityType\": \"team\",
                      \"entityId\": \"$OWNER_ID\",
                      \"permission\": \"edit\",
                      \"entityName\": \"$environment-$STRING-team\",
                      \"modelIndex\": \"AccessControl\"
                    }
                  ]
                }
              ]
            }
          ],
          \"update\": [],
          \"delete\": []
        }"
        if [[ $? = 0 ]]; then
                echo "Environment \"$environment-$STRING\" created successfully"
        else
                echo "Something went wrong when creating environment \"$environment-$STRING\""
        fi

done
