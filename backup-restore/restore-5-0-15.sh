#!/bin/bash

## main

if kubectl get pods -n nirmata --no-headers | egrep -v 'mongo|zk|kafka' 1> /dev/null; then
        echo -e "\nPlease scale down non shared services before performing the restore\n"
        exit 1
fi

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

if [[ -z $MONGO_MASTER ]]; then
        echo "Unable to find the mongo master. Please check the mongo cluster. Exiting!"
        exit 1
fi

rm -f /tmp/restore-status.txt
touch /tmp/restore-status.txt

backupfolder=$1

# Get the list of all databases
mongodbs="Activity-nirmata Availability-cluster-hc-nirmata Availability-env-app-nirmata Catalog-nirmata Cluster-nirmata Config-nirmata Environments-nirmata Users-nirmata TimeSeries-nirmata"

# For each database
for db in $mongodbs; do

  # Copy the backup file to the MongoDB pod
  kubectl -n nirmata cp $backupfolder/${db}.gz $MONGO_MASTER:/tmp/${db}.gz -c mongodb

  # Connect to the MongoDB pod and restore the database

  kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongorestore --drop --gzip --db=${db} --archive=/tmp/${db}.gz --noIndexRestore -v"

  # Check the status of the restore
  if [ $? -eq 0 ]; then
    echo "Database ${db} restored successfully" | tee -a /tmp/restore-status.txt
  else
    echo "Database ${db} restore failed" | tee -a /tmp/restore-status.txt
  fi

  # Delete the backup file
  kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "rm -f /tmp/${db}.gz"

done