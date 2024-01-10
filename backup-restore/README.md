# MongoDB Backup and Restore Scripts

This folder contains two essential scripts to help manage MongoDB backups efficiently:

1. **backup-mongo.sh**: This script leverages `mongodump` to back up MongoDB databases. The integrity of each backup is verified by restoring the dump file to a test database. During this process, dbversion and object counts are compared between the actual database and the test database based on a specific timestamp. 
   
   Before you run this script, ensure that you create a `/tmp/backup-nirmata` folder on the node where you plan to run or schedule this script (potentially as a crontab job).
   
2. **restore.sh**: Utilizes `mongorestore` to restore all MongoDB databases. The script requires one argument: the path where all the dump files are stored.

3. **automate-restore.sh**: Streamlines the entire backup-restore workflow by automating processes, including scaling down replicas, capturing backups, utilizing backups for restoration, and subsequently scaling up all resources.

## Usage

### Backup
To back up the databases, use the following command:
```sh
./backup-mongo.sh
```
### Restore
To restore the databases, use the following command with the appropriate path:
```sh
./restore.sh <path_to_dump_files>
```

Note : For the above points, we need to scale down the replicas in nirmata namespace and scale up manually.

## Backup-Restore Automated Script.
Automate script execution and streamline resource scaling using : 
```sh
./automate-restore.sh
```
