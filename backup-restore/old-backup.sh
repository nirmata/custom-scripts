#!/bin/bash

## main

BACKUP_DIR="$1"

if [[ $# != 1 ]]; then
        echo -e "\nUsage: $0 <backup-folder>\n"
        exit 1
fi

# List all mongo pods
mongos="mongodb-0 mongodb-1 mongodb-2"

for mongo in $mongos
do
    cur_mongo=$(kubectl -n nirmata exec $mongo -c mongodb -- sh -c 'echo "db.serverStatus()" |mongo' 2>&1|grep  '"ismaster"')
    if [[  $cur_mongo =~ "true" ]];then
        echo "$mongo is master"
        mongo_master=$mongo
    fi
done

MONGO_MASTER=$mongo_master

NIRMATA_SERVICES="Activity-nirmata Availability-cluster-hc-nirmata Availability-config-env-nirmata Availability-env-app-nirmata Catalog-nirmata Cluster-nirmata Config-nirmata Environments-nirmata Users-nirmata"

for nsvc in $NIRMATA_SERVICES
do
        kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mkdir -p /tmp/05102024 && mongodump --gzip --db=$nsvc --archive=/tmp/05102024/$nsvc.gz"
        sleep 2
        kubectl -n nirmata cp $MONGO_MASTER:/tmp/05102024/$nsvc.gz -c mongodb $BACKUP_DIR/$nsvc.gz
        if [[ $? = 0 ]]; then
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "rm -f /tmp/05102024/$nsvc.gz"
        else
                echo -e "\nCould not copy the file from the mongodb pod"
    fi
done
