#!/usr/bin/bash


if [[ $# != 2 ]]; then
        echo -e "\nUsage: $0 <Nirmata URL> <CSV FILENAME>\n"
        exit 1
fi

urlencode() {
    # urlencode <string>
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}



STRING="ea1qa"
NIRMATAURL=$1
FILENAME=$2

rm -f *.txt *.tmp*

echo -e "\nEnter the Nirmata API token: \n"
read -s TOKEN

TENANT_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/tenant?fields=id" | jq '.[].id' | sed "s/\"//g")

cat $FILENAME | grep -v Name | cut -d "," -f 1 > $FILENAME.tmp1
cat $FILENAME | grep -v Name | cut -d "," -f 2- > $FILENAME.tmp2

for team in $(cat $FILENAME.tmp1)
do

        TEAM_EXISTS=""
        TEAM_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$team-$STRING-team\" ).id" | sed "s/\"//g")
        if [[ -z $TEAM_EXISTS ]]; then
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
        fi
done

for user in $(cat $FILENAME.tmp2)
do
        USER_EXISTS=""
        EMAIL=""
        USER=""
        USER=$(echo $user | cut -d "," -f 1)
        EMAIL=$(echo $user | cut -d "," -f 2)
        USER_EXISTS=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/user?fields=id,name" | jq ".[] | select( .name == \"$USER\" ).id" | sed "s/\"//g")
        if [[ -z $USER_EXISTS ]]; then
                curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/users/api/txn" -d "
                {
                  \"create\": [
                    {
                      \"role\": \"devops\",
                      \"name\": \"$USER\",
                      \"email\": \"$EMAIL\",
                      \"identityProvider\": \"SAML\",
                      \"teams\": [],
                      \"mfaEnabled\": false,
                      \"modelIndex\": \"User\",
                      \"parent\": \"$TENANT_ID\"
                    }
                  ],
                  \"update\": [],
                  \"delete\": []
                }"
        fi
done

cat $FILENAME | grep -v Name | cut -d "," -f 2 | sort | uniq > users.txt

for i in $(cat users.txt)
do
        cat $FILENAME | grep $i | cut -d "," -f 1 > $i.teams.txt
done

for i in $(cat $FILENAME.tmp2 | sort | uniq)
do
        #set -x
        iuser=$(echo $i | cut -d "," -f 1)
        iemail=$(echo $i | cut -d "," -f 2)
        for temp1 in $(cat $iuser.teams.txt)
        do

                curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq ".[] | select( .name == \"$temp1-$STRING-team\" ).id" >> $iuser-team-ids.txt
        done
        #set -x
        USER_ID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/user?fields=id,name" | jq ".[] | select( .name == \"$iuser\" ).id" | sed "s/\"//g")

        ENCODE_STRING=""
        USER_ID_ENCODED=""
        ENCODE_STRING="{\"users.id\":\"$USER_ID\"}"
        USER_ID_ENCODED=$(urlencode $ENCODE_STRING)
        USER_ID_ENCODED=${USER_ID_ENCODED%$'\r'}

        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id&query=$USER_ID_ENCODED" | jq '.[].id' >> $iuser-team-ids.txt
        cat $iuser-team-ids.txt | sort | uniq > $iuser-team-ids_all.txt
        #cat $iuser-team-ids_all.txt

        temp2=""
        temp3=""
        temp4=""
        #temp2=$(cat $iuser-team-ids_all.txt | tr "\n" "," | sed 's/.$//')

        cat $iuser-team-ids_all.txt | tr "\n" "," | sed 's/.$//' > temp_var.txt
        TEMP=""
        TEMP=$(cat temp_var.txt | head -1)
        echo -e "\nUser \"$iuser\" getting added to below team ids"
        cat $iuser-team-ids_all.txt

        curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/users/api/txn" -d "
                {
          \"create\": [],
          \"update\": [
            {
              \"teams\": [$TEMP],
              \"id\": \"$USER_ID\",
              \"service\": \"Users\",
              \"modelIndex\": \"User\"
            }
          ],
          \"delete\": []
        }" 1> /dev/null
        if [[ $? = 0 ]]; then
                echo "User \"$iuser\" added to teams successfully"
        else
                echo "Something went wrong when adding \"$iuser\" to teams"
        fi
done
