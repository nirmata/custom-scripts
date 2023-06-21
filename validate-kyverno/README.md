 # Bash script to verify the Kyverno deployment

#### Prerequisites:
    - A Kubernetes Cluster with Kyverno installed.
    - Kubectl access to the cluster.
    - A linux or Mac machine to execute the script.
    - jq installed. 
    - Servicemonitor name created for Kyverno
    - Promtheus EP (IP:PORT)

__NOTE__: __
In a typical installation, the Prometheus EP can be found using `kubectl get ep -A | grep prometheus-kube-prometheus-prometheus | awk '{ print $3}'`. The EP name maybe different in your environment so use the command accordingly. 

#### Usage: 
```
$ ./check-status.sh
```
