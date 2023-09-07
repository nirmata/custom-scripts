This folder consists of 2 scripts. backup-mongo.sh script is used to backup mongodb databases using mongodump. To check the integrity of each backup, the dump file is restored to a test database and dbversion and object counts are compared between the actual database and the test database at a specific timestamp. Before running this script, make sure to create "/tmp/backup-nirmata" folder on the node where you run/schedule this script (as a crontab). The restore.sh is used to restore all the mongo databases  using mongorestore. The script takes one argument which is the path where all the dump files are stored. 

Usage: 
To backup the databases, execute backup-mongo.sh script as follows
./backup-mongo.sh

To restore the databases, execute restore.sh script as follows
./restore.sh <path-to-dump-files>


