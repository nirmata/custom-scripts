 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster

#### Usage: 
```
=========================================
Current Kyverno Deployment Status
=========================================
Kubernetes Version: v1.23.12

Kyverno Deployment Version
 - kyverno:v1.8.5
 - kyvernopre:v1.8.5

Cluster Size Details
 - Number of Nodes in the Cluster: 2
 - Number of Pods in the Cluster: 22

Total Number of Kyverno ClusterPolicies in the Cluster: 0
Cloud Provider/Infrastructure: Other

Top objects in etcd
Error from server (NotFound): the server could not find the requested resource

1 replicas of Kyverno found. It is recommended to deploy kyverno in HA Mode with 3 replicas

Kyverno Pod status:
NAME                       READY   STATUS    RESTARTS        AGE
kyverno-7b9bfd4cd8-tktbp   1/1     Running   5 (3h17m ago)   2d22h

Kyverno CRD's:
 - admissionreports.kyverno.io
 - backgroundscanreports.kyverno.io
 - clusteradmissionreports.kyverno.io
 - clusterbackgroundscanreports.kyverno.io
 - clusterpolicies.kyverno.io
 - clusterpolicyreports.wgpolicyk8s.io
 - generaterequests.kyverno.io
 - policies.kyverno.io
 - policyreports.wgpolicyk8s.io
 - updaterequests.kyverno.io

Kyverno ValidatingWebhook Deployed:
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


Collecting the manifests for cluster policies,Kyverno deployments and ConfigMaps
 - Manifests are collected in "kyverno/manifests" folder

Collecting the logs for all the Kyverno pods
 - Logs are collected in "kyverno/logs" folder

Verifying Kyverno Metrics
- Kyverno Metrics are exposed on this cluster

NAME                  TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)    AGE
kyverno-svc-metrics   ClusterIP   10.96.32.181   <none>        8000/TCP   2d22h

No of Policies in "Not Ready" State: 0

Baseline report "baselinereport.tar" generated successfully in the current directory

```
