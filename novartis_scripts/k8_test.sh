#!/bin/bash
#default external dns target
DNSTARGET=nirmata.com
SERVICETARGET=kubernetes.default.svc.cluster.local
allns=1
curl=1
namespace="default"
#Should we continue to execute on failure
CONTINUE="yes"
QUIET="no"
run_local=0
run_remote=0
export error=0
export warn=0
nossh=0
script_args=""
email=1
sendemail='ssilbory/sendemail'
alwaysemail=1
fix_issues=1

if [ -f /.dockerenv ]; then
    export INDOCKER=0
else
    export INDOCKER=1
fi

#function to print red text
error(){
    error=1
    # shellcheck disable=SC2145
    echo -e "\e[31m${@}\e[0m"
    if [ "$CONTINUE" = "no" ];then
        echo -e "\e[31mContinue is not set exiting on error!\e[0m"
       namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
       for ns in $namespaces;do
          kubectl --namespace=$ns delete ds net-test-all --ignore-not-found=true &>/dev/null
        done
        # THIS EXITS THE SCRIPT
        exit 1
    fi
}
#function to print yellow text
warn(){
    warn=1
    # shellcheck disable=SC2145
    echo -e "\e[33m${@}\e[0m"
}
good(){
    if [ ! "$QUIET" = "yes" ];then
        # shellcheck disable=SC2145
        echo -e "\e[32m${@}\e[0m"
    fi
}
helpfunction(){
    echo "Note that this script requires access to the following containers:"
    echo "nicolaka/netshoot for cluster tests."
    echo "ssilbory/sendemail for sending email."
    echo "Usage: $0"
    echo "--allns                     Test all namespaces (Default is only \"$namespace\")"
    echo '--dns-target dns.name       (Default nirmata.com)'
    #echo '--exit                     Exit on errors'
    echo '--https                     Curl the service with https.'
    echo '--http                      Curl the service with http.'
    echo '--local                     Run local tests'
    echo '-q                          Do not report success'
    echo "--namespace namespace_name  (Default is \"$namespace\")."
    echo '--cluster                   Run Nirmata K8 cluster tests'
    echo "--service service_target    (Default $SERVICETARGET)."
    echo "--fix                       Attempt to fix issues (local only)"
    echo "--ssh \"user@host.name\"    Ssh to a space-separated list of systems and run local tests"
    echo "Note that --ssh does not return non-zero on failure on ssh targets.  Parse for:"
    echo "  'Test completed with errors'"
    echo "  'Test completed with warnings'"
    echo
    echo "Email Settings (Note that these options are incompatible with --ssh.)"
    echo "--email                     Enables email reporting on error"
    echo "--to some.one@some.domain   Sets the to address.  Required"
    echo "--from email@some.domain    Sets the from address. (default k8@nirmata.com)"
    echo "--subject 'something'       Sets the email subject. (default 'K8 test script error')"
    echo "--smtp smtp.server          Set your smtp server.  Required"
    echo "--user user.name            Sets your user name. Optional"
    echo "--passwd 'L33TPASSW)RD'     Set your password.  Optional"
    echo "--email-opts '-o tls=yes'   Additional options to send to the sendemail program."
    echo "--always-email              Send emails on warning and good test results"
    echo "--sendemail                 Set the container used to send email."
    echo "Simple open smtp server:"
    echo "$0 --email --to testy@nirmata.com --smtp smtp.example.com"
    echo "Authenication with an smtp server:"
    echo "--email --to testy@nirmata.com --smtp smtp.example.com  --user sam.silbory --passwd 'foo!foo'"
    echo "Authenication with gmail: (Requires an app password be used!)"
    echo "--email --to testy@nirmata.com --smtp smtp.gmail.com:587  --user sam.silbory --passwd 'foo!foo'"
}

# deal with args
for i in "$@";do
    case $i in
        --dns-target)
            script_args=" $script_args $1 $2 "
            DNSTARGET=$2
            shift
            shift
            echo DNSTARGET is $DNSTARGET
        ;;
        --service)
            script_args=" $script_args $1 $2 "
            SERVICETARGET=$2
            shift
            shift
            echo SERVICETARGET is $SERVICETARGET
        ;;
        --continue|-c)
            script_args=" $script_args $1 "
            CONTINUE="yes"
            shift
        ;;
        --allns)
            script_args=" $script_args $1 "
            allns=0
            shift
        ;;
        --https)
            script_args=" $script_args $1 "
            curl=0
            http=1
            shift
        ;;
        --http)
            script_args=" $script_args $1 "
            curl=0
            http=0
            shift
        ;;
        --namespace)
            script_args=" $script_args $1 $2 "
            namespace=$2
            shift
            shift
        ;;
        --local)
            script_args=" $script_args $1 "
            run_local=0
            run_remote=1
            shift
        ;;
        --cluster)
            script_args=" $script_args $1 "
            run_local=1
            run_remote=0
            shift
        ;;
        --exit)
            script_args=" $script_args $1 "
            CONTINUE="no"
            shift
        ;;
        -q)
            script_args=" $script_args $1 "
            QUIET="yes"
            shift
        ;;
        --ssh)
            ssh_hosts=$2
            nossh=1
            shift
            shift
        ;;
        --nossh)
            script_args=" $script_args $1 "
            nossh=0
            shift
        ;;
        --fix)
            fix_issues=0
            shift
        ;;
        --logfile)
            script_args=" $script_args $1 $2 "
            logfile=$2
            shift
            shift
        ;;
        --email)
            script_args=" $script_args $1 "
            email=0
            shift
        ;;
        --to)
            script_args=" $script_args $1 $2 "
            TO=$2
            shift
            shift
        ;;
        --from)
            script_args=" $script_args $1 $2 "
            FROM=$2
            shift
            shift
        ;;
        --subject)
            script_args=" $script_args $1 $2 "
            SUBJECT=$2
            shift
            shift
        ;;
        --smtp)
            script_args=" $script_args $1 $2 "
            SMTP_SERVER=$2
            shift
            shift
        ;;
        --user)
            script_args=" $script_args $1 $2 "
            EMAIL_USER=$2
            shift
            shift
        ;;
        --passwd)
            script_args=" $script_args $1 $2 "
            EMAIL_PASSWD=$2
            shift
            shift
        ;;
                --sendemail)
            sendemail=$2
            shift
            shift
        ;;
        --always-email)
            alwaysemail=0
            shift
        ;;
        #--email-opts)
        #    script_args=" $script_args $1 $2 "
        #    EMAIL_OPTS="\'$2\'"
        #    shift
        #    shift
        #;;
        -h|--help)
            helpfunction
            exit 0
        ;;
    esac
done
# We don't ever want to pass --ssh!!!
script_args=$(echo $script_args |sed 's/--ssh//')



remote_test(){
    command -v kubectl &>/dev/null || error 'No kubectl found in path!!!'
    echo "Starting Cluster Tests"
    echo 'apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: net-test-all
spec:
  template:
    metadata:
      labels:
        app: net-test-all-app
    spec:
      containers:
        - name: net-test-node
          image: nicolaka/netshoot
          command: [ "/bin/sh", "-c", "sleep  100000" ]' >/tmp/nirmata-net-test-all.yml

    namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
    for ns in $namespaces;do
            kubectl --namespace=$ns delete ds net-test-all --ignore-not-found=true &>/dev/null
    done
    #echo allns is $allns
    if [ $allns != 1 ];then
        for ns in $namespaces;do
            kubectl --namespace=$ns apply -f /tmp/nirmata-net-test-all.yml &>/dev/null
        done
    else
        namespaces=$namespace
        kubectl --namespace=$namespace apply -f /tmp/nirmata-net-test-all.yml &>/dev/null
    fi
    #echo Testing namespaces $namespaces

    #check for nodes, and kubectl function
    echo
    echo Found the following nodes:
    if ! kubectl get node --no-headers; then
        error 'Failed to contact cluster!!!'
        echo 'Is the master up? Is kubectl configured?'
    fi
    echo

    if kubectl get no -o jsonpath="{.items[?(@.spec.unschedulable)].metadata.name}"|grep .;then
        warn 'Above nodes are unschedulable!!'
    fi

    times=0
    required_pods=$(kubectl get node --no-headers | awk '{print $2}' |grep Ready |wc -l)
    num_ns=$(echo $namespaces |wc -w)
    required_pods=$((required_pods * num_ns))
    #echo required_pods is $required_pods
    echo -n 'Waiting for net-test-all pods to start'
    until [[ $(kubectl get pods -l app=net-test-all-app --no-headers --all-namespaces|awk '{print $4}' |grep Running|wc -l) -ge $required_pods ]]|| \
      [[ $times = 60 ]];do
        sleep 1;
        echo -n .;
        times=$((times + 1));
    done
    echo

    if [[ $(kubectl -n $namespace get pods -l app=net-test-all-app --no-headers |awk '{print $3}' |grep Running|wc -l) -ne \
      $(kubectl get node --no-headers | awk '{print $2}' |grep Ready |wc -l) ]] ;then
        error 'Failed to start net-test-all on all nodes!!'
        echo Debugging:
        kubectl get pods -l app=net-test-all-app -o wide
        kubectl get node
    fi

    dns_error=0
    for ns in $namespaces;do
        echo Testing $ns namespace
    for pod in $(kubectl -n $ns get pods -l app=net-test-all-app --no-headers |grep Running |awk '{print $1}');do
        echo Testing "$(kubectl -n $ns get pods $pod -o wide --no-headers| awk '{print $7}') Namespace $ns"
        if  kubectl exec $pod -- nslookup $DNSTARGET 2>&1|grep -e can.t.resolve -e does.not.resolve -e can.t.find -e No.answer;then
            warn "Can not resolve external DNS name $DNSTARGET on $pod."
            kubectl -n $ns get pod $pod -o wide
            kubectl -n $ns exec $pod -- sh -c "nslookup $DNSTARGET"
            echo
        else
            good "DNS test $DNSTARGET on $pod suceeded."
        fi
        #kubectl -n $ns exec $pod -- nslookup $SERVICETARGET
        if kubectl -n $ns exec $pod -- nslookup $SERVICETARGET 2>&1|grep -e can.t.resolve -e does.not.resolve -e can.t.find -e No.answer;then
            warn "Can not resolve $SERVICETARGET service on $pod"
            echo 'Debugging info:'
            kubectl get pod $pod -o wide
            dns_error=1
            kubectl -n $ns exec $pod -- nslookup $DNSTARGET
            kubectl -n $ns exec $pod -- nslookup $SERVICETARGET
            kubectl -n $ns exec $pod -- cat /etc/resolv.conf
            error "DNS test failed to find $SERVICETARGET service on $pod"
        else
            good "DNS test $SERVICETARGET on $pod suceeded."
        fi
        if [[ $curl -eq 0 ]];then
             if [[ $http -eq 0 ]];then
                 if  kubectl -n $ns exec $pod -- sh -c "if curl --max-time 5 http://$SERVICETARGET; then exit 0; else exit 1; fi" 2>&1|grep -e 'command terminated with exit code 1';then
                     error "http://$SERVICETARGET failed to respond to curl in 5 seconds!"
                 else
                     good "HTTP test $SERVICETARGET on $pod suceeded."
                 fi
             else
                 if  kubectl -n $ns exec $pod -- sh -c "if curl --max-time 5 -k https://$SERVICETARGET; then exit 0; else exit 1; fi" 2>&1|grep -e 'command terminated with exit code 1';then
                     error "https://$SERVICETARGET failed to respond to curl in 5 seconds!"
                 else
                     good "HTTPS test $SERVICETARGET on $pod suceeded."
                 fi
             fi
        fi

    done
    done

    if [[ dns_error -eq 1 ]];then
        warn "DNS issues detected"
        echo 'Additional debugging info:'
        kubectl get svc -n kube-system kube-dns coredns
        kubectl get deployments -n kube-system coredns kube-dns
        echo 'Note you should have either coredns or kube-dns running. Not both.'
    fi

     namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
     for ns in $namespaces;do
         kubectl --namespace=$ns delete ds net-test-all --ignore-not-found=true &>/dev/null
    done

    # mongo testing
    echo "Testing MongoDB Pods"
    mongo_ns=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=mongodb --no-headers | awk '{print $1}'|head -1)
    mongos=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=mongodb --no-headers | awk '{print $2}')
    mongo_num=0
    mongo_master=""
    for mongo in $mongos; do
        if kubectl -n $mongo_ns exec $mongo -c mongodb -- sh -c 'echo "db.serverStatus()" |mongo' 2>&1|grep  '"ismaster"'|grep -q 'true,';then
            mongo_master="$mongo_master $mongo"
        fi
        mongo_num=$((mongo_num + 1));
    done
    mongo_error=0
    [[ $mongo_num -gt 3 ]] && error "Found $mongo_num Mongo Pods $mongos!!!" && mongo_error=1
    [[ $mongo_num -eq 0 ]] && error "Found Mongo Pods $mongo_num!!!" && mongo_error=1
    [[ $mongo_num -eq 1 ]] && warn "Found One Mongo Pod"  && mongo_error=1
    [ -z $mongo_master ] &&  error "No Mongo Master found!!"  && mongo_error=1
    [[ $(echo $mongo_master|wc -w) -gt 1 ]] &&  error "Mongo Masters $mongo_master found!!" && mongo_error=1
    [ $mongo_error -eq 0 ] && good "MongoDB passed tests"

    # Zookeeper testing
    zoo_error=0
    echo "Testing Zookeeper pods"
    zoo_ns=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=zk --no-headers | awk '{print $1}'|head -1)
    zoos=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=zk --no-headers | awk '{print $2}')
    zoo_num=0
    zoo_leader=""
    for zoo in $zoos; do
        if kubectl -n $zoo_ns exec $zoo -- sh -c "/usr/bin/zkServer.sh status" 2>&1|grep Mode |grep -q -e leader -e standalone;then
            zoo_leader="$zoo_leader $zoo"
        fi
        zoo_num=$((zoo_num + 1));
        zoo_df=$(kubectl -n $zoo_ns exec $zoo -- df /tmp/ | awk '{ print $5; }' |tail -1|sed s/%//)
        [[ $zoo_df -gt 50 ]] && error "Found zookeeper volume at ${zoo_df}% usage on $zoo"
    done
    [[ $zoo_num -gt 3 ]] && error "Found $zoo_num Zookeeper Pods $zoos!!!" && zoo_error=1
    [[ $zoo_num -eq 0 ]] && error "Found Zero Zookeeper Pods !!" && zoo_error=1
    [[ $zoo_num -eq 1 ]] && warn "Found One Zookeeper Pod." && zoo_error=1
    [ -z $zoo_leader ] &&  error "No Zookeeper Leader found!!" && zoo_error=1
    [[ $(echo $zoo_leader|wc -w) -gt 1 ]] && warn "Found Zookeeper Leaders $zoo_leader." && zoo_error=1
    [ $zoo_error -eq 0 ] && good "Zookeeper passed tests"

    #  testing
    echo "Testing Kafka pods"
    kafka_ns=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=kafka --no-headers | awk '{print $1}'|head -1)
    kafkas=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=kafka --no-headers | awk '{print $2}')
    for kafka in $kafkas; do
        kafka_df=$(kubectl -n $kafka_ns exec $kafka -- df /tmp/ | awk '{ print $5; }' |tail -1|sed s/%//)
        [[ $kafka_df -gt 50 ]] && error "Found Kafka volume at ${kafka_df}% usage on $kafka"
    done

}

local_test(){
echo "Starting Local Tests"

echo "Checking for swap"
if [[ $(swapon -s | wc -l) -gt 1 ]] ;  then
    if [[ $fix_issues -eq 0 ]];then
        warn "Found swap enabled"
        echo "Applying the following fixes"
        ech 'swapoff -a'
        swapoff -a
        echo "sed -i '/[[:space:]]*swap[[:space:]]*swap/d' /etc/fstab"
        sed -i '/[[:space:]]*swap[[:space:]]*swap/d' /etc/fstab
    else
        error "Found swap enabled!"
    fi
fi

echo "Testing SELinux"
if type sestatus &>/dev/null;then
    if ! sestatus | grep "Current mode" |grep -e permissive -e disabled;then
        warn 'SELinux enabled'
        if [[ $fix_issues -eq 0 ]];then
            echo "Applying the following fixes"
            echo '  sed -i s/^SELINUX=.*/SELINUX=permissive/ /etc/selinux/config'
            sed -i s/^SELINUX=.*/SELINUX=permissive/ /etc/selinux/config
            echo '  setenforce 0'
            setenforce 0
        else
            echo Consider the following changes to disabled SELinux if you are having issues:
            echo '  sed -i s/^SELINUX=.*/SELINUX=permissive/ /etc/selinux/config'
            echo '  setenforce 0'
        fi
    fi
else
    #assuming debian/ubuntu don't do selinux
    if [ -e /etc/os-release ]  &&  ! grep -q -i -e debian -e ubuntu /etc/os-release;then
        warn 'sestatus binary not found assuming SELinux is disabled.'
    fi
fi

#test kernel ip forward settings
if grep -q 0 /proc/sys/net/ipv4/ip_forward;then
        if [[ $fix_issues -eq 0 ]];then
            warn net.ipv4.ip_forward is set to 0
            echo "Applying the following fixes"
            echo '  sysctl -w net.ipv4.ip_forward=1'
            sysctl -w net.ipv4.ip_forward=1
            echo '  echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf'
            echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
        else
            error net.ipv4.ip_forward is set to 0
            echo Consider the following changes:
            echo '  sysctl -w net.ipv4.ip_forward=1'
            echo '  echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf'
        fi
else
    good ip_forward enabled
fi

if [ ! -e /proc/sys/net/bridge/bridge-nf-call-iptables ];then
    if [[ $fix_issues -eq 0 ]];then
        warn '/proc/sys/net/bridge/bridge-nf-call-iptables does not exist!'
        echo "Applying the following fixes"
        echo '  modprobe br_netfilter'
        modprobe br_netfilter
        echo '  echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf'
        echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
    else
        error '/proc/sys/net/bridge/bridge-nf-call-iptables does not exist!'
        echo 'Is the br_netfilter module loaded? "lsmod |grep br_netfilter"'
        echo Consider the following changes:
        echo '  modprobe br_netfilter'
        echo '  echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf'
    fi
fi
if grep -q 0 /proc/sys/net/bridge/bridge-nf-call-iptables;then
    if [[ $fix_issues -eq 0 ]];then
        warn "Bridge netfilter disabled!!"
        echo "Applying the following fixes"
        echo '  sysctl -w net.bridge.bridge-nf-call-iptables=1'
        sysctl -w net.bridge.bridge-nf-call-iptables=1
        echo '  echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf'
        echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf
    else
        error "Bridge netfilter disabled!!"
        echo Consider the following changes:
        echo '  sysctl -w net.bridge.bridge-nf-call-iptables=1'
        echo '  echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf'
    fi
else
    good bridge-nf-call-iptables enabled
fi


#TODO check for proxy settings, how, what, why

#test for docker
if ! systemctl is-active docker &>/dev/null ; then
    warn 'Docker service is not active? Maybe you are using some other CRI??'
else
    if docker info 2>/dev/null|grep mountpoint;then
        warn 'Docker does not have its own mountpoint'
        # What is the fix for this???
    else
        dockerVersion=$(docker --version | awk -F'[, ]+' '{print $3}')
        if [[ $dockerVersion <  19.03.13 ]] ; then
            warn 'Upgrade Docker to 19.03.13 or later'
        else
            good 'Docker is active'
        fi
    fi
fi

if type kubelet &>/dev/null;then
    #test for k8 service
    echo Found kubelet running local kubernetes tests
    if ! systemctl is-active kubelet &>/dev/null ; then
        error 'Kubelet is not active?'
    else
        good Kublet is active
    fi

    if ! systemctl is-enabled kubelet &>/dev/null ; then
        if [[ $fix_issues -eq 0 ]];then
            echo "Applying the following fixes"
            echo systectl enable kubelet
            systectl enable kubelet
        else
            error 'Kubelet is not set to run at boot?'
        fi
    else
        good Kublet is enabled at boot
    fi

    if [ ! -e /opt/cni/bin/bridge ];then
        warn '/opt/cni/bin/bridge not found is your CNI installed?'
    fi
fi

# tests for containerd
if ! systemctl is-active containerd &>/dev/null ; then
    warn 'Containerd service is not active? Maybe you are using some other CRI??'
else
    containerdVersion=$(containerd --version | awk '{print $3}')
    if [[ $containerdVersion < 1.6.19 ]] ;then
        warn 'Install containerd version 1.6.19 or later'
    else
        CONFIG_FILE="/etc/containerd/config.toml"
        if grep -q 'SystemdCgroup = true' "$CONFIG_FILE"; then
            good Containerd is active
        else
            warn "SystemdCgroup is not set to true in $CONFIG_FILE"
        fi
        
    fi
fi

# tests for systemd-resolved
if ! systemctl is-active systemd-resolved &>/dev/null ; then
    warn 'systemd-resolved is not running!'
else
    good systemd-resolved is active
fi

# tests for firewalld
if systemctl is-active firewalld &>/dev/null ; then
    warn 'firewalld is running, please turn it off using `sudo systemctl disable --now firewalld`'
else
    good firewalld is inactive
fi

}

#start main script


if [ ! -z $logfile ];then
    $0 $script_args 2>&1 |tee $logfile
    return_code=$?
    # Reformat the log file for better reading
    sed -i -e 's/\x1b\[[0-9;]*m//g' -e 's/$'"/`echo \\\r`/" $logfile
    exit $return_code
fi
if [[ $nossh -eq 1 ]];then
    if [[ ! -z $ssh_hosts ]];then
        for host in $ssh_hosts; do
            echo Testing host $host
            cat $0 | ssh $host bash -c "cat >/tmp/k8_test_temp.sh ; chmod 755 /tmp/k8_test_temp.sh; /tmp/k8_test_temp.sh $script_args --nossh ; rm /tmp/k8_test_temp.sh"
            echo
            echo
        done
    fi
else
    if [[ $email -eq 0 ]];then
        script_args=$(echo $script_args |sed 's/--email//')
        [ -z $logfile ] && logfile="/tmp/k8_test.$$"
        [ -z $EMAIL_USER ] && EMAIL_USER=""
        [ -z $EMAIL_PASSWD ] && EMAIL_PASSWD=""
        #[ -z $TO ] && error "No TO address given!!!" && exit 1
        [ -z $FROM ] && FROM="k8@nirmata.com" && warn "You provided no From address using $FROM"
        [ -z $SUBJECT ] && SUBJECT="K8 test script error" && warn "You provided no Subject using $SUBJECT"
        #[ -z $SMTP_SERVER ] && error "No smtp server given!!!" && exit 1
        echo
        sleep 1
        $0 $script_args 2>&1 |tee $logfile
        if [[ ${PIPESTATUS[0]} -ne 0 || ${alwaysemail} -eq 0 ]]; then
            # Reformat the log file for better reading
            sed -i -e 's/\x1b\[[0-9;]*m//g' -e 's/$'"/`echo \\\r`/" $logfile
            BODY=$(cat $logfile)
            docker run $sendemail $TO $FROM "$SUBJECT" "${BODY}" $SMTP_SERVER "$EMAIL_USER" "$EMAIL_PASSWD" "$EMAIL_OPTS"
            #If they named it something else don't delete
            rm -f /tmp/k8_test.$$
            exit 1
        fi
        # Reformat the log file for better reading
        sed -i -e 's/\x1b\[[0-9;]*m//g' -e 's/$'"/`echo \\\r`/" $logfile
        #If they named it something else don't delete
        rm -f /tmp/k8_test.$$
        exit 0
    fi
    if [[ $run_local -eq 0 ]];then
        local_test
    fi

    if [[ $run_remote -eq 0 ]];then
        remote_test
    fi

    if [ $error != 0 ];then
        error "Test completed with errors!"
        exit $error
    fi
    if [ $warn != 0 ];then
        warn "Test completed with warnings."
        exit 0
    fi
    echo -e  "\e[32mTesting completed without errors or warning\e[0m"
    exit 0
fi
