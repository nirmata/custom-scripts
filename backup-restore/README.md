# MongoDB Backup and Restore Scripts

This folder contains two essential scripts to help manage MongoDB backups efficiently:

1. **backup-mongo.sh**: This script leverages `mongodump` to back up MongoDB databases. The integrity of each backup is verified by restoring the dump file to a test database. During this process, dbversion and object counts are compared between the actual database and the test database based on a specific timestamp. 
   
   Before you run this script, ensure that you create a `/tmp/backup-nirmata` folder on the node where you plan to run or schedule this script (potentially as a crontab job).
   
2. **restore.sh**: Utilizes `mongorestore` to restore all MongoDB databases. The script requires one argument: the path where all the dump files are stored.

## Usage

### Backup
To back up the databases, use the following command:
```sh
./backup-mongo.sh <path_to_dump_files>
```
### Restore
To restore the databases, use the following command with the appropriate path 
use the nirmata-backups folder as path for the backup file to restore whic would be there in the backup folder:
```sh
./restore.sh <path_to_dump_files>
```