#!/bin/bash

#set -x


showcollectionscount() {

#unix_timestamp=$(($(date +%s%N)/1000000))

cat << EOF > commands_${1}.js
use $1
var timestamp = $unix_timestamp;
db.getCollectionNames().forEach(function(col) {
var size = db[col].find({"createdOn":{\$lt:timestamp}}).count();
print(col+":"+size);
})
EOF


}


getdb_version() {

cat << EOF > dbVersion_${1}.js
use $1
db.DBVERSION.find()
EOF

}

drop_db() {

cat << EOF > dropdb_${1}.js
use $1
db.dropDatabase()
EOF

}

## main
#input location of backup
backup_location=$1

# List all mongo pods
mongos="mongodb-0 mongodb-1 mongodb-2"

for mongo in $mongos
do
    # Adjust the command below with authentication details if necessary
    cur_mongo=$(kubectl -n nirmata exec $mongo -c mongodb -- mongo --quiet --eval "printjson(rs.isMaster())" 2>&1)

    if echo "$cur_mongo" | grep -q '"ismaster" : true'; then
        echo "$mongo is master"
        mongo_master=$mongo
        break # Assuming you only need one master, exit loop after finding it
    fi
done

if [ -n "$mongo_master" ]; then
    echo "The primary MongoDB replica is: $mongo_master"
else
    echo "No primary MongoDB replica found."
    exit 1 # It seems this exit was intended to be here to halt the script if no master is found.
fi

MONGO_MASTER=$mongo_master

NIRMATA_SERVICES="Activity-nirmata Availability-cluster-hc-nirmata Availability-config-env-nirmata Availability-env-app-nirmata Catalog-nirmata Cluster-nirmata Config-nirmata Environments-nirmata Users-nirmata TimeSeries-nirmata"
# NIRMATA_SERVICES="Activity-nirmata"

NIRMATA_HOST_BACKUP_FOLDER=/tmp/backup-nirmata
NIRMATA_POD_BACKUP_FOLDER=/tmp/nirmata-backups

kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- mkdir -p $NIRMATA_POD_BACKUP_FOLDER
kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- rm -rf $NIRMATA_POD_BACKUP_FOLDER/*
kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- mkdir -p $NIRMATA_POD_BACKUP_FOLDER/logs
kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- touch $NIRMATA_POD_BACKUP_FOLDER/logs/backup-status.log

# convert current date into unix time.
unix_timestamp=$(($(date +%s%N)/1000000))

mkdir -p $NIRMATA_HOST_BACKUP_FOLDER/$(date +%m-%d-%y)/$(date +"%H-%M")

BACKUP_DIR="$NIRMATA_HOST_BACKUP_FOLDER/$(date +%m-%d-%y)/$(date +"%H-%M")"

#echo $unix_timestamp

for nsvc in $NIRMATA_SERVICES
do
        echo
        echo "-------------------------------------------------------"
        echo "Backing up $nsvc db using mongodump"
        echo "-------------------------------------------------------"
        echo
        kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- touch $NIRMATA_POD_BACKUP_FOLDER/logs/${nsvc}_backup.log
        sleep 2
        kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongodump --gzip --db=$nsvc --archive=$NIRMATA_POD_BACKUP_FOLDER/$nsvc.gz 2>&1 | tee -a $NIRMATA_POD_BACKUP_FOLDER/logs/${nsvc}_backup.log"
        if [[ $? != 0 ]]; then
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "echo \"Could not backup $nsvc database on $(date)\" | tee -a $NIRMATA_POD_BACKUP_FOLDER/logs/backup-status.log"
        else
                echo
                file1=""
                file2=""
                file3=""
                file4=""

                file1="$BACKUP_DIR/${nsvc}_objcount.txt"
                file2="$BACKUP_DIR/${nsvc}-test_objcount.txt"
                file3="$BACKUP_DIR/${nsvc}_dbVersion.txt"
                file4="$BACKUP_DIR/${nsvc}-test_dbVersion.txt"

                showcollectionscount $nsvc
                kubectl -n nirmata cp commands_${nsvc}.js $MONGO_MASTER:/tmp/ -c mongodb

                getdb_version $nsvc
                kubectl -n nirmata cp dbVersion_${nsvc}.js $MONGO_MASTER:/tmp/ -c mongodb

                echo
                echo "-------------------------------------------------------------------------"
                echo "Displaying collection count for ${nsvc} database                         "
                echo "-------------------------------------------------------------------------"
                echo
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongo --quiet < /tmp/commands_${nsvc}.js" | grep -v "switched to db ${nsvc}" > $file1
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongo --quiet < /tmp/dbVersion_${nsvc}.js" | grep -v "switched to db ${nsvc}" > $file3
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongorestore --drop --gzip --archive=$NIRMATA_POD_BACKUP_FOLDER/$nsvc.gz --nsFrom "${nsvc}.*" --nsTo "${nsvc}-test.*" --noIndexRestore --nsInclude "${nsvc}.*""

                showcollectionscount ${nsvc}-test
                kubectl -n nirmata cp commands_${nsvc}-test.js $MONGO_MASTER:/tmp/
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongo --quiet < /tmp/commands_${nsvc}-test.js" | grep -v "switched to db ${nsvc}-test" > $file2
                #echo
                #echo "-------------------------------------------------------------------------"
                #echo "Displaying collection count for ${nsvc}-test database                    "
                #echo "-------------------------------------------------------------------------"
                #echo


                getdb_version ${nsvc}-test
                kubectl -n nirmata cp dbVersion_${nsvc}-test.js $MONGO_MASTER:/tmp/ -c mongodb
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongo --quiet < /tmp/dbVersion_${nsvc}-test.js" | grep -v "switched to db ${nsvc}-test" > $file4

                drop_db ${nsvc}-test
                kubectl -n nirmata cp dropdb_${nsvc}-test.js $MONGO_MASTER:/tmp/ -c mongodb
                kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "mongo --quiet < /tmp/dropdb_${nsvc}-test.js"


                diff_output="$(diff --brief "$file1" "$file2")"

                # check if there's any output from the diff command
                if [ -n "$diff_output" ]; then
                        echo "There is a difference between the files. The backup file could be corrupted as the file count between the ${nsvc} and the ${nsvc}-test databases does not match before and after " >> $BACKUP_DIR/dbvrsn_objcnt.log
                fi

                diff_output2="$(diff --brief "$file3" "$file4")"

                # check if there's any output from the diff command
                if [ -n "$diff_output2" ]; then
                        echo "The dbVersion does not seem to match between the the ${nsvc} and the ${nsvc}-test databases" >> $BACKUP_DIR/dbvrsn_objcnt.log
                fi



        fi
done

kubectl -n nirmata exec $MONGO_MASTER -c mongodb -- sh -c "cd /tmp; tar cvf nirmata-backups.tar nirmata-backups/"

kubectl -n nirmata cp $MONGO_MASTER:/tmp/nirmata-backups.tar -c mongodb $BACKUP_DIR/nirmata-backups.tar

tar -xvf $BACKUP_DIR/nirmata-backups.tar -C $BACKUP_DIR

# echo "nirmata-backups.tar extracted to: $BACKUP_DIR/nirmata-backups at $(date)" > nirmata_backup_directory_path_details.txt

kubectl -n nirmata cp $MONGO_MASTER:$NIRMATA_POD_BACKUP_FOLDER/logs/backup-status.log -c mongodb $BACKUP_DIR/backup-status.log

mv *.js /tmp


# Copy over the contents.
cp -r $NIRMATA_HOST_BACKUP_FOLDER/* "$backup_location"
# Remove the source directory after successful copy.
rm -rf $NIRMATA_HOST_BACKUP_FOLDER