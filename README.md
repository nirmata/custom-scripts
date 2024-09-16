# custom-scripts

Placeholder for custom Nirmata-Scripts

centos7script.sh - 
cleanup-cluster-agent.sh	- Script to clean-up node including nirmata-agent install after cluster deletion.
cleanup-cluster.sh	- Script to clean-up cluster state and configuration only.
k8_test.sh - verify cluster setup and nirmata install.
nadm-gui.sh	- nadm gui	
nirmata-agent-restart.sh - Script to clean restart nirmata-agent
nirmata-backup.sh - Backup script cron tab: runs every day at 3am and outputs log file

0 3 * * 0-6 /usr/bin/nirmata-backup.sh > /var/log/nirmatabackup.txt

