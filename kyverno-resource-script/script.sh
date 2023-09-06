#!/bin/bash

# Output YAML file
OUTPUT_YAML="kyverno.yaml"

# Check if the CSV file exists
CSV_FILE="kyverno-resource-data.csv"

# Check if the CSV file exists
if [ ! -f "$CSV_FILE" ]; then
  echo "CSV file not found: $CSV_FILE"
  exit 1
fi

# Generate Kyverno policy YAML
cat <<EOF > "$OUTPUT_YAML"
apiVersion: kyverno.io/v1
kind: ClusterPolicy
metadata:
  name: kyverno-policy
spec:
  rules:
    - name: include-pods-non-restricted-v2
      match:
        resources:
          kinds:
            - Pod
EOF

# Read data from the CSV file and append to the YAML
tail -n +2 "$CSV_FILE" | while IFS=',' read -r NAMESPACE POD_NAME SERVICEACCOUNT SECURITY_CONTEXT_CONSTRAINT; do
  if [ "$SECURITY_CONTEXT_CONSTRAINT" != "restricted-v2" ]; then
    cat <<EOF >> "$OUTPUT_YAML"
        - resources:
            kinds:
              - Pod
            namespaces:
              - $NAMESPACE
            names:
              - $POD_NAME
EOF
  fi
done

echo "Kyverno policy saved to $OUTPUT_YAML"
