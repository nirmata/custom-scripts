#!/bin/bash

NAMESPACE="$1"
DATABASES="Catalog-${NAMESPACE} Cluster-${NAMESPACE} Config-${NAMESPACE} Environments-${NAMESPACE} Orchestrator-${NAMESPACE} Policies-${NAMESPACE} Users-${NAMESPACE}"

if [[ $# = 0 ]]; then
	echo
	echo "Usage: $0 <namespace>"
	echo
	exit 0
fi

echo

# List all mongo pods
mongos="mongodb-0 mongodb-1 mongodb-2"

for mongo in $mongos
do
    # Adjust the command below with authentication details if necessary
    cur_mongo=$(kubectl -n ${NAMESPACE} exec $mongo -c mongodb -- mongo --quiet --eval "printjson(rs.isMaster())" 2>&1)

    if echo "$cur_mongo" | grep -q '"ismaster" : true'; then
        mongo_master=$mongo
        break # Assuming you only need one master, exit loop after finding it
    fi
done

echo -e "Comparing the DBVersion of all the mongodb databases post upgrade with the expected values...\n"
for db in $DATABASES
do
        if [[ $db = Catalog-${NAMESPACE} ]]; then
		expect_dbversion=27
	elif [[ $db = Cluster-${NAMESPACE} ]]; then
		expect_dbversion=27
	elif [[ $db = Config-${NAMESPACE} ]]; then
                expect_dbversion=27
        elif [[ $db = Environments-${NAMESPACE} ]]; then
                expect_dbversion=27
        elif [[ $db = Orchestrator-${NAMESPACE} ]]; then
            	expect_dbversion=27
        elif [[ $db = Policies-${NAMESPACE} ]]; then
            	expect_dbversion=27
        elif [[ $db = Users-${NAMESPACE} ]]; then
            	expect_dbversion=27
	fi
        actual_dbversion=""
        actual_dbversion=$(kubectl -n ${NAMESPACE} exec ${mongo_master} -- bash -c "mongo --quiet ${db} --eval \"db.DBVERSION.find().forEach(printjson);\"" 2>&1 | grep version | tr -d '{}' | awk '{ print $NF }')

        # Check if the actual_dbversion was retrieved successfully
        if [[ -z "${actual_dbversion}" ]]; then
        	echo "Error: Failed to retrieve DB version for '${db}'."
        	continue
    	fi

	if [[ $actual_dbversion != $expect_dbversion ]]; then
		echo "DB version does not match the expected DB version for ${db}"
	fi
done

echo
