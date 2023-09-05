This script is used to backup mongodb databases using mongodump. To check the integrity of each backup, the dump file is restored to a test database and dbversion and object count are validated between the actual and test database before specific timestamp. Make sure to create "/tmp/backup-nirmata" folder on the node where you schedule this script as a crontab. 

