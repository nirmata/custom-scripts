#!/bin/bash
# nadm nirmata agent restart
# 11/2/2018 Nirmata
kubectl delete pod -n nirmata $(kubectl get pods -n nirmata|grep nirmata-agent |awk '{print $1}')