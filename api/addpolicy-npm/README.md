This script is used for deploying a policySet on a cluster in NPM

<ins>**Prerequisites:**</ins>

This script will require
- `curl`, `jq` to be installed on the machine where this will be run
- Nirmata API token updated in the script
- A Kubernetes cluster connected in NPM
 
<ins>**Usage:**</ins>

Execute the script with cluster name as an argument

```sh
root@ip-172-31-81-194:~/npm/nirmata-scripts/api/addpolicy-npm# ./addpolicy-npm.sh cust-cve kindtest24

PolicySet 'cust-cve' was deployed successfully on 'kindtest24'

```

