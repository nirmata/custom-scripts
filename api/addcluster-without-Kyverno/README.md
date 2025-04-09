
This script is used for adding a cluster in NPM using Nirmata API's

<ins>**Prerequisites:**</ins>

This script will require
- `curl`, `yq` and `jq` to be installed on the machine where this will be run
- Nirmata API token updated in the script
- A Kubernetes cluster to add in NPM

<ins>**NOTE:**</ins>
While executing the script, if you come across below error, it can be safely ignored. 

error: unable to recognize "nirmata-kube-controller-testcluster14.yaml": no matches for kind "KyvernoOperator" in version "operator.kyverno.io/v1"


<ins>**Usage:**</ins>

Execute the script with cluster name and Nirmata URL as arguments. Provide the Nirmata API key after the prompt. 

```sh
root@ip-172-31-81-194:~/npm/nirmata-scripts/api/addcluster-npm# ./addcluster.sh kindtest24 https://nirmata.io 

Enter the Nirmata API token:


```


