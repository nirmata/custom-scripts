 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster

#### Usage: 
```
[root@Bastion-public sagar]# ./kyverno-baseline.sh

=========================================
Current Kyverno Deployment Status
=========================================
Kubernetes Version: v1.25.4

Kyverno Deployment Version
 - kyverno:v1.10.0-alpha.1
 - kyvernopre:v1.10.0-alpha.1
 - background-controller:v1.10.0-alpha.1
 - cleanup-controller:v1.10.0-alpha.1
 - reports-controller:v1.10.0-alpha.1

Cluster Size Details
 - Number of Nodes in the Cluster: 3
 - Number of Pods in the Cluster: 29

Total Number of Kyverno ClusterPolicies in the Cluster: 1
Cloud Provider/Infrastructure: Oracle

Top objects in etcd
# HELP apiserver_storage_objects [STABLE] Number of stored objects at the time of last check split by kind.
# TYPE apiserver_storage_objects gauge
apiserver_storage_objects{resource="clusterrolebindings.rbac.authorization.k8s.io"} 107
apiserver_storage_objects{resource="clusterroles.rbac.authorization.k8s.io"} 108

No of Kyverno replicas: 3

Kyverno Pod status:
NAME                                             READY   STATUS    RESTARTS   AGE
kyverno-admission-controller-6bd6bd6976-st86x    1/1     Running   0          12h
kyverno-background-controller-55cd4dcb8f-njd9j   1/1     Running   0          12h
kyverno-cleanup-controller-6fc556f69d-zn7wv      1/1     Running   0          12h
kyverno-reports-controller-668c59f788-29778      1/1     Running   0          12h

Kyverno CRD's:
 - admissionreports.kyverno.io
 - backgroundscanreports.kyverno.io
 - cleanuppolicies.kyverno.io
 - clusteradmissionreports.kyverno.io
 - clusterbackgroundscanreports.kyverno.io
 - clustercleanuppolicies.kyverno.io
 - clusterpolicies.kyverno.io
 - clusterpolicyreports.wgpolicyk8s.io
 - policies.kyverno.io
 - policyexceptions.kyverno.io
 - policyreports.wgpolicyk8s.io
 - updaterequests.kyverno.io

Kyverno ValidatingWebhook Deployed:
 - kyverno-cleanup-validating-webhook-cfg
 - kyverno-exception-validating-webhook-cfg
 - kyverno-policy-validating-webhook-cfg
 - kyverno-resource-validating-webhook-cfg

Kyverno MutatingWebhooks Deployed:
 - kyverno-policy-mutating-webhook-cfg
 - kyverno-resource-mutating-webhook-cfg
 - kyverno-verify-mutating-webhook-cfg

Pod Disruption Budget Deployed:
- No matching pdb found for Kyverno. It is recommended to deploy a pdb with minimum replica of 1

System Namespaces excluded in webhook
- "kyverno"

Memory and CPU consumption of Kyverno pods:
NAME                                             CPU(cores)   MEMORY(bytes)
kyverno-admission-controller-6bd6bd6976-st86x    9m           103Mi
kyverno-background-controller-55cd4dcb8f-njd9j   2m           61Mi
kyverno-cleanup-controller-6fc556f69d-zn7wv      3m           25Mi
kyverno-reports-controller-668c59f788-29778      2m           55Mi
```
