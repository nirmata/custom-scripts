#!/bin/bash

# Usage: ./twistcli_scan.sh <docker_image>

# Fixed values
CONSOLE_URL="https://asia-south1.cloud.twistlock.com/india-1131959901"
USERNAME="krish.bajaj@nirmata.com"
PASSWORD="XXXXXXXXXXX"

# Check if the correct number of arguments are passed
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <file-with-images>"
    exit 1
fi

# DOCKER_IMAGE=$1
FILE="$1"

# Generate Token
TOKEN=$(curl -s -k -X POST "${CONSOLE_URL}/api/v1/authenticate" \
    -H 'Content-Type: application/json' \
    -d '{
        "username": "'"$USERNAME"'",
        "password": "'"$PASSWORD"'"
    }' | jq -r .token)

if [ -z "$TOKEN" ]; then
    echo "Failed to retrieve token. Please check your credentials and console URL."
    exit 1
fi

echo "Token generated successfully."

while read -r img; do

        # Pull the Docker image
        echo "Pulling Docker image: ${img}"
        docker pull ${img} 1> /dev/null

        #Run twistcli scan
        twistcli images scan --address "${CONSOLE_URL}" --token "${TOKEN}" --publish=false --details "${img}"

        # Check if the scan was successful
        if [ $? -eq 0 ]; then
            echo "Twistcli scan completed successfully for image ${img}."
        else
            echo "Twistcli scan failed for image ${img}."
        fi
done < $FILE
