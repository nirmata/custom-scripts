#!/bin/bash

# Define fixed column widths for the printf formatting
namespace_width=15
type_width=15
name_width=30
url_width=30
policy_width=25
update_width=10

if [[ $# = 1 ]]; then
       allns="$1"
else
       allns=$(kubectl get ns --no-headers | cut -d ' ' -f1)
fi

# Print the header
echo
printf "%-${namespace_width}s| %-${type_width}s| %-${name_width}s| %-${url_width}s| %-${policy_width}s| %-${update_width}s\n" \
"Namespace" "Type" "Name" "Server URL" "Policy" "Update Needed"

# List all namespaces
for namespace in $allns; do
  # Types of workloads to check
  for type in Deployment StatefulSet Job CronJob; do
    # Get all resources of the current type in the current namespace
    kubectl get $type -n $namespace -o json | jq -c '.items[] | {name: .metadata.name, policy: .spec.template.spec.containers[].imagePullPolicy,secrets: .spec.template.spec.imagePullSecrets}' | \
    while read -r line; do
      name=""
      policy=""
      secrets=""
      name=$(echo $line | jq -r '.name' | tr -d '\r')
      policy=$(echo $line | jq -r '.policy' | tr -d '\r')
      secrets=$(echo $line | jq -r '.secrets' | tr -d '\r')


      if [ "$secrets" == "null" ]; then
        serverURL="N/A"
        updateNeeded="N/A"
        continue
      else
        secretName=$(echo $secrets | jq -r '.[].name' | tr -d '\r')
        # Extract the server URL from the secret
        serverURL1=$(kubectl get secret $secretName -n $namespace -o json | jq -r '.data[".dockercfg"]' | tr -d '\r' | base64 -d | jq -r 'keys[0]' 2> /dev/null)
        serverURL2=$(kubectl get secret $secretName -n $namespace -o json | jq -r '.data[".dockerconfigjson"]' | tr -d '\r' | base64 --decode | jq -r '.auths | to_entries[] | .key' 2> /dev/null)

        # Determine if an update is needed based on the server URL
        updateNeeded="Yes"
        if [[ $serverURL1 == "nexus-docker-private-registry.ci.duke-energy.app" ]] || [[ $serverURL2 == "nexus-docker-private-registry.ci.duke-energy.app" ]]; then
          updateNeeded="No"
        fi
      fi
      if [ -n "$serverURL1" ]; then
        serverURL=$serverURL1
      elif [ -n "$serverURL2" ]; then
        serverURL=$serverURL2
      else
        serverURL="Unknown" # Optional: Set c to a default value if both a and b are empty
      fi

      printf "%-${namespace_width}s| %-${type_width}s| %-${name_width}s| %-${url_width}s| %-${policy_width}s| %-${update_width}s\n" \
      $namespace $type $name $serverURL $policy $updateNeeded
    done
  done
done
echo
