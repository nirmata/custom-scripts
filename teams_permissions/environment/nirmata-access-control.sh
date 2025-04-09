#!/bin/bash

# Check if all required arguments are provided
if [ $# -lt 5 ]; then
  echo "Usage: $0 NIRMATAURL TOKEN teamname clustername Permission EnvironmentName [EnvironmentName ...]"
  exit 1
fi

NIRMATAURL="$1"
TOKEN="$2"
TEAM_NAME="$3"
ClusterName="$4"
Permission="$5"

# Shift the first five arguments to get Environment names
shift 5

# Get team ID by name
TeamID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq -r ".[] | select(.name == \"$TEAM_NAME\").id")

if [ -z "$TeamID" ]; then
  echo "Team '$TEAM_NAME' not found."
  exit 1
fi

# Iterate through provided Environment names and set permissions
for EnvironmentName in "$@"; do
  # Get environment ID by name
  EnvironmentID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/Environments?fields=id,name" | jq -r ".[] | select(.name == \"$EnvironmentName\").id")

  if [ -z "$EnvironmentID" ]; then
    echo "Environment '$EnvironmentName' not found."
  else
    # Get parent ID
    ParentID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/environments/api/AccessControlList" | jq -r ".[] | select(.parent.id == \"$EnvironmentID\").id")

    # Create AccessControl
    CreateAccessControlResponse=$(curl -s -o /dev/null -w "%{http_code}" -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/environments/api/txn" -d "
    {
      \"create\": [
        {
          \"parent\": \"$ParentID\",
          \"modelIndex\": \"AccessControl\",
          \"permission\": \"$Permission\",
          \"entityType\": \"team\",
          \"entityId\": \"$TeamID\",
          \"entityName\": \"$Permission\"
        }
      ],
      \"update\": [],
      \"delete\": []
    }")

    # Check if AccessControl creation was successful
    if [ "$CreateAccessControlResponse" -eq 200 ]; then
      echo "AccessControl for Team '$TEAM_NAME' with Permission '$Permission' has been successfully created and updated for Environment '$EnvironmentName'."
    else
      echo "Failed to create/update AccessControl for Team '$TEAM_NAME' with Permission '$Permission' in Environment '$EnvironmentName'."
    fi
  fi
done
