#!/bin/bash

#Location for backups to be stored
backup_dir=/apps/nirmata/backup/dev
#Location for backup script located
backup_script=/backup-mongo.sh


$backup_script $backup_dir 
#find  $backup_dir -mtime +90 -exec rm -rf  {} \;

cd $backup_dir
file=$(ls -Art | tail -n 1)
timestamp="$(stat -c %Y "$file")"
f_dt="$(date -d "@$timestamp" "+%Y-%m-%d")"
#f_dt="$(echo "$file"|grep -Eo "[0-9]{4}\-[0-9]{2}\-[0-9]{2}")"
echo $f_dt

s_dt="$( date +%Y-%m-%d )"

echo $s_dt
f_size="$(du -sh * |awk '{print $1}' | | tail -n 1)"
echo $f_size

if [ "$f_dt" = "$s_dt" ]
then
    echo "Hi, Backup is successfull on zephyr Dev. Backup name is $file and size is $f_size" 

else
    echo "Hi, Backup is failed. Either backup is corrupted or backup file is not available for today. Please look into the case" 
fi
#Run below command under crontab -e
#00 01 * * * /apps/nirmata/nirmata_cronjobs/nirmata-backup.sh > /tmp/nirmata_backup.log 2>&1
#You can update the script with the emails as well.