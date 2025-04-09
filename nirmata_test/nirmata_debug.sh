#!/bin/bash

SERVICES="$*"

for service in $SERVICES;do 
	IPs=$(kubectl -n nirmata get pod -o wide | grep "$service" | awk '{print $6}')
        echo "Pod IPs are $IPs"
	for IP in $IPs;do 
		curl -k -X PUT -d "{\"name\": \"com.nirmata\", \"level\": \"DEBUG\"}" https://"$IP":8443/"$service"/logger
	done
done

