#!/bin/bash

# Check for correct number of arguments
if [ "$#" -ne 5 ]; then
  echo "Usage: $0 <text_file_path> <file_name> <rule_name> <exclude_SECURITY_CONTEXT_CONSTRAINT> <match_SECURITY_CONTEXT_CONSTRAINT>"
  exit 1
fi

# Text file path
TEXT_FILE="$1"

# Output YAML file
OUTPUT_YAML="$2.yaml"

# Rule name
RULE_NAME="$3"

# Exclude SECURITY_CONTEXT_CONSTRAINT
EXCLUDE_SECURITY_CONTEXT="$4"

# Match SECURITY_CONTEXT_CONSTRAINT
MATCH_SECURITY_CONTEXT="$5"

# Check if the text file exists
if [ ! -f "$TEXT_FILE" ]; then
  echo "Text file not found: $TEXT_FILE"
  exit 1
fi

# Create Kyverno policy YAML file
cat <<EOF > "$OUTPUT_YAML"
spec:
  rules:
    - name: $RULE_NAME
      exclude:
        any:
EOF

# Initialize variables to track the current namespace and pod names array
current_namespace=""
pod_names=()

# Read data from the text file and append to the YAML for exclude section
awk 'NR > 2 && $4 == "'"$EXCLUDE_SECURITY_CONTEXT"'" {
  if ($1 != current_namespace) {
    if (current_namespace != "") {
      # Close the previous resource section
      print "        - resources:"
      print "            kinds:"
      print "              - Pod"
      print "            namespaces:"
      print "              - " current_namespace
      print "            names:"
      for (i = 1; i <= length(pod_names); i++) {
        print "              - " pod_names[i]
      }
    }
    # Start a new resource section for the current namespace
    current_namespace=$1
    delete pod_names
    pod_names[1]=$2
  } else {
    # Append the pod name to the current namespace
    pod_names[length(pod_names) + 1]=$2
  }
} END {
  if (current_namespace != "") {
    # Close the last resource section
      print "        - resources:"
      print "            kinds:"
      print "              - Pod"
      print "            namespaces:"
      print "              - " current_namespace
      print "            names:"
    for (i = 1; i <= length(pod_names); i++) {
      print "              - " pod_names[i]
    }
  }
}' "$TEXT_FILE" >> "$OUTPUT_YAML"

# Add the match section to the YAML
cat <<EOF >> "$OUTPUT_YAML"
      match:
        any:
EOF

# Read data from the text file again and append to the YAML for match section
awk 'NR > 2 && $4 == "'"$MATCH_SECURITY_CONTEXT"'" {
  print "        - resources:"
  print "            kinds:"
  print "              - Pod"
  print "            namespaces:"
  print "              - " $1
  print "            names:"
  print "              - " $2
}' "$TEXT_FILE" >> "$OUTPUT_YAML"

echo "Kyverno policy saved to $OUTPUT_YAML"
