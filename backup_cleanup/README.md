# Backup Cleanup via  Bash Script

### This Script will help you to remove all the backup files older than 30 days in a particular directory.

#### NOTE: 
    - This script works only on RPM and Debian flavors.
    - Currently, Script asks/prompts for the Backup files directory path to remove the backup files older than 30 day

#### Pre-requisite:-
    - To run the script you need to give the Backup files directory path where the files are stored. So keep the backup directory path handy.

#### Steps:
1. Clone/Download Script from the repo.\
    `git clone https://github.com/nirmata/custom-scripts.git `
2.  navigate to backup_cleanup folder\
    `cd custom-scripts/backup_cleanup`
3.  add execute permission to the script.\
    `chmod +x backup_cleanup.sh`
4.  run the script.
        `./backup_cleanup.sh`

