#!/bin/bash
# nadm backup & restart
# 11.2.2018 Brandon Pendleton
# Nirmata

PS3='Please enter your choice: '
options=("Backup Nirmata" "Restart Nirmata Agents" "Quit")
select opt in "${options[@]}"
do
    case $opt in
        "Backup Nirmata")
            echo 'Please input the directory in which we want to backup to ie.) /backup/nirmata'
            read -r vardirectory
            echo The backup will go to "$vardirectory"
            set -x
            ./nadm backup -d "$vardirectory" -n namespace
            set +x
            ;;
        "Restart Nirmata Agents")
            set -x
            kubectl delete pod -n nirmata $(kubectl get pods -n nirmata|grep nirmata-agent |awk '{print $1}')
            set +x
            echo "You've restarted the Nirmata Agents"
            ;;
        "Quit")
            break
            ;;
        *) echo "invalid option $REPLY";;
    esac
done