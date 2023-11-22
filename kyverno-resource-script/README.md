# Kyverno Policy Generator

This Bash script generates Kyverno policy YAML files based on data from a text file. It simplifies the process of creating Kyverno policies by allowing you to specify rules, exclusions, and inclusions easily.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Usage](#usage)
- [Example](#example)

## Prerequisites

Before using this script, ensure that you have the following:

- **Bash**: Make sure you have Bash (Bourne-Again SHell) installed on your system.

## Usage

Follow these steps to generate Kyverno policy YAML files using the script:

1. **Make the Script Executable**: 
   ```
   chmod +x script.sh
   ```

2. **Run the Script**:
   ```
   ./script.sh <text_file_path> <file_name> <rule_name> <exclude_SECURITY_CONTEXT_CONSTRAINT> <match_SECURITY_CONTEXT_CONSTRAINT>
   ```

   - `<text_file_path>`: Path to the text file containing your data.
   - `<file_name>`: Desired name for the output YAML file.
   - `<rule_name>`: Name of the Kyverno rule.
   - `<exclude_SECURITY_CONTEXT_CONSTRAINT>`: Security context constraint to exclude from the policy.
   - `<match_SECURITY_CONTEXT_CONSTRAINT>`: Security context constraint to include in the policy.

3. **Generated Kyverno Policy**:
   The script will create a Kyverno policy YAML file with the specified rule names and context constraints.

## Example

For instance, if you want to generate a policy file named `vktest.yaml` based on data in the `nonprod_script.txt` file, excluding pods with the `restricted-v2` security context constraint and including pods with the `nonroot-anyuid` security context constraint, you can use the following command:

```bash
./script.sh nonprod_script.txt vktest myrule restricted-v2 nonroot-anyuid
```

This command will generate the policy and save it as `vktest.yaml`.

---