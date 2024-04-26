# MongoDB Backup and Restore Scripts

This folder contains two essential scripts to help manage MongoDB backups efficiently:

1. **backup-mongo.sh**: This script leverages `mongodump` to back up MongoDB databases. The integrity of each backup is verified by restoring the dump file to a test database. During this process, dbversion and object counts are compared between the actual database and the test database based on a specific timestamp. 
   
   Before you run this script, ensure that you create a `/tmp/backup-nirmata` folder on the node where you plan to run or schedule this script (potentially as a crontab job).
   
2. **restore.sh**: Utilizes `mongorestore` to restore all MongoDB databases. The script requires one argument: the path where all the dump files are stored.

3. **backup-mongo-5-0-15.sh**: Similar to backup-mongo.sh but this script is used after upgrading Mongodb to 5.0.15 but while running the script, from now on mention the path as well to store the backup.
   
4. **restore-5-0-15.sh**: Similar to restore.sh but this script is used after upgrading Mongodb to 5.0.15

5. **backup-4-20-4.sh**: Like the backup scripts previously discussed, this script also specifies the path for storing backups. However, it is specifically designed to back up the additional databases, Policies-nirmata and TimeSeries-Metrics-nirmata, following the upgrade to Nirmata 4.20.4.
   
6. **restore-4-20-4.sh**: Similar to the restore scripts mentioned but this is used to restore the additional databases *Policies-nirmata* and *TimeSeries-Metrics-nirmata* after upgrading Nirmata to 4.20.4



## Usage

### Backup
To back up the databases, use the following command:
```sh
./backup-mongo.sh
```

To back up the databases (Mongodb 5.0.15) and mention the path as well to store the backup, use the following command:
```sh
./backup-mongo-5-0-15.sh <path_to_dump_files>
```

To back up the databases (Nirmata 4.20.4) and mention the path as well to store the backup, use the following command:
```sh
./backup-4-20-4.sh <path_to_dump_files>
```



### Restore
To restore the databases, use the following command with the appropriate path:
```sh
./restore.sh <path_to_dump_files>
```

To restore the databases (Mongodb 5.0.15), use the following command with the appropriate path:
```sh
./restore-4-20-4.sh <path_to_dump_files>
```

To restore the databases (Nirmata 4.20.4), use the following command with the appropriate path:
```sh
./restore-5-0-15.sh <path_to_dump_files>
```