 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster.
    - A linux or Mac machine with bash shell to execute the script.
    - jq installed. 
    - Promtheus installed with servicemonitor for Kyverno created. 
    - Servicemonitor name created for Kyverno
    - Promtheus svc (IP:PORT) [NodeIP and NodePort]
    - Metrics server should be installed on the cluster

__How to get the Prometheus Service__: <br />
In a typical installation, the Prometheus SVC can be found by running `kubectl get svc -A | grep kube-prometheus-prometheus | awk '{ print $3,$4,$6 }'`. The SVC name maybe different in your environment so use the command accordingly. 
Please ensure that you can reach Prometheus from the system where you are executing the script

#### Usage: 
```
$./kyverno-healthcheck-baseline-v3.sh <service-monitor-for-kyverno> <Prometheus SVC (NodeIP:NodePort)> <KYVERNO_NAMESPACE>

Example:
$ kubectl get svc -A | grep prometheus-kube-prometheus-prometheus | awk '{ print $3,$4,$6 }'
NodePort 172.20.10.35 9090:30098/TCP

$ ./kyverno-healthcheck-baseline-v3.sh service-monitor-kyverno-service 172.20.10.35:30098 kyverno
```


