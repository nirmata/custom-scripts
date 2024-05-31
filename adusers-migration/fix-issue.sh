#!/bin/bash

## to run use:
# nohup ./migrate-acls-v4.sh > ADoutput$(date +"%Y%m%d").log 2>&1 &

## URL of the Nirmata environment
## DEV/TEST: https://caasd-nirmata-ent1-dcpdev.duke-energy.com
## QA: https://caasq-nirmata-ent1-dcpqa.duke-energy.com
## PROD: https://caasp-nirmata-ent1-dcpprd.duke-energy.com
NIRMATAURL='https://nirmata.io'

## Name of the CSV file to use
FILE='test.csv'

## Enter YOUR Nirmata API key:
TOKEN='xxxxxxxxx'

cluster() {

#curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/AccessControlList?fields=id" | jq -r ".[].id" > cluster_aclids.txt

truncate --size 0 cluster_aclids.txt

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/kubernetescluster?fields=name,id" | jq -r ".[].id" > clusterlist.txt

for cluster in $(cat clusterlist.txt)
do
        #echo $cluster
        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/kubernetescluster/$cluster/accessControlList?fields=id" |jq -r ".[].id" >> cluster_aclids.txt
done

for claclid in $(cat cluster_aclids.txt)
do
        teamA_permissions=""
        teamA_permissions=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/AccessControlList/$claclid/accessControl?fields=id,entityType,entityName,permission" | jq -r ".[] | select((.entityType == \"team\") and (.entityName == \"$1\")).permission")
        teamB_uuid=""
        teamB_uuid=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq -r ".[] | select( .name == \"$2\" ).id")
        entityType="team"
        echo
        #echo "claclid: $claclid"
        #echo "teamA_permissions: $teamA_permissions"
        #echo "teamB_uuid: $teamB_uuid"
        #echo "TEAM_B: $TEAM_B"
        #echo "entityType: $entityType"
        if [[ ! -z $teamA_permissions ]]; then
                curl --location -X POST "$NIRMATAURL/cluster/api/AccessControlList/$claclid/accessControls" \
                --header "Authorization: NIRMATA-API $TOKEN" \
                --header 'Content-Type: text/plain' \
                --data '{
                        "entityType": "'"$entityType"'",
                        "entityId": "'"$teamB_uuid"'",
                        "entityName": "'"$2"'",
                        "permission": "'"$teamA_permissions"'"
                        }'
        fi

done

}

environments() {

#curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/AccessControlList?fields=id" | jq -r ".[].id" > environments_aclids.txt

truncate --size 0 environments_aclids.txt

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/Environment" | jq -r ".[].id" > environments_list.txt

for envv in $(cat environments_list.txt)
do
        #echo $envv
        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/Environment/$envv/accessControlList?fields=id" |jq -r ".[].id" >> environments_aclids.txt
done

for envaclid in $(cat environments_aclids.txt)
do
        teamA_permissions=""
        teamA_permissions=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/AccessControlList/$envaclid/accessControl?fields=id,entityType,entityName,permission" | jq -r ".[] | select((.entityType == \"team\") and (.entityName == \"$1\")).permission")
        #echo "teamA_permissions: $teamA_permissions"
        teamB_uuid=""
        teamB_uuid=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq -r ".[] | select( .name == \"$2\" ).id")
        #echo "teamB_uuid: $teamB_uuid"
        entityType="team"
        #echo
        #echo "envaclid: $envaclid"
        #echo "teamA_permissions: $teamA_permissions"
        #echo "teamB_uuid: $teamB_uuid"
        #echo "TEAM_B: $TEAM_B"
        #echo "entityType: $entityType"
        if [[ ! -z $teamA_permissions ]]; then
                curl --location -X POST "$NIRMATAURL/environments/api/AccessControlList/$envaclid/accessControls" \
                --header "Authorization: NIRMATA-API $TOKEN" \
                --header 'Content-Type: text/plain' \
                --data '{
                        "entityType": "'"$entityType"'",
                        "entityId": "'"$teamB_uuid"'",
                        "entityName": "'"$2"'",
                        "permission": "'"$teamA_permissions"'"
                        }'
        fi

done

}

catalog() {

#curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/catalog/api/AccessControlList?fields=id" | jq -r ".[].id" > catalog_aclids.txt

truncate --size 0 catalog_aclids.txt

curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/catalog/api/catalogs" | jq -r ".[].id" > catalog_list.txt

for catalog in $(cat catalog_list.txt)
do
        #echo $catalog
        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/catalog/api/catalogs/$catalog/accessControlList?fields=id" |jq -r ".[].id" >> catalog_aclids.txt
done


for catalog_aclid in $(cat catalog_aclids.txt)
do
        teamA_permissions=""
        teamA_permissions=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/catalog/api/AccessControlList/$catalog_aclid/accessControl?fields=id,entityType,entityName,permission" | jq -r ".[] | select((.entityType == \"team\") and (.entityName == \"$1\")).permission")
        teamB_uuid=""
        teamB_uuid=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq -r ".[] | select( .name == \"$2\" ).id")
        entityType="team"
        echo
        #echo "catalog_aclid: $catalog_aclid"
        #echo "teamA_permissions: $teamA_permissions"
        #echo "teamB_uuid: $teamB_uuid"
        #echo "TEAM_B: $TEAM_B"
        #echo "entityType: $entityType"
        if [[ ! -z $teamA_permissions ]]; then
                curl --location -X POST "$NIRMATAURL/catalog/api/AccessControlList/$catalog_aclid/accessControls" \
                --header "Authorization: NIRMATA-API $TOKEN" \
                --header 'Content-Type: text/plain' \
                --data '{
                        "entityType": "'"$entityType"'",
                        "entityId": "'"$teamB_uuid"'",
                        "entityName": "'"$2"'",
                        "permission": "'"$teamA_permissions"'"
                        }'
        fi

done

}


## main




   # while read -r nirm_team_id;
   # do
   #      nirm_team_name=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq -r ".[] | select( .id == \"$nirm_team_id\" ).name")
   #      #adgrp_id=""

   #      echo "----------------------------------------------------------------------------------------"
   #      echo "Migrating Accesscontrol from team \"$nirm_team_name\" to team \"$adgrp\" for cluster service"
   #      echo "----------------------------------------------------------------------------------------"
   #      cluster "$nirm_team_name" "$adgrp"
   #      sleep 10
   #      echo "----------------------------------------------------------------------------------------"
   #      echo "Migrating Accesscontrol from team \"$nirm_team_name\" to team \"$adgrp\" for environment service"
   #      echo "----------------------------------------------------------------------------------------"
   #      environments "$nirm_team_name" "$adgrp"
   #      echo "----------------------------------------------------------------------------------------"
   #      echo "Migrating Accesscontrol from team \"$nirm_team_name\" to team \"$adgrp\" for catalog service"
   #      echo "----------------------------------------------------------------------------------------"
   #      catalog "$nirm_team_name" "$adgrp"

   #      nirm_team_name=""
   # done < "${adgrp}.txt"

while read -r line;
do
        nirm_team_name=$(echo $line | cut -d "," -f1)
        adgrp=$(echo $line | cut -d "," -f2)

        # echo "----------------------------------------------------------------------------------------"
        # echo "Migrating Accesscontrol from team \"$nirm_team_name\" to team \"$adgrp\" for cluster service"
        # echo "----------------------------------------------------------------------------------------"
        # cluster "$nirm_team_name" "$adgrp"
        # sleep 10
        echo "----------------------------------------------------------------------------------------"
        echo "Migrating Accesscontrol from team \"$nirm_team_name\" to team \"$adgrp\" for environment service"
        echo "----------------------------------------------------------------------------------------"
        environments "$nirm_team_name" "$adgrp"
        echo "----------------------------------------------------------------------------------------"
        echo "Migrating Accesscontrol from team \"$nirm_team_name\" to team \"$adgrp\" for catalog service"
        echo "----------------------------------------------------------------------------------------"
        catalog "$nirm_team_name" "$adgrp"

        nirm_team_name=""
        adgrp=""
done < $FILE

   


#cluster
#environments
#catalog
