# custom-scripts

Placeholder for custom Nirmata-Scripts

Backup script cron tab: runs every day at 3am and outputs log file

0 3 * * 0-6 /usr/bin/nirmata-backup.sh > /var/log/nirmatabackup.txt

