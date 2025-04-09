#!/bin/bash

# Initialize counters
annotated_pods=0
non_annotated_pods=0
empty_namespaces=()

# Print header with fixed column widths
echo
echo "----------------------------------------------------------------------------------------------------------------------"
printf "%-55s %-20s %-20s %s\n" "Pod Name" "Namespace" "Annotation Exists?" "Annotation Value"
echo "----------------------------------------------------------------------------------------------------------------------"

# Loop through all namespaces
for ns in $(kubectl get namespaces -o custom-columns=NAME:.metadata.name --no-headers); do
  # Get pods in each namespace
  pods=$(kubectl get pods -n "$ns" -o custom-columns=NAME:.metadata.name --no-headers)

  if [ -z "$pods" ]; then
    # No pods in this namespace
    empty_namespaces+=("$ns")
  else
    # Loop through pods
    for pod in $pods; do
      # Check if the pod has the "kubernetes.io/psp" annotation
      annotation_value=$(kubectl get pod "$pod" -n "$ns" -o jsonpath='{.metadata.annotations.kubernetes\.io/psp}')

      if [ -n "$annotation_value" ]; then
        # Pod has the annotation
        printf "%-55s %-20s %-20s %s\n" "$pod" "$ns" "Yes" "$annotation_value"
        ((annotated_pods++))
      else
        # Pod does not have the annotation
        printf "%-55s %-20s %-20s %s\n" "$pod" "$ns" "No" "N/A"
        ((non_annotated_pods++))
      fi
    done
  fi
done

echo "----------------------------------------------------------------------------------------------------------------------"
# Print the counts
echo
echo "Total Pods with psp annotation: $annotated_pods"
echo "Total Pods without psp annotation: $non_annotated_pods"

# Print namespaces with 0 pods
if [ ${#empty_namespaces[@]} -gt 0 ]; then
    echo
    echo "Namespaces with 0 Pods:"
    for ns in "${empty_namespaces[@]}"; do
        echo "- $ns"
    done
else
    echo
    echo "No namespaces with 0 pods."
fi
