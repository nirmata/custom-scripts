# mongodb cleanup script


Prerequisites

Before running the script, ensure that you have the following:

MongoDB installed and configured.

Proper permissions to access the specified health_check_script nadm_directory and backup_directory.


First create one empty dir on the machine which can be use as backup_directory.

```
mkdir backup_db
cd backup_db
ls -lrth
mv -r * /tmp
```

Now go back to your path of the script



Path of script = ./mongodb-cleanup.sh

Path of health check script = health_script_path

Path of nadm directory = nadm_directory

Path of backup_directory = backup_directory

```
Example Usage: ./mongodb-cleanup.sh health_script_path nadm_directory backup_directory
```