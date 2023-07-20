  This script is used for fetching details like namespaces, deployments, serviceaccounts and clusterroles for PSP migration. 

<ins>**Usage:**</ins>

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

