#!/bin/bash 

rm -f /tmp/find-env-namespaces-tmp.txt

for namespace in $(kubectl get namespace --no-headers |awk '{print $1}'); do 
    #echo found namespace $namespace
    for pod in $(kubectl -n $namespace get pod --no-headers 2>/dev/null |awk '{print $1}'  ); do
        #echo found pod $pod $namespace
        nirmata_env=$(kubectl -n $namespace get pod $pod --show-labels --no-headers |awk '{print $6}' |grep -oP 'nirmata.io/environment.name=.*,' |sed -e 's,nirmata.io/environment.name=,,' -e s/,//)
        if [ ! -z $nirmata_env ];then
            echo $nirmata_env:$namespace >>/tmp/find-env-namespaces-tmp.txt
        fi
    done
done

echo Env:Namespace
sort /tmp/find-env-namespaces-tmp.txt  |uniq
rm -f /tmp/find-env-namespaces-tmp.txt
