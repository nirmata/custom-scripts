#!/bin/bash
# Upgrading K8s Control plane to any next version
# Author:    Mustafa Challawala
# Repo:      https://github.com/nirmata/custom-scripts/tree/master/kubeadm-upgrade-script
# Create on: 2022-Sep-10


# NOTE: The upgrade procedure on control plane nodes should be executed one node at a time. Pick a control plane node that you wish to upgrade first.
# NOTE: Pass node name as parameter argument with script if Node name is mentioned different with Kubernetes. 

read -p "Enter kuberentes version which you want to upgrade to (example: 1.22.x): " VERSION

echo -e "Enter Boolean value true if you are upgrading Additional Control Plane Node / Worker Nodes...."
echo -e "Enter Boolean value false if you are upgrading 1st Control Plane Node / Primary Master Node...."

read -p "Enter (true/false):" IS_ADDITIONAL_CONTROL_PLANE

echo $VERSION, $IS_ADDITIONAL_CONTROL_PLANE

# Global variables
NODE_NAME=${1:-$HOSTNAME}
KUBEADM_VERSION=$VERSION
KUBELET_VERSION=$VERSION
KUBECTL_VERSION=${KUBELET_VERSION}


install_kubernetes_bineries(){
	if cat /etc/*release | grep ^NAME | grep CentOS; then
    echo "==============================================="
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION}  on CentOS"
    echo "==============================================="
    sudo yum install -y kubeadm-${KUBEADM_VERSION}-0 kubelet-${KUBELET_VERSION}-0 kubectl-${KUBECTL_VERSION}-0 --disableexcludes=kubernetes
 elif cat /etc/*release | grep ^NAME | grep Red; then
    echo "==============================================="
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION} on RedHat"
    echo "==============================================="
    sudo yum install -y kubeadm-${KUBEADM_VERSION}-0 kubelet-${KUBELET_VERSION}-0 kubectl-${KUBECTL_VERSION}-0 --disableexcludes=kubernetes
 elif cat /etc/*release | grep ^NAME | grep Fedora; then
    echo "================================================"
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION} on Fedorea"
    echo "================================================"
    sudo yum install -y kubeadm-${KUBEADM_VERSION}-0 kubelet-${KUBELET_VERSION}-0 kubectl-${KUBECTL_VERSION}-0 --disableexcludes=kubernetes
 elif cat /etc/*release | grep ^NAME | grep Ubuntu; then
    echo "==============================================="
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION} on Ubuntu"
    echo "==============================================="
    apt-mark unhold kubeadm kubelet kubectl && apt-get update
    apt-get install -y kubeadm=${KUBEADM_VERSION}-00 kubelet=${KUBELET_VERSION}-00 kubectl=${KUBECTL_VERSION}-00
    apt-mark hold kubeadm kubelet kubectl
 elif cat /etc/*release | grep ^NAME | grep Debian ; then
    echo "==============================================="
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION} on Debian"
    echo "==============================================="
    apt-mark unhold kubeadm kubelet kubectl && apt-get update
    apt-get install -y kubeadm=${KUBEADM_VERSION}-00 kubelet=${KUBELET_VERSION}-00 kubectl=${KUBECTL_VERSION}-00
    apt-mark hold kubeadm kubelet kubectl
 elif cat /etc/*release | grep ^NAME | grep Mint ; then
    echo "============================================="
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION} on Mint"
    echo "============================================="
    apt-mark unhold kubeadm kubelet kubectl && apt-get update
    apt-get install -y kubeadm=${KUBEADM_VERSION}-00 kubelet=${KUBELET_VERSION}-00 kubectl=${KUBECTL_VERSION}-00
    apt-mark hold kubeadm kubelet kubectl
 elif cat /etc/*release | grep ^NAME | grep Knoppix ; then
    echo "================================================="
    echo "Installing packages kubeadm-${KUBEADM_VERSION}, kubelet-${KUBELET_VERSION}, kubectl-${KUBECTL_VERSION} on Kanoppix"
    echo "================================================="
    apt-mark unhold kubeadm kubelet kubectl && apt-get update
    apt-get install -y kubeadm=${KUBEADM_VERSION}-00 kubelet=${KUBELET_VERSION}-00 kubectl=${KUBECTL_VERSION}-00
    apt-mark hold kubeadm kubelet kubectl
 else
    echo "OS NOT DETECTED, couldn't install packages"
    exit 1;
 fi
}

execute_upgrade(){
	echo "==============================================="
	echo -e "\e[1;32m Starting upgrade...\n"
	echo "==============================================="

	# Draining control plane. Prepare the node for maintenance by marking it unschedulable and evicting the workloads
	# You have to enter your node name as a parameter when invoking the script, otherwise it will use the value of HOSTNAME environment variable
	echo "==============================================="
	echo -e ">\e[1;32m Draining control plane \e[1m${NODE_NAME}\e[0m \n"
	echo "==============================================="
	sudo kubectl drain ${NODE_NAME} --ignore-daemonsets
	echo
	#
	# Upgrading Kubeadm and showing the new version
	echo "==============================================="
	echo -e ">\e[1;32m Installing Bineries ...\n"
	echo "==============================================="
	install_kubernetes_bineries
	#sudo yum install -y kubeadm-${KUBEADM_VERSION}-0 kubelet-${KUBELET_VERSION}-0 kubectl-${KUBECTL_VERSION}-0 --disableexcludes=kubernetes
	#echo  "Upgraded to version: `sudo kubeadm version`"
	echo
	#
	# Verifying upgrade plan
	echo "==============================================="
	echo -e ">\e[1;32m Checking upgrade plan...\n"
	echo "==============================================="
	sudo kubeadm upgrade plan "v${KUBEADM_VERSION}"
	#
	# Pulling Images
	echo "==============================================="
	echo -e ">\e[1;32m Pulling Images...\n"
	echo "==============================================="
	sudo kubeadm config images pull
	echo
	if [ "$IS_ADDITIONAL_CONTROL_PLANE" = "true" ]; then
		#
		# Applying the upgrade
		echo "==============================================="
		echo -e ">\e[1;32m Aplying the upgrade on Additional Control Plane \ Worker Nodes...\n"
		echo "==============================================="
		sudo kubeadm upgrade node
		echo
	elif [ "$IS_ADDITIONAL_CONTROL_PLANE" = "false" ]; then
		#
		# Applying the upgrade
		echo "==============================================="
		echo -e ">\e[1;32m Aplying the upgrade with automatic certificate renewal...\n"
		echo "==============================================="
		sudo kubeadm upgrade apply "v${KUBEADM_VERSION}" --yes
		echo
	else
		echo -e "Enter Boolean value true if you are upgrading Additional Control Plane Node...."
		echo -e "Enter Boolean value false if you are upgrading 1st Control Plane Node...."
		echo -e "Note: This Script is not used to upgrade worker Nodes....."
    	exit;
	fi
	#
	# Restarting the kubelet
	sudo systemctl daemon-reload && sudo systemctl restart kubelet
	echo -e ">\e[1;32m Daemon reloaded and kubelet restarted\n"
	#
	# Uncordoning the node
	echo -e ">\e[1;32m Bring the node back online by marking it schedulable...\n"
	kubectl uncordon ${NODE_NAME}

	#
	echo -e "\n \e[1;32m Control plane ${HOSTNAME} \e[32msuccessfuly\e[0m upgraded\n"
}

if [ -z $VERSION -a -z $IS_ADDITIONAL_CONTROL_PLANE ]
  then
  	echo -e ">Enter kuberentes version which you want to upgrade to...."
  	echo -e ">Enter Boolean value true if you are upgrading Additional Control Plane Node/ Worker Nodes...."
		echo -e ">Enter Boolean value false if you are upgrading 1st Control Plane Node...."
    exit;
else
	echo "==============================================="
	read -p ">\e[93mWants to Start upgrade.... (y/n)?" choice
	case "$choice" in 
  	y|Y ) 
			execute_upgrade
			;;
  	n|N ) 
			echo -e ">\e[1;91mCanceled upgrade" 
			exit 1
			;;
  	* ) 
			echo "invalid"
			exit 1
			;;
	esac	
fi
