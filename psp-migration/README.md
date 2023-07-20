  This script is used for fetching details like namespaces, deployments, serviceaccounts and clusterroles for PSP migration. 


  Usage: 

 
<ins>**Prerequisites:**</ins>

- Make sure `curl` and `jq` are installed on the machine where you are running this script

<ins>**Usage:**</ins>

Execute the script with the required arguments and provide the Nirmata API token for your tenant. 

Required Arguments:
```sh
$1 - Nirmata URL
```

```sh

[root@saas ]# ./get-ns-deploy-svcaccnt-cr.sh

------------------------------------------------------------------------------------------------------------------------------------------------------
NAMESPACE                                APP                                      SERVICEACCOUNT                           CLUSTERROLE 
------------------------------------------------------------------------------------------------------------------------------------------------------
kube-system                              coredns                                  coredns                                  system:coredns
kyverno                                  kyverno                                  kyverno                                  kyverno     
kyverno                                  kyverno-cleanup-controller               kyverno-cleanup-controller               kyverno:cleanup-controller
local-path-storage                       local-path-provisioner                   local-path-provisioner-service-account   local-path-provisioner-role
nirmata                                  nirmata-kube-controller                  nirmata                                  nirmata:nirmata-privileged
nirmata                                  nirmata-kube-controller                  nirmata                                  nirmata:policyexception-manager
kube-system                              kindnet                                  kindnet                                  kindnet     
kube-system                              kube-proxy                               kube-proxy                               system:node-proxier
------------------------------------------------------------------------------------------------------------------------------------------------------
```

