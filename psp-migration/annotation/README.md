This script is used to list all pods in all namespaces and checks if they have the psp annotation applied to them. 

<ins>**Usage:**</ins>

```sh

$ ./check-psp-annotation.sh

----------------------------------------------------------------------------------------------------------------------
Pod Name                                                Namespace            Annotation Exists?   Annotation Value
----------------------------------------------------------------------------------------------------------------------
coredns-64897985d-vqzlk                                 kube-system          No                   N/A
coredns-64897985d-zcd2j                                 kube-system          No                   N/A
etcd-kindpsp-control-plane                              kube-system          No                   N/A
kindnet-qj8rn                                           kube-system          No                   N/A
kindnet-tb5hq                                           kube-system          No                   N/A
kube-controller-manager-kindpsp-control-plane           kube-system          No                   N/A
kube-proxy-8wjf2                                        kube-system          No                   N/A
kube-proxy-wkwhn                                        kube-system          No                   N/A
kube-scheduler-kindpsp-control-plane                    kube-system          No                   N/A
nginx-hostnetwork-deployment-79784cb86d-p9pdv           kube-system          Yes                  permissive
local-path-provisioner-58dc9cd8d9-b9bmk                 local-path-storage   No                   N/A
----------------------------------------------------------------------------------------------------------------------

Total Pods with psp annotation: 1
Total Pods without psp annotation: 10



```
