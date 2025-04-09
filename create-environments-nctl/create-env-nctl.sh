$ cat create-environment-nctl.sh
#!/usr/bin/bash

# Update the location of the csv file below
# filename='/c/Users/Sagar/Downloads/csv/create-env-nctl.csv'
filename=''
cat $filename | grep -v environment-name > tempfile.txt


COUNT=$(which nctl 2> /dev/null| wc -l)
if [[ $COUNT != 1 ]]; then
        echo -e "\nnctl not installed. Please install nctl and try again. Exiting ..."
#       echo -e "nctl can be downloaded from https://downloads.nirmata.io/nctl/allreleases/"
        exit 1
fi

echo -e "\nEnter the Nirmata API token: "
read -s TOKEN


for line in $(cat tempfile.txt);
do
        #set -x
        CLUSTER_NAME=$(echo $line | cut -d "," -f 3)
        ENVIRONMENT_NAME=$(echo $line | cut -d "," -f 1)
        ENVIRONMENT_TYPE=$(echo $line | cut -d "," -f 2)
        NIRMATA_URL=$(echo $line | cut -d "," -f 4)
        #echo -e "CLUSTER_NAME: $CLUSTER_NAME\nENVIRONMENT_NAME: $ENVIRONMENT_NAME\nENVIRONMENT_TYPE: $ENVIRONMENT_TYPE"
        ENV_COUNT=$(nctl environments get --token "$TOKEN" --url https://$NIRMATA_URL | grep -w $ENVIRONMENT_NAME | awk '{print $1}')
        if [[ ! -n $ENV_COUNT ]]; then
                nctl environments create $ENVIRONMENT_NAME --cluster $CLUSTER_NAME --type $ENVIRONMENT_TYPE --url https://$NIRMATA_URL --token "$TOKEN" 1> /dev/null
                if [[ $? = 0 ]]; then
                        echo "environment \"$ENVIRONMENT_NAME\" created successfully"
                else
                        echo "Something went wrong when creating \"$ENVIRONMENT_NAME\" environment. Please check"
                fi
        else
                echo "The environment \"$ENVIRONMENT_NAME\" already exists"
        fi
done
