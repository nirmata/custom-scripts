#!/bin/bash

# Get all cluster policies
cluster_policies=$(kubectl get clusterpolicies -o jsonpath='{.items[*].metadata.name}')

# Loop through each policy
for policy in $cluster_policies; do
  # Get the policy definition
  policy_definition=$(kubectl get clusterpolicy "$policy" -o jsonpath='{.spec}')

  # Extract and print rule names using jq
  jq -r '.rules[].name' <<< "$policy_definition"
done
