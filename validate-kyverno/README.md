 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster.
    - A linux or Mac machine to execute the script.

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
 - Number of Pods in the Cluster: 155

Total Number of Kyverno ClusterPolicies in the Cluster: 37
Cloud Provider/Infrastructure: AWS

Total size of the etcd database file physically allocated in bytes:
etcd_db_total_size_in_bytes{endpoint="https://168.254.5.3:2379"} 4.964352e+06

Top objects in etcd:
# HELP apiserver_storage_objects [STABLE] Number of stored objects at the time of last check split by kind.
# TYPE apiserver_storage_objects gauge
apiserver_storage_objects{resource="events"} 472

Kyverno Replicas:
 - 3 replicas of Kyverno found

Kyverno Pod status:
NAME                                         READY   STATUS    RESTARTS   AGE
kyverno-ccfc87875-5xdq2                      2/2     Running   0          6d5h
kyverno-ccfc87875-7gqcv                      2/2     Running   0          6d5h
kyverno-ccfc87875-xqqjr                      2/2     Running   0          6d5h
kyverno-cleanup-controller-5b8c57465-d9sl9   1/1     Running   0          6d5h

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
kyverno   1               N/A               2                     7d

System Namespaces excluded in webhook
- "kyverno"

Memory and CPU consumption of Kyverno pods:
NAME                                         CPU(cores)   MEMORY(bytes)
kyverno-ccfc87875-5xdq2                      23m          145Mi
kyverno-ccfc87875-7gqcv                      58m          259Mi
kyverno-ccfc87875-xqqjr                      17m          155Mi
kyverno-cleanup-controller-5b8c57465-d9sl9   2m           24Mi

Collecting the manifests for cluster policies,Kyverno deployments and ConfigMaps
 - Manifests are collected in "kyverno/manifests" folder

Collecting the logs for all the Kyverno pods
 - Logs are collected in "kyverno/logs" folder

Verifying Kyverno Metrics
- Kyverno Metrics are exposed on this cluster

NAME                  TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
kyverno-svc-metrics   ClusterIP   172.20.188.180   <none>        8000/TCP   7d

No of Policies in "Not Ready" State: 0

Total admission requests triggered in the last 24h:  311712

Percentage of total incoming admission requests corresponding to resource creations:  0.36511525197187794


Scraping Policies and Rule Counts from Prometheus


Scraping Policy and Rule Execution from Prometheus


Scraping Policy Rule Execution Latency from Prometheus


Scraping Admission Review Latency from Prometheus


Scraping Admission Requests Counts from Prometheus


Scraping Policy Change Counts from Prometheus


Scraping Client Queries from Prometheus


All the raw Kyverno data scraped above is dumped in BaselineReport.txt


Baseline report "baselinereport.tar" generated successfully in the current directory
```
