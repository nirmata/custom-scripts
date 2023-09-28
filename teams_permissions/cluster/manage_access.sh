#!/bin/bash

# Check if all required arguments are provided
if [ $# -lt 5 ]; then
  echo "Usage: $0 NIRMATAURL TOKEN teamname Permission clustername1 [clustername2 ...]"
  exit 1
fi

NIRMATAURL="$1"
TOKEN="$2"
TEAM_NAME="$3"
Permission="$4"

# Shift the first four arguments to get cluster names
shift 4

# Iterate through the remaining arguments (cluster names)
while [ $# -gt 0 ]; do
  CLUSTERNAME="$1"

  # Get team ID by name
  TeamID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/users/api/teams?fields=id,name" | jq -r ".[] | select(.name == \"$TEAM_NAME\").id")

  if [ -z "$TeamID" ]; then
    echo "Team '$TEAM_NAME' not found."
    exit 1
  fi

  # Get cluster ID by name
  CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" | jq ".[] | select( .name == \"$CLUSTERNAME\" ).id" | sed "s/\"//g")

  if [ -z "$CLUSTERID" ]; then
    echo "Cluster '$CLUSTERNAME' not found."
  else
    # Get parent ID
    ParentID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/AccessControlList" | jq -r ".[] | select(.parent.id == \"$CLUSTERID\").id")

    # Create AccessControl
    CreateAccessControlResponse=$(curl -s -o /dev/null -w "%{http_code}" -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/cluster/api/txn" -d "
    {
      \"create\": [
        {
          \"parent\": \"$ParentID\",
          \"modelIndex\": \"AccessControl\",
          \"permission\": \"$Permission\",
          \"entityType\": \"team\",
          \"entityId\": \"$TeamID\",
          \"entityName\": \"$TEAM_NAME\"
        }
      ],
      \"update\": [],
      \"delete\": []
    }")

    # Check if AccessControl creation was successful
    if [ "$CreateAccessControlResponse" -eq 200 ]; then
      echo "AccessControl for Team '$TEAM_NAME' with Permission '$Permission' has been successfully created and updated for Cluster '$CLUSTERNAME'."
    else
      echo "Failed to create/update AccessControl for Team '$TEAM_NAME' with Permission '$Permission' in Cluster '$CLUSTERNAME'."
    fi
  fi

  # Shift to the next cluster name
  shift
done
