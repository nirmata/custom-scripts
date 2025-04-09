#!/bin/bash
# shellcheck disable=SC1117,SC2086,SC2001

# This might be better done in python or ruby, but we can't really depend on those existing or having useful modules on customer sites or containers.

version=2.0.0
#updated with mongodb
#default external dns target
DNSTARGET=nirmata.com
#default service target
SERVICETARGET=kubernetes.default.svc.cluster.local
# set to zero to default to all namespaces
allns=1
# set to zero to default to curl url
curl=1
# Default namespace for nirmata services
namespace="nirmata"
# Should we continue to execute on failure
CONTINUE="yes"
# Set to yes to be quieter
QUIET="no"
# set to 1 to disable local tests, this tests K8 compatiblity of local system
run_local=1
# set to 1 to disable remote tests, this tests k8 functionality via kubectl
run_remote=1
# set to 1 to disable base_cluster_node tests, this tests base cluster nodes
run_base_cluster_local=1
# These are used to run the mongo, zookeeper, kafka and kafka controller tests by default to test the nrimata setup.
# Maybe we should fork this script to move the nirmata tests else where?
run_mongo=1
run_zoo=1
run_kafka=1
run_kafka_controller=1
# Did we get an error?
export error=0
# Did we get a warning?
export warn=0
# Default to not using ssh
nossh=0
# Collect our script args
script_args=""
# shellcheck disable=SC2124
all_args="$@"
# We should do something if there is no instruction for us
if [[ ! $all_args == *--cluster* ]] ; then
    if [[ ! $all_args == *--local* ]] ; then
        if [[ ! $all_args == *--nirmata* ]] ; then
            if [[ ! $all_args == *--base-cluster-local* ]] ; then
                # default to testing nirmata
                run_mongo=0
                run_zoo=0
                run_kafka=0
                run_kafka_controller=0
            fi
        fi
    fi
fi
# Should we email by default?
email=1
# default sendemail containers Note NOT sendmail!
sendemail='ghcr.io/nirmata/sendemail'
alwaysemail=1
# Set this to fix local issues by default
fix_issues=1
# warnings return 2 otherwise
warnok=1
#additional args for kubectl
add_kubectl=""
# required free space for nirmata pods
df_free=80
# mongo seems to run out of space more easily during syncs
df_free_mongo=50
# docker parition free space
df_free_root=85
# set the repository to test login for
# repository='docker.io'

if [ -f /.dockerenv ]; then
    export INDOCKER=0
else
    export INDOCKER=1
fi

#function to print red text
error(){
    error=1
    # shellcheck disable=SC2145
    echo -e "\e[31mError: ${@}\e[0m"
    if [ "$CONTINUE" = "no" ];then
        # THIS EXITS THE SCRIPT
        echo -e "\e[31mContinue is not set exiting on error!\e[0m"
       namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
       for ns in $namespaces;do
          kubectl --namespace=$ns delete ds nirmata-net-test-all --ignore-not-found=true &>/dev/null
        done
        kubectl --namespace=$namespace delete ds nirmata-net-test-all --ignore-not-found=true &>/dev/null
        # THIS EXITS THE SCRIPT
        exit 1
    fi
}
#function to print yellow text
warn(){
    warn=1
    # shellcheck disable=SC2145
    echo -e "\e[33mWarn: ${@}\e[0m"
}
#function to print green text
good(){
    if [ ! "$QUIET" = "yes" ];then
        # shellcheck disable=SC2145
        echo -e "\e[32mGOOD: ${@}\e[0m"
    fi
}

echo_cmd(){
        # shellcheck disable=SC2145
        echo "${@}"
        # shellcheck disable=SC2068
        ${@}
}

helpfunction(){
    echo "Note that this script requires access to the following containers:"
    echo "nicolaka/netshoot for cluster tests."
    echo "ssilbory/sendemail for sending email."
    echo "Usage: $0"
    echo "--version                   Reports version ($version)"
    echo "--allns                     Test all namespaces (Default is only \"$namespace\")"
    echo '--dns-target dns.name       (Default nirmata.com)'
    #echo '--exit                     Exit on errors'
    echo '--https                     Curl the service with https.'
    echo '--http                      Curl the service with http.'
    echo '--local                     Run local tests'
    echo '--nirmata                   Run Nirmata app tests'
    echo '-q                          Do not report success'
    echo "--warnok                    Do not exit 2 on warnings."
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
    echo " --base-cluster-local to test base cluster nodes"
}

# deal with args
# Args are getting out of control it might be worth using getops or something.
for i in "$@";do
    case $i in
        --version)
            echo "$0 version $version"
            exit 0
        ;;
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
            if [[ ! $all_args == *--cluster* ]] ; then
                run_remote=1
            fi
            shift
        ;;
        --base-cluster-local)
            script_args=" $script_args $1 "
            run_base_cluster_local=0
            if [[ ! $all_args == *--cluster* ]] ; then
                run_remote=1
            fi
            if [[ ! $all_args == *--local* ]] ; then
                run_local=1
            fi
            shift
        ;;  
        --cluster)
            script_args=" $script_args $1 "
            if [[ ! $all_args == *--local* ]] ; then
                run_local=1
            fi
            run_remote=0
            shift
        ;;
        --nirmata)
            script_args=" $script_args $1 "
            run_mongo=0
            run_zoo=0
            run_kafka=0
            run_kafka_controller=0
            if [[ ! $all_args == *--cluster* ]] ; then
                run_remote=1
            fi
            if [[ ! $all_args == *--local* ]] ; then
                run_local=1
            fi
            shift
        ;;
        --exit)
            script_args=" $script_args $1 "
            CONTINUE="no"
            shift
        ;;
        --insecure)
            script_args=" $script_args $1 $2 "
            add_kubectl=" $add_kubectl --insecure-skip-tls-verify=false "
            shift
        ;;
        --client-cert)
            add_kubectl=" $add_kubectl --client-certificate=$2"
            shift
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
            TO="$2 $TO"
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
        --warnok)
            script_args=" $script_args $1 "
            warnok=0
            shift
        ;;
        # --repository)
        #     script_args=" $script_args $1 $2 "
        #     repository=$2
        #     shift
        #     shift
        # ;;
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
        # Remember that shifting doesn't remove later args from the loop
        -*)
            helpfunction
            exit 1
        ;;
    esac
done
# We don't ever want to pass --ssh to ssh!!!
script_args=$(echo $script_args |sed 's/--ssh//')
# shellcheck disable=SC2139
alias kubectl="kubectl $add_kubectl "

# Test mongodb pods
mongo_test(){
# mongo testing
echo "Testing MongoDB Pods"
mongo_ns=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=mongodb --no-headers | awk '{print $1}'|head -1)
mongos=$(kubectl get pod --namespace=$mongo_ns -l nirmata.io/service.name=mongodb --no-headers | awk '{print $1}')
mongo_num=0
# The mongo master (or masters ?!!?)
mongo_master=""
# Number of masters (ideally one)
mongo_masters=0
mongo_error=0
for mongo in $mongos; do
    if kubectl -n $mongo_ns get pod $mongo --no-headers |awk '{ print $2 }' |grep -q '[0-2]/2'; then
        mongo_container="-c mongodb"
    else
        mongo_container=""
    fi
    cur_mongo=$(kubectl -n "$mongo_ns" exec $mongo -c mongodb -- mongo --quiet --eval "printjson(rs.isMaster())" 2>&1)
    if echo "$cur_mongo" | grep -q '"ismaster" : true,'; then
        echo "$mongo is master/Primary"
        mongo_master="$mongo_master $mongo"
        mongo_masters=$((mongo_masters+ 1));
    else
        if echo "$cur_mongo" | grep -q '"secondary" : true,'; then
            echo "$mongo is slave/Secondary"
        else
            warn "$mongo is not master or slave! (Are we standalone?)"
            mongo_error=1
            kubectl -n $mongo_ns get pod $mongo --no-headers -o wide
        fi
    fi
    mongo_df=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- df /data/db | awk '{ print $5; }' | tail -1 | sed s/%//)
    [[ $mongo_df -gt $df_free_mongo ]] && (error "Found MongoDB volume at ${mongo_df}% usage on $mongo" ; \
        kubectl -n $mongo_ns exec $mongo $mongo_container -- du --all -h /data/db/ |grep '^[0-9,.]*G' )
    kubectl -n $mongo_ns exec $mongo $mongo_container -- du  -h /data/db/WiredTigerHS.wt |grep '[0-9]G' && \
        warn "WiredTiger lookaside file is very large on $mongo. Consider increasing Mongodb memory."
    mongo_num=$((mongo_num + 1));
    mongo_stateStr=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "rs.status()" |mongo' 2>&1 |grep stateStr)
    if [[ $mongo_stateStr =~ RECOVERING || $mongo_stateStr =~ DOWN || $mongo_stateStr =~ STARTUP ]];then
        if [[ $mongo_stateStr =~ RECOVERING ]];then warn "Detected recovering Mongodb from this node!"; fi
        if [[ $mongo_stateStr =~ DOWN ]];then error "Detected Mongodb in down state from this node!"; fi
        if [[ $mongo_stateStr =~ STARTUP ]];then warn "Detected Mongodb in startup state from this node!"; fi
        kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "rs.status()" |mongo'
    fi
done
if [[ $mongo_num -gt 3 ]];then
    error "Found $mongo_num Mongo Pods $mongos!!"
    mongo_error=1
fi
if [[ $mongo_num -eq 0 ]];then
    error "Found Mongo Pods $mongo_num!!" && mongo_error=1
else
    [[ $mongo_num -lt 3 ]] && warn "Found $mongo_num Mongo Pods"  && mongo_error=1
fi

if [[ $mongo_masters -lt 1 ]]; then
    if [[ $mongo_num -eq 1 ]];then
	    warn "No Mongo Master found!! (Assuming standalone)"
    else
        error "No Mongo Master found with multiple mongo nodes!!"
        mongo_error=1
    fi
else
    if [[ $mongo_masters -gt 1 ]];then
        error "Found $mongo_masters masters: $mongo_master!!"
        mongo_error=1
    fi
fi
[ $mongo_error -eq 0 ] && good "MongoDB passed tests"
}

# Zookeeper testing
zoo_test(){
    zoo_error=0
    echo "Testing Zookeeper pods"
    
    # Get the namespace of Zookeeper pods
    zoo_ns=$(kubectl get pod --all-namespaces -l 'nirmata.io/service.name in (zookeeper, zk)' --no-headers | awk '{print $1}'|head -1)
    
    # List Zookeeper pods
    zoos=$(kubectl get pod -n $zoo_ns -l 'nirmata.io/service.name in (zookeeper, zk)' --no-headers | awk '{print $1}')
    
    zoo_num=0
    zoo_leader=""
    
    # Iterate through each Zookeeper pod and check its status
    for zoo in $zoos; do
        curr_zoo=$(kubectl -n $zoo_ns exec $zoo -- zkServer.sh status 2>&1 | grep Mode)
        
        zoo_node_count=$(kubectl exec $zoo -n $zoo_ns -- sh -c "echo srvr | nc localhost 2181 | grep Node.count:" | awk '{ print $3; }')
        
        if [[ $zoo_node_count -lt 50000 ]]; then
            echo "$zoo node count is $zoo_node_count"
        else
            error "Error: $zoo node count is $zoo_node_count"
        fi
        
        if [[  $curr_zoo =~ "leader" ]]; then
            echo "$zoo is zookeeper leader"
            zoo_leader="$zoo_leader $zoo"
        elif [[  $curr_zoo =~ "follower" ]]; then
            echo "$zoo is zookeeper follower"
        elif [[  $curr_zoo =~ "standalone" ]]; then
            warn "$zoo is zookeeper standalone!"
            zoo_leader="$zoo_leader $zoo"
        else
            error "$zoo appears to have failed!! (not follower/leader/standalone)"
            kubectl -n $zoo_ns get pod $zoo --no-headers -o wide
            zoo_error=1
        fi
        
        zoo_num=$((zoo_num + 1))
        
        # Check the disk usage of the Zookeeper pod
        zoo_df=$(kubectl -n $zoo_ns exec $zoo -- df /var/lib/zookeeper | awk '{ print $5; }' | tail -1 | sed s/%//)
        [[ $zoo_df -gt $df_free ]] && error "Found zookeeper volume at ${zoo_df}% usage on $zoo!!"
    done
    
    if [[ $zoo_num -gt 3 ]]; then
        error "Found $zoo_num Zookeeper Pods $zoos!!"
        zoo_error=1
    fi
    if [[ $zoo_num -eq 0 ]]; then
        error "Found Zero Zookeeper Pods!!"
        zoo_error=1
    else
        [[ $zoo_num -eq 1 ]] && warn "Found One Zookeeper Pod." && zoo_error=1
    fi
    
    if [ -z $zoo_leader ]; then
        error "No Zookeeper Leader found!!"
        zoo_error=1
    fi
    if [[ $(echo $zoo_leader | wc -w) -gt 1 ]]; then
        warn "Found Zookeeper Leaders $zoo_leader!"
        zoo_error=1
    fi
    
    [ $zoo_error -eq 0 ] && good "Zookeeper passed tests"
}


# testing kafka pods
kafka_test(){
    echo "Testing Kafka pods"
    kafka_ns=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=kafka --no-headers | awk '{print $1}'|head -1)
    kafkas=$(kubectl get pod -n $kafka_ns -l nirmata.io/service.name=kafka --no-headers | awk '{print $1}')
    kaf_num=0
    kaf_error=0
    for kafka in $kafkas; do
        echo "Found Kafka Pod $kafka"
        kafka_df=$(kubectl -n $kafka_ns exec $kafka -- df /var/lib/kafka | awk '{ print $5; }' | tail -1 | sed s/%//)
        [[ $kafka_df -gt $df_free ]] && error "Found Kafka volume at ${kafka_df}% usage on $kafka"
        kaf_num=$((kaf_num + 1));
    done
    [[ $kaf_num -gt 3 ]] && error "Found $kaf_num Kafka Pods $kafkas!!!" && kaf_error=1
    if [[ $kaf_num -eq 0 ]];then
        error "Found Zero Kafka Pods!!!"
        kaf_error=1
    elif [[ $kaf_num -lt 3 ]]; then
        warn "Found $kaf_num Kafka Pod!"
        kaf_error=1
    fi
    for kafka in $kafkas; do
        kubectl exec $kafka -n $kafka_ns -- sh -c "nc -z 127.0.0.1 9092 > /dev/null 2>&1"
        stat=$?
        if [ $stat -eq 0 ]; then
            good "$kafka API is healthy!"
        else
            error "$kafka API is unhealthy!"
            kaf_error=1
        fi
    done
    [[ $kaf_error -eq 0 ]] && good "Kafka passed tests"
}

kafka_controller_test(){
    echo "Testing Kafka controller pods"
    kafka_controller_ns=$kafka_ns
    kafka_controllers=$(kubectl get pod -n $kafka_controller_ns -l nirmata.io/service.name=kafka-controller --no-headers | awk '{print $1}')
    kaf_cont_num=0
    kaf_cont_error=0
    for kafka_controller in $kafka_controllers; do
        echo "Found Kafka Controller Pod $kafka_controller"
        kafka_controller_df=$(kubectl -n $kafka_controller_ns exec $kafka_controller -- df /var/lib/kafka | awk '{ print $5; }' | tail -1 | sed s/%//)
        [[ $kafka_controller_df -gt $df_free ]] && error "Found Kafka volume at ${kafka_df}% usage on $kafka_controller"
        kaf_cont_num=$((kaf_cont_num + 1));
    done
    [[ $kaf_cont_num -gt 3 ]] && error "Found $kaf_cont_num Kafka Controller Pods $kafka_controllers!!!" && kaf_cont_error=1
    if [[ $kaf_cont_num -eq 0 ]];then
        error "Found Zero Kafka Controller Pods!!!"
        kaf_cont_error=1
    elif [[ $kaf_cont_num -lt 3 ]]; then
        warn "Found $kaf_cont_num Kafka Controller Pod!"
        kaf_cont_error=1
    fi
    for kafka_controller in $kafka_controllers; do
        kubectl exec $kafka_controller -n $kafka_controller_ns -- sh -c "nc -z 127.0.0.1 9093 > /dev/null 2>&1"
        stat=$?
        if [ $stat -eq 0 ]; then
            good "$kafka_controller API is healthy!"
        else
            error "$kafka_controller API is unhealthy!"
            kaf_cont_error=1
        fi
    done
    [[ $kaf_cont_error -eq 0 ]] && good "Kafka Controller passed tests"
}

#function to email results
do_email(){
if [[ $email -eq 0 ]];then
    # Check for certs in the cronjob's container
    if [ -e /certs/ ];then
        cp -f /certs/*.crt /usr/local/share/ca-certificates/
        update-ca-certificates
    fi
    [ -z $logfile ] && logfile="/tmp/k8_test.$$"
    [ -z $EMAIL_USER ] && EMAIL_USER="" #would this ever work?
    [ -z $EMAIL_PASSWD ] && EMAIL_PASSWD="" #would this ever work?
    [ -z $FROM ] && FROM="k8@nirmata.com" && warn "You provided no From address using $FROM"
    [ -z "$SUBJECT" ] && SUBJECT="K8 test script error" && warn "You provided no Subject using $SUBJECT"
    [ -z $SMTP_SERVER ] && error "No smtp server given!!!" && exit 1
    # This needs to be redone
    if [[ ${alwaysemail} -eq 0 || ${error} -gt 0 || ${warn} -gt 0 ]]; then
        if [[ $warnok -eq 0 ]];then
            if [[ ${alwaysemail} -ne 0 ]];then
                if [[ ${error} -eq 0 ]];then
                    return 0
                fi
            fi
        fi

        #Let's wait for the file to sync in case tee is buffered
        echo; echo; echo
        sleep 2
        # Reformat the log file for better reading and shell check can bite me.
        # shellcheck disable=SC1012,SC2028,SC2116
        BODY=$(sed -e 's/\x1b\[[0-9;]*m//g' -e 's/$'"/$(echo \\\r)/" ${logfile})
        for email_to in $TO; do
            if type -P "sendEmail" &>/dev/null; then
                if [ -n "$PASSWORD" ];then
                    echo $BODY |sendEmail -t "$email_to" -f "$FROM" -u \""$SUBJECT"\" -s "$SMTP_SERVER" "$EMAIL_OPTS"
                else
                    echo $BODY |sendEmail -t "$email_to" -f "$FROM" -u \""$SUBJECT"\" -s "$SMTP_SERVER" -xu "$EMAIL_USER" -xp "$EMAIL_PASSWD" "$EMAIL_OPTS"
                fi
            else
                docker run $sendemail $email_to $FROM "$SUBJECT" "${BODY}" $SMTP_SERVER "$EMAIL_USER" "$EMAIL_PASSWD" "$EMAIL_OPTS"
            fi
            #If they named it something else don't delete
            rm -f /tmp/k8_test.$$
        done
    fi
fi
}

# This tests the sanity of your k8 cluster
cluster_test(){
    command -v kubectl &>/dev/null || error 'No kubectl found in path!!!'
    echo "Starting Cluster Tests"
    # Setup a DaemonSet to test dns on all nodes.
    echo 'apiVersion: extensions/v1beta1
kind: DaemonSet
metadata:
  name: nirmata-net-test-all
spec:
  template:
    metadata:
      labels:
        app: nirmata-net-test-all-app
    spec:
      containers:
        - name: nirmata-net-test-node
          image: nicolaka/netshoot
          command: [ "/bin/sh", "-c", "sleep  100000" ]' >/tmp/nirmata-net-test-all.yml

    namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
    for ns in $namespaces;do
            kubectl --namespace=$ns delete ds nirmata-net-test-all --ignore-not-found=true &>/dev/null
    done
    kubectl --namespace=$namespace delete ds nirmata-net-test-all --ignore-not-found=true &>/dev/null

    if [ $allns -eq 1 ];then
        namespaces=$namespace
    fi
    for ns in $namespaces;do
        kubectl --namespace=$ns apply -f /tmp/nirmata-net-test-all.yml &>/dev/null
    done
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
    required_pods=$(kubectl get node --no-headers | awk '{print $2}' |grep -c Ready )
    num_ns=$(echo $namespaces |wc -w)
    required_pods=$((required_pods * num_ns))
    #echo required_pods is $required_pods
    echo -n 'Waiting for nirmata-net-test-all pods to start'
    until [[ $(kubectl get pods -l app=nirmata-net-test-all-app --no-headers --all-namespaces|awk '{print $4}' |grep -c Running) -ge $required_pods ]]|| \
      [[ $times = 60 ]];do
        sleep 1;
        echo -n .;
        times=$((times + 1));
    done
    echo

    # Do we have at least as many pods as nodes? (Do we care enough to do a compare node to pod?)
    if [[ $(kubectl -n $namespace get pods -l app=nirmata-net-test-all-app --no-headers |awk '{print $3}' |grep -c Running) -ne \
      $(kubectl get node --no-headers | awk '{print $2}' |grep -c Ready) ]] ;then
        error 'Failed to start nirmata-net-test-all on all nodes!!'
        echo Debugging:
        kubectl get pods -l app=nirmata-net-test-all-app -o wide
        kubectl get node
    fi

    dns_error=0
    for ns in $namespaces;do
        echo Testing $ns namespace
    for pod in $(kubectl -n $ns get pods -l app=nirmata-net-test-all-app --no-headers |grep Running |awk '{print $1}');do
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

    for pod in $(kubectl -n $ns get pods -l app=nirmata-net-test-all-app --no-headers |grep Running |awk '{print $1}');do
      root_df=$(kubectl -n $ns exec $pod -- df / | awk '{ print $5; }' | tail -1 | sed s/%//)
      [[ $root_df -gt $df_free_root ]] && ( node=$(kubectl get pod $pod -o=custom-columns=NODE:.spec.nodeName) ;\
        error "Found docker partition ${root_df}% usage on $node" ; )

    done
    namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
    for ns in $namespaces;do
      kubectl --namespace=$ns delete ds nirmata-net-test-all --ignore-not-found=true &>/dev/null
    done

    # Test if metrics service is enabled
    if kubectl get deployment -n kube-system metrics-server > /dev/null 2>&1; then
        good "Metric server is installed."
    else
        warn "Metric server is not installed."
    fi

    NAMESPACE="devtest5"

    # Get all deployments in the specified namespace
    deployments=$(kubectl get deployments -n "$NAMESPACE" -o json)

    # Check if there are any deployments
    if [[ $(echo "$deployments" | jq '.items | length') -eq 0 ]]; then
        echo "No deployments found in namespace $NAMESPACE."
        exit 0
    fi

    # Initialize a flag to track the status
    all_deployments_ok=true

    # Loop through each deployment
    echo "$deployments" | jq -c '.items[]' | while read -r deployment; do
        name=$(echo "$deployment" | jq -r '.metadata.name')
        desired_replicas=$(echo "$deployment" | jq -r '.spec.replicas')

        # Get the pods associated with the deployment
        pods=$(kubectl get pods -n "$NAMESPACE" -l app="$name" -o json)

        # Check if all pods are ready
        all_pods_ready=true
        echo "$pods" | jq -c '.items[]' | while read -r pod; do
            pod_name=$(echo "$pod" | jq -r '.metadata.name')
            pod_status=$(echo "$pod" | jq -r '.status.conditions[] | select(.type=="Ready") | .status')

            if [[ "$pod_status" != "True" ]]; then
                echo "Pod $pod_name in deployment $name is not ready."
                all_pods_ready=false
            fi
        done

        if [[ "$all_pods_ready" == true ]]; then
            echo "All pods in deployment $name are ready."
        else
            all_deployments_ok=false
        fi
    done

    # Exit with a status based on the deployments' health
    if [ "$all_deployments_ok" = true ]; then
        good "All deployments in namespace $NAMESPACE are fully functional."
    else
        warn "Some deployments in namespace $NAMESPACE are not fully functional."
    fi

}

# Function to check bidirectional connectivity to the load balancer DNS on port 443
check_connectivity() {
    local lb_dns=$1

    # # Check connectivity using curl
    # if curl -s --connect-timeout 5 "https://$lb_dns:443" > /dev/null; then
    #     good "Successfully connected to $lb_dns on port 443."
    # else
    #     error "Failed to connect to $lb_dns on port 443."
    # fi

    # Check connectivity using curl
    echo "Checking bidirectional connectivity to $lb_dns on port 443..."
    if curl -k -v --connect-timeout 5 "https://$lb_dns:443" 2>&1 | grep -q "Connected to"; then
        good "Successfully connected to $lb_dns on port 443."
    else
        error "Failed to connect to $lb_dns on port 443."
    fi

    # Check if the port is open using nc (netcat)
    if command -v nc &>/dev/null; then
        if nc -z -v -w5 "$lb_dns" 443; then
            good "Port 443 is open on $lb_dns."
        else
            error "Port 443 is not open on $lb_dns."
        fi
    else
        error "'nc' (netcat) is not installed. Please install it using the appropriate command for your OS."
        if [[ -f /etc/os-release ]]; then
            . /etc/os-release
            case $ID in
                ubuntu|debian)
                    echo "sudo apt update && sudo apt install netcat"
                    ;;
                centos|rhel|fedora)
                    echo "sudo yum install nc"  # Using yum instead of dnf for broader compatibility
                    ;;
                *)
                    echo "Please install netcat using your package manager."
                    ;;
            esac
        else
            error "Unable to determine the OS. Please install netcat using your package manager."
        fi
        # exit 1
    fi
}


# test if your local system can run k8
#!/bin/bash
# Function to check bidirectional connectivity using nc (netcat)
#!/bin/bash
# Function to perform local tests
local_test() {
    echo "Starting Local Tests"

    # Ask if running on a Nirmata managed cluster
    read -p "Are you running the script on a Nirmata managed cluster? (yes/no): " nirmata_response
    if [[ "$nirmata_response" == "yes" ]]; then
        echo "Continuing with Nirmata managed cluster tests..."
        # Add your Nirmata managed cluster logic here
        echo "Running Nirmata specific tests..."
        # You can add the logic for Nirmata-specific tests here

    elif [[ "$nirmata_response" == "no" ]]; then
        # Since it's not a Nirmata managed cluster, ask about the base cluster
        read -p "Are you running on the base cluster node? (yes/no): " base_cluster_response
        if [[ "$base_cluster_response" == "yes" ]]; then
            # Ask for load balancer DNS
            read -p "Please provide the load balancer DNS: " lb_dns
            echo "Checking bidirectional connectivity to $lb_dns on port 443..."
            check_connectivity "$lb_dns"
        else
            error "You are not on a Nirmata managed cluster or base cluster node. Exiting."
            exit 1
        fi
    else
        error "Invalid response. Please answer 'yes' or 'no'."
        exit 1
    fi

# Function to check if all proxy configurations are present in a given file
check_proxy_in_file() {
  local file_path=$1
  local missing_params=()
  local params=("HTTP_PROXY" "HTTPS_PROXY" "NO_PROXY" "http_proxy" "https_proxy" "no_proxy")

  if [ -f "$file_path" ]; then
    for param in "${params[@]}"; do
      if ! grep -q -e "$param" "$file_path"; then
        missing_params+=("$param")
      fi
    done

    if [ ${#missing_params[@]} -eq 0 ]; then
      good "All proxy configurations are found in $file_path"
    else
      warn "Missing proxy configurations in $file_path: ${missing_params[*]}"
    fi
  else
    error "$file_path does not exist. Please follow the pre-req document to add the proxy details"
  fi
}

if command -v docker &>/dev/null; then
    CONTAINER_RUNTIME="docker"
    echo "[INFO] Docker is installed. Proceeding with Docker checks."

    # Check Docker service configuration
    echo "Checking Docker proxy configuration..."
    check_proxy_in_file "/etc/systemd/system/docker.service.d/http-proxy.conf"

elif command -v podman &>/dev/null; then
    CONTAINER_RUNTIME="podman"
    echo "[INFO] Podman is installed. Proceeding with Podman checks."

    # Check Podman service configuration
    echo "Checking Podman proxy configuration..."
    check_proxy_in_file "/usr/lib/systemd/system/podman.service"

else
    echo "[ERROR] Neither Docker nor Podman is installed. Exiting."
    exit 1
fi

# Check containerd service configuration
echo "Checking containerd proxy configuration..."
check_proxy_in_file "/etc/systemd/system/containerd.service"

# Check node level proxy settings
echo "Checking node level proxy settings..."
check_proxy_in_file "/etc/profile.d/proxy.sh"

echo "Proxy configuration check completed."


# Kubelet generally won't run if swap is enabled.
fix_issues=0  # Set to 1 if you want to apply fixes, otherwise keep it as 0

# Check if swap is enabled
if [[ $(swapon -s | wc -l) -gt 1 ]]; then
    error "Swap is currently enabled!"
    
    if [[ $fix_issues -eq 0 ]]; then
        echo "Please disable swap to avoid issues. You can run the following commands:"
        echo "1. Disable swap: swapoff -a"
        echo "2. Remove swap entry from /etc/fstab: sed -i '/[[:space:]]*swap[[:space:]]*swap/d' /etc/fstab"
    else
        warn "Found swap enabled, disabling it now..."
        echo_cmd swapoff -a
        echo_cmd sed -i '/[[:space:]]*swap[[:space:]]*swap/d' /etc/fstab
    fi
else
    good "No swap found."
fi


# Check SELinux status
if type sestatus &>/dev/null; then
    if sestatus | grep "Current mode:" | grep -q -e enforcing; then
        error "SELinux is currently enabled and enforcing!"
        sestatus
        
        if [[ $fix_issues -eq 0 ]]; then
            echo "Please consider the following changes to disable SELinux if you are having issues:"
            echo '  sed -i s/^SELINUX=.*/SELINUX=permissive/ /etc/selinux/config'
            echo '  setenforce 0'
        else
            warn "Applying fixes to set SELinux to permissive mode..."
            echo_cmd sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config
            echo_cmd setenforce 0
        fi
    else
        good "SELinux is not enforcing."
    fi
else
    warn "sestatus command not found. Unable to check SELinux status."
fi
# Test kernel IP forward settings
if grep -q 0 /proc/sys/net/ipv4/ip_forward; then
    echo "net.ipv4.ip_forward is set to 0"
    echo "Consider applying the following changes to enable IP forwarding:"
    echo '  sysctl -w net.ipv4.ip_forward=1'  # Suggest command to enable IP forwarding temporarily
    echo '  echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf'  # Suggest command to persist the change
else
    echo "IP forwarding is enabled."
fi

# Verify if the Docker CE repository is enabled
if yum repolist enabled | grep -q "docker-ce-stable"; then
    # Attempt to list packages from the Docker CE repository to verify access
    if sudo yum --disablerepo="*" --enablerepo="docker-ce-stable" list available docker-ce > /dev/null 2>&1; then
        good "Docker CE repository is accessible, and packages can be downloaded."
    else
        error "Docker CE repository is enabled, but packages cannot be downloaded. 
        Action Required: Verify if the repository URL is whitelisted in your network/proxy settings. 
        Ensure that the node has access or the necessary permissions to access the repository."
    fi
else
    error "Docker CE repository is not enabled or not added correctly. 
    Action Required: Re-add the repository using:
    sudo yum-config-manager --add-repo https://download.docker.com/linux/rhel/docker-ce.repo
    Ensure that the repository is whitelisted in your network/proxy settings."
fi


# Ask if running on a Nirmata managed cluster
if [[ "$nirmata_response" == "yes" ]]; then
    echo "Skipping Kubernetes repository check for Nirmata managed cluster."

elif [[ "$nirmata_response" == "no" && "$base_cluster_response" == "yes" ]]; then
    # Verify if the Kubernetes repository is enabled for base cluster
    if yum repolist enabled | grep -q "kubernetes"; then
        # Attempt to list packages from the Kubernetes repository to verify access
        if sudo yum --disablerepo="*" --enablerepo="kubernetes" list available kubectl > /dev/null 2>&1; then
            good "Kubernetes repository is accessible, and packages can be downloaded."
        else
            error "Kubernetes repository is enabled, but packages cannot be downloaded.
            Action Required: Verify if the repository URL is whitelisted in your network/proxy settings.
            Ensure that the node has access or the necessary permissions to access the repository."
        fi
    else
        error "Kubernetes repository is not enabled or not added correctly. Please whitelist if this node is for Base Cluster otherwise Ignore it, Not required for the Nirmata Managed Cluster.
        Action Required: Re-add the repository using:
        cat <<EOF | sudo tee /etc/yum.repos.d/kubernetes.repo
        [kubernetes]
        name=Kubernetes
        baseurl=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/
        enabled=1
        gpgcheck=1
        gpgkey=https://pkgs.k8s.io/core:/stable:/v1.29/rpm/repodata/repomd.xml.key
        exclude=kubelet kubeadm kubectl cri-tools kubernetes-cni
        EOF
        Ensure that the repository is whitelisted in your network/proxy settings."
    fi

else
    error "Invalid response for Nirmata or Base Cluster. Exiting."
    exit 1
fi


#check for br netfilter
if [ ! -e /proc/sys/net/bridge/bridge-nf-call-iptables ];then
    if [[ $fix_issues -eq 0 ]];then
        warn '/proc/sys/net/bridge/bridge-nf-call-iptables does not exist!'
        echo "Applying the following fixes"
        echo_cmd modprobe br_netfilter
        echo_cmd echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf
    else
        error '/proc/sys/net/bridge/bridge-nf-call-iptables does not exist!'
        echo 'Is the br_netfilter module loaded? "lsmod |grep br_netfilter"'
        echo Consider the following changes:
        echo '  modprobe br_netfilter'
        echo '  echo "br_netfilter" > /etc/modules-load.d/br_netfilter.conf'
    fi
else
    good bridge-nf-call-iptables module loaded
fi
if grep -q 0 /proc/sys/net/bridge/bridge-nf-call-iptables;then
    if [[ $fix_issues -eq 0 ]];then
        error "Bridge netfilter disabled!!"
        echo "Applying the following fixes"
        echo_cmd sysctl -w net.bridge.bridge-nf-call-iptables=1
        echo_cmd echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf
    else
        echo Consider the following changes:
        echo '  sysctl -w net.bridge.bridge-nf-call-iptables=1'

        echo '  echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf'
    fi
else
    good bridge-nf-call-iptables enabled
fi

#TODO check for proxy settings, how, what, why
# Do we really need this has anyone complained?


# # Function to check if a port is enabled in iptables
# check_port() {
#     local port=$1
#     local protocol=$2
#     if sudo iptables -C INPUT -p "$protocol" --dport "$port" -j ACCEPT &>/dev/null ||
#        sudo iptables -C FORWARD -p "$protocol" --dport "$port" -j ACCEPT &>/dev/null; then
#         good "Port $port/$protocol is enabled in iptables."
#     else
#         warn "Port $port/$protocol is NOT enabled in iptables."
#     fi
# }

# # Initialize flags
# error_found=false
# port_error_found=false

# # Function to check if a port is enabled in iptables
# check_port() {
#     local port=$1
#     local protocol=$2
#     if sudo iptables -C INPUT -p "$protocol" --dport "$port" -j ACCEPT &>/dev/null ||
#        sudo iptables -C FORWARD -p "$protocol" --dport "$port" -j ACCEPT &>/dev/null; then
#         good "Port $port/$protocol is enabled in iptables."
#     else
#         port_error_found=true  # Set the port error flag
#     fi
# }

# # Verify specific ports
# declare -a ports=(2379 2380 6443 8090 8091 8472 10250 10251 10252 10255 10256 10257 10259 179 9099 4789)

# for port in "${ports[@]}"; do
#     check_port "$port" "tcp"
# done

# # Additional cluster ports (incoming and outgoing)
# check_port 53 udp    # DNS
# check_port 8472 udp    # DNS
# check_port 443 tcp   # HTTPS
# check_port 30000:32768 tcp   # NodePort range

# # Check if any errors were found
# if $port_error_found; then
#     # Check if all inbound and outbound traffic is allowed
#     allowed_inbound=$(sudo iptables -L INPUT -n | grep -E 'ACCEPT' | wc -l)
#     allowed_outbound=$(sudo iptables -L OUTPUT -n | grep -E 'ACCEPT' | wc -l)

#     # If all inbound and outbound are allowed
#     if [[ $allowed_inbound -gt 0 && $allowed_outbound -gt 0 ]]; then
#         good "All inbound and outbound traffic is allowed in iptables. All looks good, no action required."
#     else
#         error "Please reach out to the UNIX team to enable the required ports in iptables."
#     fi
# else
#     good "All required ports are enabled in iptables. All looks good, no action required."
# fi


    # # Function to check if a port is enabled in iptables
    # check_port() {
    #     local port=$1
    #     local protocol=$2
    #     if sudo iptables -C INPUT -p "$protocol" --dport "$port" -j ACCEPT &>/dev/null ||
    #     sudo iptables -C FORWARD -p "$protocol" --dport "$port" -j ACCEPT &>/dev/null; then
    #         good "Port $port/$protocol is enabled in iptables."
    #     else
    #         error "Port $port/$protocol is NOT enabled in iptables."
    #         missing_ports+=("$port")  # Add the missing port to the list
    #     fi
    # }

    # # Initialize flags
    # error_found=false
    # port_error_found=false
    # missing_ports=()  # Initialize an array to track missing ports

    # # Verify specific ports for Nirmata Managed Cluster (check when nirmata_response == "yes")
    # check_port() {
    #     local port=$1
    #     local protocol=$2
    #     # Check if the port is present in the iptables output
    #     if sudo iptables -L -v -n | grep -q "$protocol.*dpt:$port"; then
    #         good "Port $port/$protocol is enabled in iptables."
    #     else
    #         error "Port $port/$protocol is NOT enabled in iptables."
    #         missing_ports+=("$port")  # Add the missing port to the list
    #     fi
    # }

    # # Initialize flags
    # error_found=false
    # port_error_found=false
    # missing_ports=()  # Initialize an array to track missing ports

    # # Verify specific ports for Nirmata Managed Cluster (check when nirmata_response == "yes")
    # if [[ "$nirmata_response" == "yes" ]]; then
    #     # Ports specific to Nirmata Managed Cluster
    #     declare -a nirmata_ports=(2379 2380 6443 8090 8091 8472 10250 10255 10256 10257 10259 179 9099 4789 443 30000-32767)
    #     for port in "${nirmata_ports[@]}"; do
    #         check_port "$port" "tcp"
    #     done
    #     for port in "${nirmata_ports[@]}"; do
    #         check_port "$port" "udp"
    #     done
    # fi

    # # Verify additional ports for Base Cluster (check when base_cluster_response == "yes")
    # if [[ "$base_cluster_response" == "yes" ]]; then
    #     # Additional ports for Base Cluster
    #     declare -a base_ports=(31111:31169 80:30141 1936:30142 9093 27017 80 9090 8443 2888 3888 2181)
    #     for port in "${base_ports[@]}"; do
    #         check_port "$port" "tcp"
    #     done
    #     for port in "${base_ports[@]}"; do
    #         check_port "$port" "udp"
    #     done
    # fi

    # # If any ports are missing, print them out
    # if [ ${#missing_ports[@]} -gt 0 ]; then
    #     echo "The following ports are missing from iptables and need to be added:"
    #     for port in "${missing_ports[@]}"; do
    #         echo "- Port $port"
    #     done
    # else
    #     echo "All required ports are enabled in iptables. All looks good, no action required."
    # fi

    # Function to check if a port is enabled in iptables
    check_port() {
        local port=$1
        local protocol=$2

        # if sudo iptables -L -v -n | grep -q "$protocol.*dpt:$port"; then
        #     good "Port $port/$protocol is enabled in iptables."
        # else
        #     error "Port $port/$protocol is NOT enabled in iptables."
        #     missing_ports+=("$port/$protocol")  # Add the missing port and protocol to the list
        # fi
        if sudo iptables -L -v -n | grep -q "$protocol.*dpts\?:$port"; then
            good "Port $port/$protocol is enabled in iptables."
        else
            error "Port $port/$protocol is NOT enabled in iptables."
            missing_ports+=("$port")  # Add the missing port to the list
        fi
    }

    # Initialize flags and arrays
    missing_ports=()
    error_found=false

    # Ports and protocols for Managed Cluster
    declare -a managed_ports_tcp=(2379 2380 6443 8090 8091 10250 10255 10256 10257 10259 179 9099 443)
    declare -a managed_ports_udp=(8472 4789)
    declare -a managed_port_ranges_tcp=(30000:32767)

    # Ports and protocols for Base Cluster
    declare -a base_ports_tcp=(2379 2380 6443 8090 8091 10250 10255 10256 10257 10259 179 9099 443 9093 27017 80 9090 8443 2888 3888 2181)
    declare -a base_ports_udp=(8472 4789)
    declare -a base_port_ranges_tcp=(30000:32767 31111:31169 80:30141 1936:30142)

    # Check ports for Managed Cluster if enabled
    if [[ "$nirmata_response" == "yes" ]]; then
        echo "Checking ports for Managed Cluster..."

        # Check individual TCP ports
        for port in "${managed_ports_tcp[@]}"; do
            check_port "$port" "tcp"
        done

        # Check individual UDP ports
        for port in "${managed_ports_udp[@]}"; do
            check_port "$port" "udp"
        done

        # Check TCP port ranges
        for range in "${managed_port_ranges_tcp[@]}"; do
            check_port "$range" "tcp"
        done
    fi

    # Check ports for Base Cluster if enabled
    if [[ "$base_cluster_response" == "yes" ]]; then
        echo "Checking ports for Base Cluster..."

        # Check individual TCP ports
        for port in "${base_ports_tcp[@]}"; do
            check_port "$port" "tcp"
        done

        # Check individual UDP ports
        for port in "${base_ports_udp[@]}"; do
            check_port "$port" "udp"
        done

        # Check TCP port ranges
        for range in "${base_port_ranges_tcp[@]}"; do
            check_port "$range" "tcp"
        done
    fi

    # Print missing ports if any
    if [ ${#missing_ports[@]} -gt 0 ]; then
        echo "The following ports are missing from iptables and need to be added:"
        for port in "${missing_ports[@]}"; do
            echo "- $port"
        done
        error_found=true
    else
        echo "All required ports are enabled in iptables. All looks good, no action required."
    fi

# Function to check if a port is open via telnet
check_telnet() {
    local host=$1
    local port=$2
    local component=$3
    local timeout=5
    local output

    # Use telnet to check port and capture output
    output=$( (echo > /dev/tcp/$host/$port) 2>&1 )
    if [ $? -eq 0 ]; then
        good "Connection to $host:$port ($component) successful via telnet."
    else
        if echo "$output" | grep -q "timed out"; then
            if [[ "$port" == "8472" || "$port" == "8285" ]]; then
                error "Connection to $host:$port ($component) timed out. Please ensure this port is allowed if this is the base cluster node. Output: $output"
            else
                error "Connection to $host:$port ($component) timed out. Output: $output"
            fi
        elif echo "$output" | grep -q "Connection refused"; then
            good "Connection to $host:$port ($component) refused. Output: $output"
        else
            warn "Connection to $host:$port ($component) failed. Output: $output"
        fi
    fi
}

# Detect node IP
CURRENT_IP=$(hostname -I | awk '{print $1}')

# Performing checks on the same node
echo "Current IP: $CURRENT_IP"
echo "Performing checks on the node with IP $CURRENT_IP..."

# Ports and components for the node
declare -A PORTS=(
    [6443]="Kubernetes API Server"
    [2379]="etcd"
    [10259]="KubeScheduler"
    [10257]="Controller-Manager"
    [10250]="kubelet"
    [10256]="kube-proxy"
    [179]="BGP"
    [9099]="Custom Service"
    [4789]="VXLAN"
)

for port in "${!PORTS[@]}"; do
    component=${PORTS[$port]}
    echo "Checking $component on port $port from $CURRENT_IP..."
    check_telnet "$CURRENT_IP" "$port" "$component"
done

# Check for Flannel specific ports
FLANNEL_PORTS=(
    [8472]="Flannel VXLAN"
    [8285]="Flannel API"
)

for port in "${!FLANNEL_PORTS[@]}"; do
    component=${FLANNEL_PORTS[$port]}
    echo "Checking $component on port $port from $CURRENT_IP..."
    check_telnet "$CURRENT_IP" "$port" "$component"
done

# Random NodePort check (30000-32767)
RANDOM_PORT=$((30000 + RANDOM % 2768))
echo "Checking random NodePort $RANDOM_PORT on $CURRENT_IP..."
check_telnet "$CURRENT_IP" "$RANDOM_PORT" "NodePort"

# Final output
echo "Port checks completed for node with IP $CURRENT_IP."

# Container runtime service check script
# Determine if Docker or Podman is installed
if command -v docker &>/dev/null; then
    CONTAINER_RUNTIME="docker"
    echo "[INFO] Docker is installed. Proceeding with Docker checks."

    # Test for Docker service
    if ! systemctl is-active docker &>/dev/null ; then
        error 'Docker service is not active. Maybe you are using some other CRI?'
        if [[ $fix_issues -eq 0 ]]; then
            echo_cmd sudo systemctl start docker
        fi
    else
        good "Docker is running"
    fi

    if ! systemctl is-enabled docker &>/dev/null; then
        error 'Docker service is not starting at boot. Maybe you are using some other CRI?'
        if [[ $fix_issues -eq 0 ]]; then
            echo_cmd sudo systemctl enable docker
        fi
    else
        good "Docker is starting at boot"
    fi

    # Check for Docker mount point
    if docker info 2>/dev/null | grep -q mountpoint; then
        warn 'Docker does not have its own mountpoint'
        # Add any additional fix or handling steps if needed.
        # For example, you could add instructions for reconfiguring the storage driver.
    fi

elif command -v podman &>/dev/null; then
    CONTAINER_RUNTIME="podman"
    echo "[INFO] Podman is installed. Proceeding with Podman checks."

    if ! systemctl is-enabled podman &>/dev/null; then
        error 'Podman service is not starting at boot. Maybe you are using some other CRI?'
        if [[ $fix_issues -eq 0 ]]; then
            echo_cmd sudo systemctl enable podman
        fi
    else
        good "Podman is starting at boot"
    fi

    # Verify Podman configuration for runtime
    echo "[INFO] Checking Podman runtime configuration..."
    if grep -q 'runtime = "runc"' /usr/share/containers/containers.conf; then
        good "Podman is configured to use 'runc' as the runtime."
    else
        error "Podman is not configured to use 'runc' as the runtime. Please update the configuration."
        # Optional fix: add a line to update the configuration if needed
        # echo_cmd sudo sed -i 's/runtime = .*/runtime = "runc"/' /usr/share/containers/containers.conf
    fi

    # Ensure containernetworking-plugins is installed
    echo "[INFO] Checking if 'containernetworking-plugins' is installed..."
    if ! dnf list installed containernetworking-plugins &>/dev/null; then
        error "'containernetworking-plugins' is not installed."
        if [[ $fix_issues -eq 0 ]]; then
            echo_cmd sudo dnf install containernetworking-plugins -y
        fi
    else
        good "'containernetworking-plugins' is already installed."
    fi

else
    echo "[ERROR] Neither Docker nor Podman is installed. Exiting."
    exit 1
fi


# # Is the version of docker locked/held if not we are going to suffer death by upgrade.
# if [ ! -e /usr/bin/docker ];then
#   error no /usr/bin/docker
# fi
# if [ -e /usr/bin/dpkg ];then
#   dockerpkg=$(dpkg -S /usr/bin/docker |awk '{print $1}' |sed 's/:$//')
#   if [[ $dockerpkg =~ docker.io ]];then
#     if  sudo apt-mark showhold |grep -q docker.io; then
#       good docker.io package held
#     else
#        warn docker.io package is not held
#        if [[ $fix_issues -eq 0 ]];then
#          echo_cmd sudo apt-mark hold docker.io
#        fi
#     fi
#   else
#     if [[ $dockerpkg =~ docker-ce ]];then
#       if  sudo apt-mark showhold |grep -q docker-ce; then
#         good docker-ce package held
#       else
#         warn docker-ce package is not held
#         if [[ $fix_issues -eq 0 ]];then
#           echo_cmd sudo apt-mark hold docker-ce
#         fi
#       fi
#     fi
#   fi
# else
#   if [ -e /usr/bin/rpm ];then
#     if yum versionlock list |grep -q docker-ce;then
#       good docker versionlocked
#     else
#       warn docker is not versionlocked
#       if [[ $fix_issues -eq 0 ]];then
#         echo_cmd "yum install 'dnf-command(versionlock)'"
#       fi
#     fi
#   fi
# fi


# tests for containerd
if ! systemctl is-active containerd &>/dev/null ; then
    error 'Containerd service is not active? Maybe you are using some other CRI??'
else
    containerdVersion=$(containerd --version | awk '{print $3}')
    if [[ $containerdVersion < 1.6.19 ]] ;then
        error 'Install containerd version 1.6.19 or later'
    else
        CONFIG_FILE="/etc/containerd/config.toml"
        if grep -q 'SystemdCgroup = true' "$CONFIG_FILE"; then
            good Containerd is active
        else
            error "SystemdCgroup is not set to true in $CONFIG_FILE"
        fi
        
    fi
fi


check_kubernetes_processes() {
  local processes_found=false
  
  # List of processes to check
  local processes=("kube-proxy" "kube-apiserver" "kubelet" "kube-scheduler" "kube-controller-manager" "etcd")
  
  for process in "${processes[@]}"; do
    if pgrep -f "$process" > /dev/null; then
      processes_found=true
      error "Process '$process' is running. Verify it by running 'ps -ef | grep $process' and remove it using 'kill -9 $process'. Make Sure to cleanup the k8s processes using cluster-cleanup script before creating the Nirmata Managed Cluster cluster"
    fi
  done
  
  if ! $processes_found; then
    good "No Kubernetes-related processes found."
  fi
}

# Execute the process check
echo "Checking for Kubernetes-related processes..."
check_kubernetes_processes

echo "Process check completed."

# tests for systemd-resolved
if ! systemctl is-active systemd-resolved &>/dev/null ; then
    error 'systemd-resolved is not running!'
else
    good systemd-resolved is active
fi

# tests for firewalld
if systemctl is-active firewalld &>/dev/null ; then
    error 'firewalld is running, please turn it off using `sudo systemctl disable --now firewalld`'
else
    good firewalld is inactive
fi

#Customers often have time issues, which can cause cert issues.  Ex:cert is in future.
if type chronyc &>/dev/null;then
  if chronyc activity |grep -q "^0 sources online";then
    error "Chrony found, but no ntp sources reported!"
  else
    good Found Chrony with valid ntp sources.
  fi
else
  if type ntpq &>/dev/null;then
    if ntpq -c rv |grep -q 'leap=00,'; then
      good Found ntp and we appear to be syncing.
    else
      error "Found ntp client, but it appears to not be synced"
    fi
  else
    error "No ntp client found!!"
  fi
fi

# Determine if Docker or Podman is running and check for Nirmata agent service accordingly
if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null; then
    echo "Docker is running. Checking for Nirmata Docker agent..."
    if [ -e /etc/systemd/system/nirmata-agent.service ]; then
        echo "Found nirmata-agent.service. Testing Nirmata agent."
        test_agent
    else
        good "Nirmata agent service for Docker is not found!"
    fi
elif command -v podman &>/dev/null && systemctl is-active podman &>/dev/null; then
    echo "Podman is running. Checking for Nirmata Podman agent..."
    if [ -e /etc/systemd/system/nirmata-agent-podman.service ]; then
        echo "Found nirmata-agent-podman.service. Testing Nirmata Podman agent."
        test_agent
    else
        good "Nirmata agent service for Podman is not found!"
    fi
else
    echo "Neither Docker nor Podman is running. Checking for kubelet..."
    # Only perform kubelet check if it's a managed cluster (base_cluster_response is "no")
    if [[ "$nirmata_response" == "yes" ]]; then
        echo "Checking for kubelet..."
        if type kubelet &>/dev/null; then
            # Test for Kubernetes service
            echo "Found kubelet binary. Running local Kubernetes tests."
            echo -e "\e[33mNote: If you plan on running the Nirmata agent, remove this kubelet! \nIf this kubelet is running, it will prevent Nirmata's kubelet from running.\e[0m"

            if ! systemctl is-active kubelet &>/dev/null; then
                error 'Kubelet is not active?'
            else
                good "Kubelet is active"
            fi

            if ! systemctl is-enabled kubelet &>/dev/null; then
                if [[ $fix_issues -eq 0 ]]; then
                    echo "Applying the following fixes"
                    echo_cmd sudo systemctl enable kubelet
                else
                    error 'Kubelet is not set to run at boot?'
                fi
            else
                good "Kubelet is enabled at boot"
            fi

        else
            error "No Kubelet or Nirmata Agent found!"
        fi
    else
        echo "Skipping kubelet check for Base Cluster."
    fi


    if [ ! -e /opt/cni/bin/bridge ]; then
        error '/opt/cni/bin/bridge not found. Is your CNI installed?'
    fi
fi



    # Test if containerd configuration directory exists
    if [ -d '/etc/containerd' ]; then
        good "/etc/containerd is correctly mounted."
    else
        error "/etc/containerd is not mounted. Please mount it with the help of respective team."
    fi

    # # Test if containerd data directory exists (commonly used)
    # if [ -d '/var/lib/containerd' ]; then
    #     good "/var/lib/containerd exists."
    # else
    #     error "/var/lib/containerd does not exist."
    # fi

    # Test if Docker directory exists
    if [ -d '/var/lib/docker/containerd' ]; then
        good "/var/lib/docker/containerd exists."
        size=$(du -sh /var/lib/docker/containerd 2>/dev/null | awk '{print $1}')
        if [ -n "$size" ]; then
            good "Size of /var/lib/docker/containerd: $size."
        else
            warn "Could not determine the size of /var/lib/docker/containerd."
        fi
    else
        error "/var/lib/docker/containerd does not exist."
    fi


    # Test if Podman configuration directory exists
    if [ -d '/etc/containers' ]; then
        good "/etc/containers is correctly mounted."
    else
        error "/etc/containers is not mounted. Please mount it with the help of respective team."
    fi

    # Test if Podman data directory exists
    if [ -d '/var/lib/containers' ]; then
        good "/var/lib/containers exists."
    else
        error "/var/lib/containers does not exist. Please mount it with the help of respective team."
    fi
}

base_cluster_local(){
    # # Test for repository access
    # pullRes=$(docker login "$repository" 2>&1)

    # if [ $? -eq 0 ]; then
    #     good "Access to the repository is present."
    # else
    #     error "Cannot access the repository!"
    # fi

    # Test for zk, kafka and mongodb directory exists
    dirs=("/apps/nirmata/zk" "/apps/nirmata/kafka" "/apps/nirmata/mongodb")

    for dir in "${dirs[@]}"; do
        if [ -d $dir ]; then
            good "$dir is correctly mounted."
        else
            error "$dir is not mounted. Please mount it with the help of respective team."
        fi
    done

    # Test for Node Space Allocation (To be modified)
    paths="/apps/nirmata"

    for path in $paths; do
        if df -h | grep -q "$path"; then
            space_used=$(df -h | grep "$path" | awk '{print $5}' | sed 's/%//')
            if [ "$space_used" -gt 50 ]; then
                warn "Space usage for $path is at $space_used%, which exceeds the 50% threshold."
            else
                good "Space allocation for $path is at $space_used%, which is within the 50% threshold."
            fi
        else
            warn "$path is not found."
        fi
    done
}

# Test nirmata agent for nirmata built clusters
test_agent(){
echo "Testing Nirmata Agent"

if command -v docker &>/dev/null && systemctl is-active docker &>/dev/null; then
    # If Docker is running, check for nirmata-agent
    if systemctl is-active nirmata-agent &>/dev/null; then
        good "Nirmata Agent (Docker) is running"
    else
        error "Nirmata Agent (Docker) is not running"
    fi

    if systemctl is-enabled nirmata-agent &>/dev/null; then
        good "Nirmata Agent (Docker) is enabled at boot"
    else
        error "Nirmata Agent (Docker) is not enabled at boot"
    fi

    if docker ps | grep -q -e nirmata/nirmata-host-agent; then
        good "Found nirmata-host-agent (Docker)"
    else
        error "nirmata-host-agent (Docker) is not running!"
    fi

elif command -v podman &>/dev/null && systemctl is-active podman &>/dev/null; then
    # If Podman is running, check for nirmata-agent-podman
    if systemctl is-active nirmata-agent-podman &>/dev/null; then
        good "Nirmata Agent (Podman) is running"
    else
        error "Nirmata Agent (Podman) is not running"
    fi

    if systemctl is-enabled nirmata-agent-podman &>/dev/null; then
        good "Nirmata Agent (Podman) is enabled at boot"
    else
        error "Nirmata Agent (Podman) is not enabled at boot"
    fi

    if podman ps | grep -q -e nirmata/nirmata-host-agent; then
        good "Found nirmata-host-agent (Podman)"
    else
        error "nirmata-host-agent (Podman) is not running!"
    fi

else
    error "Neither Docker nor Podman is running or installed"
fi

# if docker ps |grep -q -e "hyperkube proxy";then
#     good Found hyperkube proxy
# else
#     error Hyperkube proxy is not running!
# fi
# if docker ps --no-trunc|grep -q -e 'hyperkube kubelet' ;then
#     good Found hyperkube kubelet
# else
#     error Hyperkube kubelet is not running!
# fi
# if docker ps |grep -q -e /opt/bin/flanneld ;then
#     good Found flanneld
# else
#     error Flanneld is not running!
# fi
# How do we determine if this is a master?
#maybe grep -e /usr/local/bin/etcd -e /nirmata-kube-controller -e /metrics-server -e "hyperkube apiserver"
#Are we sure these run only on the master?
#if docker ps |grep -q -e nirmata/nirmata-kube-controller;then
#    good Found nirmata-kube-controller
#else
#    error nirmata-kube-controller is not running!
#fi
#if docker ps |grep -q -e /metrics-server;then
#    good Found Metrics container
#else
#    error Metrics container is not running!
#fi
}

#start main script
# Do we need to log?
if [[ $email -eq 0 ]];then
    if [ -z $logfile ];then
        logfile="/tmp/k8_test.$$"
    fi
fi
if [[ -n $logfile ]];then
   exec > >(tee -i $logfile)
fi

echo "$0 version $version"

# Really you should be using ansible or the like to run this script remotely.
# That said not all customers have something like ansible so we're going do it old school and ugly.
if [[ $nossh -eq 1 ]];then
    if [[ -n $ssh_hosts ]];then
        for host in $ssh_hosts; do
            echo Testing host $host
            # No shellcheck this cat is not useless
            # shellcheck disable=SC2002
            cat $0 | ssh $host bash -c "cat >/tmp/k8_test_temp.sh ; chmod 755 /tmp/k8_test_temp.sh; /tmp/k8_test_temp.sh $script_args --nossh ; rm /tmp/k8_test_temp.sh"
            echo
            echo
        done
    # Should we break if this if fails?
    # What about return codes?
    fi
fi

# Actually run tests

#tests local system for compatiblity
if [[ $run_local -eq 0 ]];then
    local_test
fi

#tests local system for compatiblity
if [[ $run_base_cluster_local -eq 0 ]];then
    base_cluster_local
fi

# test kubernetes cluster
if [[ $run_remote -eq 0 ]];then
    kubectl get namespace $namespace >/dev/null || error "Can not find namespace $namespace tests may fail!!!"
    cluster_test
fi

#This tests nirmata's mongodb
if [[ $run_mongo -eq 0 ]];then
    kubectl get namespace $namespace >/dev/null || error "Can not find namespace $namespace tests may fail!!!"
    mongo_test
fi

#This tests nirmata's zookeeper
if [[ $run_zoo -eq 0 ]];then
    zoo_test
fi

#This tests nirmata's kafka (needs work, but Kafka only seems to have issues when zk does)
if [[ $run_kafka -eq 0 ]];then
    kafka_test
fi

if [[ $run_kafka_controller -eq 0 ]];then
    kafka_controller_test
fi

if [ $error != 0 ];then
    error "Test completed with errors!"
    do_email
    exit $error
fi
if [ $warn != 0 ];then
    warn "Test completed with warnings."
    if [ $warnok != 0 ];then
        do_email
        exit 2
    else
        warn "Warnings are being ignored."
        echo -e  "\e[32mTesting completed without errors\e[0m"
        do_email
        exit 0
    fi
fi
echo -e  "\e[32mTesting completed without errors or warning\e[0m"
do_email
exit 0
