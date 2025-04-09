
This script is used for adding a cluster in NPM using Nirmata API's

<ins>**Prerequisites:**</ins>

This script will require
- `curl`, `yq` and `jq` to be installed on the machine where this will be run
- Nirmata API token updated in the script
- A Kubernetes cluster to add in NPM

<ins>**Usage:**</ins>

Execute the script with cluster name as an argument

```sh
root@ip-172-31-81-194:~/npm/nirmata-scripts/api/addcluster-npm# ./addcluster.sh kindtest24

Cluster added to NPM successfully
```


