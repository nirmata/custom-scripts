#!/usr/bin/bash

## function to check and install jq based on the ostype

installjq() {

        # Check the operating system
        if [[ "$(uname)" == "Darwin" ]]; then
                # Mac OS X
                brew install jq
        elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
                # Linux
                if [[ -n "$(command -v yum)" ]]; then
                        # CentOS, RHEL, Fedora
                        sudo yum install epel-release -y
                        sudo yum install -y jq
                elif [[ -n "$(command -v apt-get)" ]]; then
                        # Debian, Ubuntu, Mint
                        sudo apt-get update
                        sudo apt-get install -y jq
                elif [[ -n "$(command -v zypper)" ]]; then
                        # OpenSUSE
                        sudo zypper install -y jq
                elif [[ -n "$(command -v pacman)" ]]; then
                        # Arch Linux
                        sudo pacman -S --noconfirm jq
                else
                        echo "Error: Unsupported Linux distribution."
                        exit 1
                fi
        else
                echo "Error: Unsupported operating system."
                exit 1
        fi

        # Print the version of jq installed
        jq --version

        if [[ ! -n "$(command -v jq)" ]]; then
                echo -e "\nUnable to install jq. Exiting!\n"
                exit 1
        fi

}

## main

if [[ -n "$(command -v jq)" ]]; then
    echo
    #echo "jq is installed."
    #jq --version
else
    echo -e "\njq is not installed. Installing jq ...\n"
    installjq
fi

if [[ $# != 2 ]]; then
        echo -e "\nUsage: \t$0 <cluster-name> <Nirmata URL>\n"
        echo -e "Example: $0 demo-cluster https://nirmata.io"
        exit 1
fi

CLUSTERNAME=$1

NIRMATAURL=$2

KUBELETARGS=$3

echo -e "\nEnter the Nirmata API token: \n"
read -s TOKEN


CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" 2>&1 | jq ".[] | select( .name == \"$CLUSTERNAME\" ).id" 2> /dev/null | sed "s/\"//g")

if [[ -z $CLUSTERID ]]; then
        echo -e "Unable to get the clusterid from Nirmata. Make sure the clustername or token provided is correct\n"
        exit 1
fi

#echo "CLUSTERID: $CLUSTERID"

CLUSTERENV=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster/$CLUSTERID/clusterEnvironment" | jq -r .clusterEnvironment.id)

#echo "CLUSTERENV: $CLUSTERENV"


CLUSTERENV_VAR=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/config/api/environment/$CLUSTERENV/environmentVariables" 2>&1 | jq ".[] | select( .key == \"KUBELET_ARGS\" ).id" | sed "s/\"//g")


curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/config/api/environments?fields=id,desiredServices,environmentHostCluster" | jq -r ".[] | select(.environmentHostCluster.id == \"$CLUSTERID\").desiredServices[].id" > desiredserviceids.txt

for dsid in $(cat desiredserviceids.txt)
do

        temp1=""
        desiredsvcname=""
        desirdsvcid=""
        temp1=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/config/api/DesiredService" | jq -r ".[] | select(.id == \"$dsid\").name")
        count=$(echo $temp1 | grep kubelet | wc -l)
        if [[ $count != 0 ]]; then
                desiredsvcname="$temp1"
                #echo "desiredsvcname: $desiredsvcname"
                desirdsvcid=$dsid
                #echo "desirdsvcid: $desirdsvcid"
                break
        fi
done

VALUE_TEMP=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/config/api/environment/$CLUSTERENV/environmentVariables?fields=value,id,key" 2>&1 | jq ".[] | select( .key == \"KUBELET_ARGS\" ).value" | sed "s/\"//g")

count1=$(echo $VALUE_TEMP | grep docker | wc -l)
count2=$(echo $VALUE_TEMP | grep containerd.sock | wc -l)
count3=$(echo $VALUE_TEMP | grep cgroupfs | wc -l)
count4=$(echo $VALUE_TEMP | grep systemd | wc -l)

if [[ $count1 != 0 ]]; then
        VALUE_TEMP=$(echo $VALUE_TEMP | sed 's/docker/remote/g')
        #echo $VALUE_TEMP
fi

if [[ $count2 != 0 ]]; then
        echo
else
        VALUE_TEMP="$VALUE_TEMP --container-runtime-endpoint=unix:///run/containerd/containerd.sock"
        #echo $VALUE_TEMP
fi

if [[ $count3 != 0 ]]; then
        VALUE_TEMP=$(echo $VALUE_TEMP | sed 's/cgroupfs/systemd/g')
        #echo $VALUE_TEMP
elif [[ $count4 != 0 ]]; then
        echo
else
        VALUE_TEMP="$VALUE_TEMP --cgroup-driver=systemd"
        #echo $VALUE_TEMP
fi

#echo "----------------------------------------"
#echo "          Kubelet Arguments"
#echo "----------------------------------------"
#echo
#echo $VALUE_TEMP
#echo

curl -s -o /dev/null -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/config/api/txn" -d "

{
  \"create\": [],
  \"update\": [
    {
      \"services\": [
        \"$desiredsvcname\"
      ],
      \"key\": \"KUBELET_ARGS\",
      \"value\": \"$VALUE_TEMP\",
      \"id\": \"$CLUSTERENV_VAR\",
      \"modelIndex\": \"EnvironmentVariable\",
      \"parent\": {
        \"id\": \"$CLUSTERENV\",
        \"service\": \"Config\",
        \"modelIndex\": \"Environment\",
        \"childRelation\": \"environmentVariables\"
      }
    }
  ],
  \"delete\": []
}"

if [[ $? = 0 ]]; then
        echo -e "Kubelet arguments updated successfully"
        echo "----------------------------------------"
        echo "          Kubelet Arguments"
        echo "----------------------------------------"
        echo $VALUE_TEMP
        echo
        sleep 30
        #echo "Do you want to restart all the kubelets (Say yes or no)?"
        read -p "Do you want to restart all the kubelets (Say yes or no)?" response
        #read response
        if [[ $response = yes ]]; then

                echo "Redeploying Kubelet service"
                curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X POST "$NIRMATAURL/config/api/txn" -d "

                {
                \"create\": [
                        {
                        \"modelIndex\": \"DesiredServiceAction\",
                        \"parent\": \"$desirdsvcid\",
                        \"actionType\": \"redeploy\"
                        }
                ],
                \"update\": [],
                \"delete\": []
                }" 1> /dev/null

                if [[ $? = 0 ]]; then
                        echo -e "Kubelet service redeployed\n."
                else
                        echo -e "Something went wrong while redeploying the Kubelet service."
                fi
                exit 0
        elif [[ $response = no ]]; then
                echo -e "Exiting without restarting kubelets\n"
                exit 0
        else
                echo -e "Invalid response. Please respond say or no to the question above!\n"
                exit 1
        fi

else
        echo "Something went wrong. Failed to update the kubelet arguments in Nirmata"
fi
