#!/bin/bash

installjq() {

        # Check the operating system
        if [[ "$(uname)" == "Darwin" ]]; then
                # Mac OS X
                brew install jq
        elif [[ "$(expr substr $(uname -s) 1 5)" == "Linux" ]]; then
                # Linux
                if [[ -n "$(command -v yum)" ]]; then
                        # CentOS, RHEL, Fedora
                        sudo yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
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
}

if [[ -n "$(command -v jq)" ]]; then
    echo "jq is installed."
    jq --version
else
    echo -e "\njq is not installed. Installing jq ...\n"
    installjq
    echo "jq is installed successfully"
fi

if [ $# -lt 5 ]; then
    echo "Usage: $0 kubeconfig clustername Nirmata-API-Token Nirmata-URL namespace1 [namespace2 ...]"
    echo ""
    echo "* kubeconfig: Absolute path of kubeconfig file for the cluster"
    echo "* clustername: Cluster name in Nirmata UI"
    echo "* Nirmata-API-Token: Token for accessing the Nirmata API"
    echo "* Nirmata-URL: URL of the Nirmata API"
    echo "* namespace1: Name of the first namespace to be cleaned up (e.g., 'kyverno')"
    echo "* namespace2...: Names of the additional namespaces to be cleaned up"
    echo ""
    echo "Eg: $0 /home/user/.kube/config test-cluster <Nirmata-API-Token> https://www.nirmata.io  nirmata-kyverno-operator kyverno nirmata"
    echo "Warning"
else
    kubeconfig=$1
    CLUSTERNAME=$2
    TOKEN=$3
    NIRMATAURL=$4
    CLUSTERID=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster?fields=id,name" | jq -r ".[] | select(.name == \"$CLUSTERNAME\").id")
    shift 4
    namespaces=("$@")

    echo "Cleaning up Kyverno from the cluster"
    echo "==================================================="

    for namespace in "${namespaces[@]}"; do
        echo "Deleting resources in namespace: $namespace"

    echo "==================================================="

        # Uninstall best-practice-policies chart
        echo "Uninstalling best-practice-policies chart..."
        helm uninstall best-practice-policies -n default

        # Uninstall pod-security-policies chart
        echo "Uninstalling pod-security-policies chart..."
        helm uninstall pod-security-policies -n default

        # Uninstall kyverno chart
        echo "Uninstalling kyverno chart..."
        helm uninstall kyverno -n kyverno

        # Delete policyset resources with retries
        echo "Deleting policyset resources"
        retries=0
        while [[ $(kubectl --kubeconfig="$kubeconfig" get policyset -n "$namespace" -o name) && $retries -lt 3 ]]; do
            kubectl --kubeconfig="$kubeconfig" delete policyset --all --force --grace-period=0 -n "$namespace"
            sleep 5
            ((retries++))
        done

        if [[ $(kubectl --kubeconfig="$kubeconfig" get policyset -n "$namespace" -o name) ]]; then
            echo "Failed to delete policyset resources in namespace '$namespace'."
            exit 1
        fi
        echo "Deleted policyset resources in namespace '$namespace'"

        echo "Remaining policyset resources:"
        kubectl --kubeconfig="$kubeconfig" get policyset -n "$namespace" -o name || echo "No resources found."

        echo "==================================================="



    # Delete clusterpolicy resources with retries
        echo "Deleting clusterpolicy resources"
        retries=0
        while [[ $(kubectl --kubeconfig="$kubeconfig" get clusterpolicy -n "$namespace" -o name) && $retries -lt 3 ]]; do
            kubectl --kubeconfig="$kubeconfig" delete clusterpolicy --all --force --grace-period=0 -n "$namespace"
            sleep 5
            ((retries++))
        done

        if [[ $(kubectl --kubeconfig="$kubeconfig" get clusterpolicy -n "$namespace" -o name) ]]; then
            echo "Failed to delete clusterpolicy resources in namespace '$namespace'."
            exit 1
        fi
        echo "Deleted clusterpolicy resources in namespace '$namespace'"

        echo "Remaining clusterpolicy resources:"
        kubectl --kubeconfig="$kubeconfig" get clusterpolicy -n "$namespace" -o name || echo "No resources found."


    echo "==================================================="


        # Delete CustomResourceDefinitions 
        echo "Deleting CustomResourceDefinitions"
        crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "nirmata.security.io")
        echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch  {} -p '{"metadata":{"finalizers":[]}}' --type=merge
        # echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch  {} -p '{"spec":{"finalizers":[]}}' --type=merge
        retries=0
        while [[ -n $crds && $retries -lt 3 ]]; do
            echo "$crds" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
            sleep 5
            crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i  "nirmata.security.io")
            ((retries++))
        done
        if [[ -n $crds ]]; then
            echo "Failed to delete CustomResourceDefinitions in namespace '$namespace'."
            exit 1
        fi
        echo "Remaining CustomResourceDefinitions:"
        kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i  "nirmata.security.io" || echo "No resources found."

    echo "==================================================="


        # Delete CustomResourceDefinitions 
        echo "Deleting CustomResourceDefinitions"
        crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "$namespace")
        echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch  {} -p '{"metadata":{"finalizers":[]}}' --type=merge
        # echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch  {} -p '{"spec":{"finalizers":[]}}' --type=merge
        retries=0
        while [[ -n $crds && $retries -lt 3 ]]; do
            echo "$crds" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
            sleep 5
            crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "$namespace")
            ((retries++))
        done
        if [[ -n $crds ]]; then
            echo "Failed to delete CustomResourceDefinitions in namespace '$namespace'."
            exit 1
        fi
        echo "Remaining CustomResourceDefinitions:"
        kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "$namespace" || echo "No resources found."

    echo "==================================================="

        # Delete kyverno CustomResourceDefinitions 
        echo "Deleting kyverno CustomResourceDefinitions"
        crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "kyverno")
        echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge
        # echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch {} -p '{"spec":{"finalizers":[]}}' --type=merge
        retries=0
        while [[ -n $crds && $retries -lt 3 ]]; do

            echo "$crds" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
            sleep 5
            crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "kyverno")
            ((retries++))
        done
        if [[ -n $crds ]]; then
            echo "Failed to delete CustomResourceDefinitions in namespace 'kyverno'."
            exit 1
        fi
        echo "Remaining CustomResourceDefinitions:"
        kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "kyverno" || echo "No resources found."

    echo "==================================================="

        # Delete wgpolicy CustomResourceDefinitions 
        echo "Deleting wgpolicy CustomResourceDefinitions"
        crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "wgpolicy")
        echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch {} -p '{"metadata":{"finalizers":[]}}' --type=merge
        # echo "$crds" | xargs -I {} kubectl --kubeconfig="$kubeconfig" patch {} -p '{"spec":{"finalizers":[]}}' --type=merge
        retries=0
        while [[ -n $crds && $retries -lt 3 ]]; do

            echo "$crds" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
            sleep 5
            crds=$(kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "wgpolicy")
            ((retries++))
        done
        if [[ -n $crds ]]; then
            echo "Failed to delete CustomResourceDefinitions in namespace 'wgpolicy'."
            exit 1
        fi
        echo "Remaining CustomResourceDefinitions:"
        kubectl --kubeconfig="$kubeconfig" get customresourcedefinition -o name | grep -i "wgpolicy" || echo "No resources found."

    echo "==================================================="

        # Delete ClusterRoles
        echo "Deleting ClusterRoles"
        cluster_roles=$(kubectl --kubeconfig="$kubeconfig" get clusterrole -o name | grep -i "$namespace")
        if [[ -n $cluster_roles ]]; then
            echo "ClusterRoles found. Deleting..."
            retries=0
            while [[ -n $cluster_roles && $retries -lt 3 ]]; do
                echo "$cluster_roles" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                cluster_roles=$(kubectl --kubeconfig="$kubeconfig" get clusterrole -o name | grep -i "$namespace")
                ((retries++))
            done
            if [[ -n $cluster_roles ]]; then
                echo "Failed to delete ClusterRoles in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted ClusterRoles in namespace '$namespace'"
        else
            echo "Skipping ClusterRole deletion. No ClusterRoles found in namespace '$namespace'."
        fi
        echo "Remaining ClusterRoles:"
        kubectl --kubeconfig="$kubeconfig" get clusterrole -o name | grep -i "$namespace" || echo "No resources found."

        echo "==================================================="

        # Delete Kyverno ClusterRoles
        echo "Deleting kyverno ClusterRoles"
        cluster_roles=$(kubectl --kubeconfig="$kubeconfig" get clusterrole -o name | grep -i "kyverno")
        if [[ -n $cluster_roles ]]; then
            echo "ClusterRoles found. Deleting..."
            retries=0
            while [[ -n $cluster_roles && $retries -lt 3 ]]; do
                echo "$cluster_roles" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                cluster_roles=$(kubectl --kubeconfig="$kubeconfig" get clusterrole -o name | grep -i "kyverno")
                ((retries++))
            done
            if [[ -n $cluster_roles ]]; then
                echo "Failed to delete ClusterRoles in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted ClusterRoles in namespace '$namespace'"
        else
            echo "Skipping ClusterRole deletion. No ClusterRoles found in namespace '$namespace'."
        fi
        echo "Remaining ClusterRoles:"
        kubectl --kubeconfig="$kubeconfig" get clusterrole -o name | grep -i "kyverno" || echo "No resources found."

        echo "==================================================="

        # Delete ClusterRoleBindings
        echo "Deleting ClusterRoleBindings"
        cluster_role_bindings=$(kubectl --kubeconfig="$kubeconfig" get clusterrolebinding -o name | grep -i "$namespace")
        if [[ -n $cluster_role_bindings ]]; then
            echo "ClusterRoleBindings found. Deleting..."
            retries=0
            while [[ -n $cluster_role_bindings && $retries -lt 3 ]]; do
                echo "$cluster_role_bindings" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                cluster_role_bindings=$(kubectl --kubeconfig="$kubeconfig" get clusterrolebinding -o name | grep -i "$namespace")
                ((retries++))
            done
            if [[ -n $cluster_role_bindings ]]; then
                echo "Failed to delete ClusterRoleBindings in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted ClusterRoleBindings in namespace '$namespace'"
        else
            echo "Skipping ClusterRoleBinding deletion. No ClusterRoleBindings found in namespace '$namespace'."
        fi
        echo "Remaining ClusterRoleBindings:"
        kubectl --kubeconfig="$kubeconfig" get clusterrolebinding -o name | grep -i "$namespace" || echo "No resources found."

        echo "==================================================="

        # Delete kyverno ClusterRoleBindings
        echo "Deleting kyverno ClusterRoleBindings"
        cluster_role_bindings=$(kubectl --kubeconfig="$kubeconfig" get clusterrolebinding -o name | grep -i "kyverno")
        if [[ -n $cluster_role_bindings ]]; then
            echo "ClusterRoleBindings found. Deleting..."
            retries=0
            while [[ -n $cluster_role_bindings && $retries -lt 3 ]]; do
                echo "$cluster_role_bindings" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                cluster_role_bindings=$(kubectl --kubeconfig="$kubeconfig" get clusterrolebinding -o name | grep -i "kyverno")
                ((retries++))
            done
            if [[ -n $cluster_role_bindings ]]; then
                echo "Failed to delete ClusterRoleBindings in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted ClusterRoleBindings in namespace '$namespace'"
        else
            echo "Skipping ClusterRoleBinding deletion. No ClusterRoleBindings found in namespace '$namespace'."
        fi
        echo "Remaining ClusterRoleBindings:"
        kubectl --kubeconfig="$kubeconfig" get clusterrolebinding -o name | grep -i "kyverno" || echo "No resources found."

        echo "==================================================="

        # Delete MutatingWebhookConfigurations
        echo "Deleting MutatingWebhookConfigurations"
        mutating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get mutatingwebhookconfiguration -o name | grep -i "$namespace")
        if [[ -n $mutating_webhook_configs ]]; then
            echo "MutatingWebhookConfigurations found. Deleting..."
            retries=0
            while [[ -n $mutating_webhook_configs && $retries -lt 3 ]]; do
                echo "$mutating_webhook_configs" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                mutating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get mutatingwebhookconfiguration -o name | grep -i "$namespace")
                ((retries++))
            done
            if [[ -n $mutating_webhook_configs ]]; then
                echo "Failed to delete MutatingWebhookConfigurations in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted MutatingWebhookConfigurations in namespace '$namespace'"
        else
            echo "Skipping MutatingWebhookConfiguration deletion. No MutatingWebhookConfigurations found in namespace '$namespace'."
        fi
        echo "Remaining MutatingWebhookConfigurations:"
        kubectl --kubeconfig="$kubeconfig" get mutatingwebhookconfiguration -o name | grep -i "$namespace" || echo "No resources found."

        echo "==================================================="

        # Delete kyverno MutatingWebhookConfigurations
        echo "Deleting kyverno MutatingWebhookConfigurations"
        mutating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get mutatingwebhookconfiguration -o name | grep -i "kyverno")
        if [[ -n $mutating_webhook_configs ]]; then
            echo "MutatingWebhookConfigurations found. Deleting..."
            retries=0
            while [[ -n $mutating_webhook_configs && $retries -lt 3 ]]; do
                echo "$mutating_webhook_configs" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                mutating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get mutatingwebhookconfiguration -o name | grep -i "kyverno")
                ((retries++))
            done
            if [[ -n $mutating_webhook_configs ]]; then
                echo "Failed to delete MutatingWebhookConfigurations in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted MutatingWebhookConfigurations in namespace '$namespace'"
        else
            echo "Skipping MutatingWebhookConfiguration deletion. No MutatingWebhookConfigurations found in namespace '$namespace'."
        fi
        echo "Remaining MutatingWebhookConfigurations:"
        kubectl --kubeconfig="$kubeconfig" get mutatingwebhookconfiguration -o name | grep -i "kyverno" || echo "No resources found."

        echo "==================================================="

        # Delete ValidatingWebhookConfigurations
        echo "Deleting ValidatingWebhookConfigurations"
        validating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get validatingwebhookconfiguration -o name | grep -i "$namespace")
        if [[ -n $validating_webhook_configs ]]; then
            echo "ValidatingWebhookConfigurations found. Deleting..."
            retries=0
            while [[ -n $validating_webhook_configs && $retries -lt 3 ]]; do
                echo "$validating_webhook_configs" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                validating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get validatingwebhookconfiguration -o name | grep -i "$namespace")
                ((retries++))
            done
            if [[ -n $validating_webhook_configs ]]; then
                echo "Failed to delete ValidatingWebhookConfigurations in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted ValidatingWebhookConfigurations in namespace '$namespace'"
        else
            echo "Skipping ValidatingWebhookConfiguration deletion. No ValidatingWebhookConfigurations found in namespace '$namespace'."
        fi
        echo "Remaining ValidatingWebhookConfigurations:"
        kubectl --kubeconfig="$kubeconfig" get validatingwebhookconfiguration -o name | grep -i "$namespace" || echo "No resources found."

        echo "==================================================="

        # Delete kyverno ValidatingWebhookConfigurations
        echo "Deleting kyverno ValidatingWebhookConfigurations"
        validating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get validatingwebhookconfiguration -o name | grep -i "kyverno")
        if [[ -n $validating_webhook_configs ]]; then
            echo "ValidatingWebhookConfigurations found. Deleting..."
            retries=0
            while [[ -n $validating_webhook_configs && $retries -lt 3 ]]; do
                echo "$validating_webhook_configs" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0
                sleep 5
                validating_webhook_configs=$(kubectl --kubeconfig="$kubeconfig" get validatingwebhookconfiguration -o name | grep -i "kyverno")
                ((retries++))
            done
            if [[ -n $validating_webhook_configs ]]; then
                echo "Failed to delete ValidatingWebhookConfigurations in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted ValidatingWebhookConfigurations in namespace '$namespace'"
        else
            echo "Skipping ValidatingWebhookConfiguration deletion. No ValidatingWebhookConfigurations found in namespace '$namespace'."
        fi
        echo "Remaining ValidatingWebhookConfigurations:"
        kubectl --kubeconfig="$kubeconfig" get validatingwebhookconfiguration -o name | grep -i "$namespace" || echo "No resources found."

        echo "==================================================="

        # Delete StatefulSets
        echo "Deleting StatefulSets"
        statefulsets=$(kubectl --kubeconfig="$kubeconfig" get statefulset -n "$namespace" -o name)
        if [[ -n $statefulsets ]]; then
            retries=0
            while [[ -n $statefulsets && $retries -lt 3 ]]; do
                echo "$statefulsets" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0 -n "$namespace"
                sleep 5
                statefulsets=$(kubectl --kubeconfig="$kubeconfig" get statefulset -n "$namespace" -o name)
                ((retries++))
            done
            if [[ -n $statefulsets ]]; then
                echo "Failed to delete StatefulSets in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted StatefulSets in namespace '$namespace'"
        else
            echo "Skipping StatefulSet deletion. No StatefulSets found in namespace '$namespace'."
        fi
        echo "Remaining StatefulSets:"
        kubectl --kubeconfig="$kubeconfig" get statefulset -n "$namespace" -o name || echo "No resources found."

        echo "==================================================="

        # Delete DaemonSets
        echo "Deleting DaemonSets"
        daemonsets=$(kubectl --kubeconfig="$kubeconfig" get daemonset -n "$namespace" -o name)
        if [[ -n $daemonsets ]]; then
            retries=0
            while [[ -n $daemonsets && $retries -lt 3 ]]; do
                echo "$daemonsets" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0 -n "$namespace"
                sleep 5
                daemonsets=$(kubectl --kubeconfig="$kubeconfig" get daemonset -n "$namespace" -o name)
                ((retries++))
            done
            if [[ -n $daemonsets ]]; then
                echo "Failed to delete DaemonSets in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted DaemonSets in namespace '$namespace'"
        else
            echo "Skipping DaemonSet deletion. No DaemonSets found in namespace '$namespace'."
        fi
        echo "Remaining DaemonSets:"
        kubectl --kubeconfig="$kubeconfig" get daemonset -n "$namespace" -o name || echo "No resources found."

        echo "==================================================="

        # Delete Deployments
        echo "Deleting Deployments"
        deployments=$(kubectl --kubeconfig="$kubeconfig" get deployment -n "$namespace" -o name)
        if [[ -n $deployments ]]; then
            retries=0
            while [[ -n $deployments && $retries -lt 3 ]]; do
                echo "$deployments" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0 -n "$namespace"
                sleep 5
                deployments=$(kubectl --kubeconfig="$kubeconfig" get deployment -n "$namespace" -o name)
                ((retries++))
            done
            if [[ -n $deployments ]]; then
                echo "Failed to delete Deployments in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted Deployments in namespace '$namespace'"
        else
            echo "Skipping Deployment deletion. No Deployments found in namespace '$namespace'."
        fi
        echo "Remaining Deployments:"
        kubectl --kubeconfig="$kubeconfig" get deployment -n "$namespace" -o name || echo "No resources found."

        echo "==================================================="

        # Delete Services
        echo "Deleting Services"
        services=$(kubectl --kubeconfig="$kubeconfig" get service -n "$namespace" -o name)
        if [[ -n $services ]]; then
            retries=0
            while [[ -n $services && $retries -lt 3 ]]; do
                echo "$services" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0 -n "$namespace"
                sleep 5
                services=$(kubectl --kubeconfig="$kubeconfig" get service -n "$namespace" -o name)
                ((retries++))
            done
            if [[ -n $services ]]; then
                echo "Failed to delete Services in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted Services in namespace '$namespace'"
        else
            echo "Skipping Service deletion. No Services found in namespace '$namespace'."
        fi
        echo "Remaining Services:"
        kubectl --kubeconfig="$kubeconfig" get service -n "$namespace" -o name || echo "No resources found."

        echo "==================================================="

        # Delete Pods
        echo "Deleting Pods"
        pods=$(kubectl --kubeconfig="$kubeconfig" get pod -n "$namespace" -o name)
        if [[ -n $pods ]]; then
            retries=0
            while [[ -n $pods && $retries -lt 3 ]]; do
                echo "$pods" | xargs kubectl --kubeconfig="$kubeconfig" delete --force --grace-period=0 -n "$namespace"
                sleep 5
                pods=$(kubectl --kubeconfig="$kubeconfig" get pod -n "$namespace" -o name)
                ((retries++))
            done
            if [[ -n $pods ]]; then
                echo "Failed to delete Pods in namespace '$namespace'."
                exit 1
            fi
            echo "Deleted Pods in namespace '$namespace'"
        else
            echo "Skipping Pod deletion. No Pods found in namespace '$namespace'."
        fi
        echo "Remaining Pods:"
        kubectl --kubeconfig="$kubeconfig" get pod -n "$namespace" -o name || echo "No resources found."

        echo "==================================================="



        # Wait for resources to be deleted
       echo  "Waiting for resources to be deleted in namespace '$namespace'."
        while kubectl --kubeconfig="$kubeconfig" get pod -n "$namespace" 2>&1 | grep Terminating; do
            sleep 5
        done

    echo "==================================================="


        # Delete the namespace
        echo "Deleting namespace: $namespace"

    echo "==================================================="


        # Check if namespace exists
        namespace_exists=$(kubectl --kubeconfig="$kubeconfig" get namespace "$namespace" -o name 2>/dev/null)
        echo $namespace_exists
        if [[ -z $namespace_exists ]]; then
            echo "Namespace '$namespace' does not exist on the cluster. Skipping deletion."
        else

    echo "==================================================="

            # Remove finalizers from the namespace
            # kubectl --kubeconfig="$kubeconfig" delete ns "$namespace" --wait=true 2>/dev/null
            kubectl --kubeconfig="$kubeconfig" patch namespace "$namespace" -p '{"spec":{"finalizers": []}}' --type=merge
            # kubectl --kubeconfig="$kubeconfig" patch namespace "$namespace" -p '{"metadata":{"finalizers": []}}' --type=merge
            # Retry deletion if namespace still exists
            retries=3
            while [[ $retries -gt 0 ]]; do
                # Delete the namespace
                kubectl --kubeconfig="$kubeconfig" delete ns "$namespace" --force --grace-period=0 --wait=true 2>/dev/null

                # Check if namespace still exists
                namespace_status=$(kubectl --kubeconfig="$kubeconfig" get namespace "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null)
                if [[ -z $namespace_status ]]; then
                    echo "Namespace '$namespace' doesn't exist now"
                    break
                fi

                retries=$((retries-1))
                echo "Failed to delete namespace '$namespace'. Retrying..."
                sleep 5
            done

            # Check deletion status
            if [[ $retries -eq 0 ]]; then
                echo "Failed to delete namespace '$namespace' after multiple attempts. Please check manually."
                exit 1
            fi
        fi

        echo "Namespace '$namespace' deleted successfully"
    done

    echo "==================================================="

    # Delete secrets
    kubectl --kubeconfig="$kubeconfig" get secret -A | grep -i policies | awk '{print $2}' | xargs kubectl --kubeconfig="$kubeconfig" delete secret -n default --force --grace-period=0

    echo "Kyverno and Nirmata-related resources are deleted from the cluster"


    echo "-------------Cleaning up the Cluster from Nirmata---------------"
    echo $CLUSTERID > clusterid_$CLUSTERNAME

    for clusterid in $(cat clusterid_$CLUSTERNAME); do
        echo "Removing cluster $CLUSTERNAME from Nirmata..."
        delete_response=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X DELETE "$NIRMATAURL/cluster/api/KubernetesCluster/$clusterid?action=remove")

        if [[ $? -eq 0 ]]; then
            echo "$delete_response"
            echo "$CLUSTERNAME removal request sent successfully"
        fi

        # Wait until the cluster is completely removed
        retries=0
        elapsed_time=0
        while true; do
            cluster_exists=$(curl -s -H "Accept: application/json, text/javascript, */*; q=0.01" -H "Authorization: NIRMATA-API $TOKEN" -X GET "$NIRMATAURL/cluster/api/KubernetesCluster/$clusterid")

            if [[ -z "$cluster_exists" ]]; then
                echo "Cluster $CLUSTERNAME has been successfully removed from Nirmata"
                break
            elif [[ "$cluster_exists" == *"KubernetesCluster:$clusterid not found"* ]]; then
                echo "Cluster $CLUSTERNAME not found. Assuming removal is complete."
                break
            elif [[ $retries -lt 120 ]]; then  # Retry for up to 20 minutes (120 retries * 10 seconds = 20 minutes)
                if [[ $elapsed_time -eq 0 || $elapsed_time -ge 300 ]]; then
                    echo "Cluster Removal is taking more time than usual. Please wait for removal."
                    elapsed_time=0
                fi
                echo "Cluster $CLUSTERNAME removal is in progress..."
                sleep 10  # Wait for 10 seconds before retrying
                ((retries++))
                ((elapsed_time+=10))
            else
                echo "Cluster $CLUSTERNAME seems to be larger. Please wait to remove the cluster from the Nirmata UI before retrying."
                exit 1
            fi
        done
    done
fi
echo "==================================================="c