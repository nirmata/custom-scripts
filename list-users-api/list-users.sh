#!/usr/bin/bash

#TOKEN=""
NIRMATAURL="$1"

if [[ $# != 1 ]]; then
        echo -e "\nUsage: $0 <Nirmata URL>\n"
        exit 1
fi

echo -e "\nEnter the Nirmata API token: \n"
read -s TOKEN


echo "Name,ID,IdentityProvider" > users.csv
curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/User" | jq -r '.[] | "\(.name),\(.id),\(.identityProvider)"' >> users.csv
