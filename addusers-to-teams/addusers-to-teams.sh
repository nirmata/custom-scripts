#!/usr/bin/bash


STRING="ea1qa"
NIRMATAURL="$1"
FILENAME=$2

echo -e "\nEnter the Nirmata URL: \n"
read -s TOKEN

cat $FILENAME | grep -v Name > $FILENAME.temp

for line in $(cat $FILENAME.temp)
do
        #set -x
        TEAM_ID=""
        USER_EXISTS=""
        USER=$(echo $line | cut -d "," -f 2)
        TEAM_TMP=$(echo $line | cut -d "," -f 1)
        EMAIL=$(echo $line | cut -d "," -f 3)
        TENANT_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "https://www.nirmata.io/users/api/tenant?fields=id" | jq '.[].id' | sed "s/\"//g")
        USER_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/user?fields=id,name" | jq ".[] | select( .name == \"$USER\" ).id" | sed "s/\"//g")
        TEAM_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$TEAM_TMP-$STRING-team\" ).id" | sed "s/\"//g")
        if [[ -z $TEAM_ID ]]; then
                echo "User $USER cannot be created and added to \"$TEAM_TMP-$STRING-team\" as it does not exist"
                continue
        fi

        if [[ -z $USER_EXISTS ]]; then
                curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/users/api/txn" -d "
                {
                  \"create\": [
                    {
                      \"role\": \"devops\",
                      \"name\": \"$USER\",
                      \"email\": \"$EMAIL\",
                      \"identityProvider\": \"Local\",
                      \"teams\": [
                        \"$TEAM_ID\"
                      ],
                      \"mfaEnabled\": false,
                      \"modelIndex\": \"User\",
                      \"parent\": \"$TENANT_ID\"
                    }
                  ],
                  \"update\": [],
                  \"delete\": []
                }"
                if [[ $? = 0 ]]; then
                        echo "User $USER added successfully to \"$TEAM_TMP-$STRING-team\""
                else
                        echo "Something went wrong when adding user $USER"
                fi
        else
                echo "User $USER already exists"
                continue
        fi
done
