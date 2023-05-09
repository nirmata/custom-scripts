 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster

#### Usage: 
```
$ ./kyverno-baseline.sh

=========================================
Current Kyverno Deployment Status
=========================================

Kubernetes Version: v1.23.17-eks-a59e1f0

Kyverno Deployment Version
 - kyverno-license-manager:v0.0.2
 - kyverno:v1.9.2-n4k.nirmata.1
 - kyvernopre:v1.9.2-n4k.nirmata.1
 - kyverno-license-manager:v0.0.2
 - cleanup-controller:v1.9.2-n4k.nirmata.1

Cluster Size Details
 - Number of Nodes in the Cluster: 12
 - Number of Pods in the Cluster: 154

Total Number of Kyverno ClusterPolicies in the Cluster: 37
Cloud Provider/Infrastructure: AWS

Top objects in etcd:

Kyverno Replicas:
 - 3 replicas of Kyverno found

Kyverno Pod status:
NAME                                         READY   STATUS    RESTARTS   AGE
kyverno-ccfc87875-5xdq2                      2/2     Running   0          4d3h
kyverno-ccfc87875-7gqcv                      2/2     Running   0          4d3h
kyverno-ccfc87875-xqqjr                      2/2     Running   0          4d3h
kyverno-cleanup-controller-5b8c57465-d9sl9   1/1     Running   0          4d3h

Kyverno CRD's:
 - admissionreports.kyverno.io
 - backgroundscanreports.kyverno.io
 - cleanuppolicies.kyverno.io
 - clusteradmissionreports.kyverno.io
 - clusterbackgroundscanreports.kyverno.io
 - clustercleanuppolicies.kyverno.io
 - clusterpolicies.kyverno.io
 - clusterpolicyreports.wgpolicyk8s.io
 - clusterreportchangerequests.kyverno.io
 - generaterequests.kyverno.io
 - kyvernoadapters.security.nirmata.io
 - kyvernoes.security.nirmata.io
 - kyvernooperators.security.nirmata.io
 - openshiftkyvernooperators.operator.nirmata.io
 - policies.kyverno.io
 - policyexceptions.kyverno.io
 - policyreports.wgpolicyk8s.io
 - reportchangerequests.kyverno.io
 - updaterequests.kyverno.io

Kyverno ValidatingWebhook Deployed:
 - kyverno-cleanup-validating-webhook-cfg
 - kyverno-exception-validating-webhook-cfg
 - kyverno-operator-validating-webhook-configuration
 - kyverno-policy-validating-webhook-cfg
 - kyverno-resource-validating-webhook-cfg

Kyverno MutatingWebhooks Deployed:
 - kyverno-policy-mutating-webhook-cfg
 - kyverno-resource-mutating-webhook-cfg
 - kyverno-verify-mutating-webhook-cfg

Pod Disruption Budget Deployed:

NAME      MIN AVAILABLE   MAX UNAVAILABLE   ALLOWED DISRUPTIONS   AGE
kyverno   1               N/A               2                     4d22h

System Namespaces excluded in webhook
- "kyverno"

Memory and CPU consumption of Kyverno pods:
NAME                                         CPU(cores)   MEMORY(bytes)
kyverno-ccfc87875-5xdq2                      19m          143Mi
kyverno-ccfc87875-7gqcv                      115m         253Mi
kyverno-ccfc87875-xqqjr                      19m          146Mi
kyverno-cleanup-controller-5b8c57465-d9sl9   3m           24Mi

Collecting the manifests for cluster policies,Kyverno deployments and ConfigMaps
 - Manifests are collected in "kyverno/manifests" folder

Collecting the logs for all the Kyverno pods
 - Logs are collected in "kyverno/logs" folder

Verifying Kyverno Metrics
- Kyverno Metrics are exposed on this cluster

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
kyverno-svc-metrics   ClusterIP   172.20.188.180   <none>        8000/TCP   4d22h

No of Policies in "Not Ready" State: 0

Baseline report "baselinereport.tar" generated successfully in the current directory

```
