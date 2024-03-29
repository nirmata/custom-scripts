#!/bin/bash
# shellcheck disable=SC1117,SC2086,SC2001

# This might be better done in python or ruby, but we can't really depend on those existing or having useful modules on customer sites or containers.

# This script has 3 functional modes.  You can in theory run all 3 modes, but really you should run them independently even when that makes sense.
# Test local system for K8 compatiblity, and basic custom cluster sanity tests. --local
# Test K8 for basic sanity --cluster
# Test Nirmata installation mainly mongodb. --nirmata
#    Note this script considers any nirmata installation that isn't HA to be in warning.

# Update the script to show the correct status of mongodb pods when they are in RECOVERY/DOWN/STARTUP status
version=1.1.3
# Url of script for updates
script_url='https://raw.githubusercontent.com/nirmata/k8_test/master/nirmata_test.sh'
# Should we update
update=1
# default external dns target
DNSTARGET=nirmata.com
# default service target
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
# These are used to run the mongo, zookeeper, and kafka tests by default to test the nrimata setup.
# Maybe we should fork this script to move the nirmata tests else where?
run_mongo=1
run_zoo=1
run_kafka=1
run_deploy=1
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
            # default to testing nirmata
            run_mongo=0
            run_zoo=0
            run_kafka=0
            run_deploy=0
        fi
    fi
fi
# Should we email by default?
email=1
# default sendemail containers Note NOT sendmail!
sendemail='ghcr.io/nirmata/sendemail'
alwaysemail=1
localmail=1
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
#set zookeeper maxs
zoo_latency_max=20
zoo_node_max=50000


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
    echo "--update                    Update script from $script_url"
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
    echo "--mail-local                Use mail command to send email."
    echo "Simple open smtp server:"
    echo "$0 --email --to testy@nirmata.com --smtp smtp.example.com"
    echo "Authenication with an smtp server:"
    echo "--email --to testy@nirmata.com --smtp smtp.example.com  --user sam.silbory --passwd 'foo!foo'"
    echo "Authenication with gmail: (Requires an app password be used!)"
    echo "--email --to testy@nirmata.com --smtp smtp.gmail.com:587  --user sam.silbory --passwd 'foo!foo'"
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
            run_deploy=0
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
        --mail-local)
            localmail=0
            shift
        ;;
        --warnok)
            script_args=" $script_args $1 "
            warnok=0
            shift
        ;;
        --update)
          update=0
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
        # Remember that shifting doesn't remove later args from the loop
        # We will exir on any arg with a - even if we shift it away.
        -*)
            helpfunction
            exit 1
        ;;
    esac
done
# We don't ever want to pass --ssh or --update.  We might get inception, but without DiCaprio.
script_args=$(echo $script_args |sed -e 's/--ssh//' -e 's/--update//')

# Update Script?
if [[ $update == 0 ]];then
  rm -f /tmp/nirmata_test.sh.download.$$
  if [ -x "$(command -v wget)" ];then
    wget -O /tmp/nirmata_test.sh.download.$$ $script_url || error "Download failed of $script_url"
  else
    if [ -x "$(command -v curl)" ];then
      curl $script_url -o  /tmp/nirmata_test.sh.download.$$ || error "Download failed of $script_url"
    else
      error "Unable to dowonload $script_url as we can't find curl or wget"
    fi
  fi
  if [ -e /tmp/nirmata_test.sh.download.$$ ];then
    basename=$(basename $0)
    dirname=$(dirname $0)
    fullname="$dirname/$basename"
    cp -f $fullname $fullname.bak
    cp -f /tmp/nirmata_test.sh.download.$$ $fullname
    rm -f /tmp/nirmata_test.sh.download.$$
    $fullname $script_args
    exit $?
  else
    error "Failed to update script"
  fi
fi

# shellcheck disable=SC2139
alias kubectl="kubectl $add_kubectl "

# Test mongodb pods
mongo_test(){
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
    # Check if the MongoDB pod is ready
    pod_status=$(kubectl get pod "$mongo" -n "$mongo_ns" -o jsonpath='{.status.phase}')
    pod_ready=$(kubectl get pod "$mongo" -n "$mongo_ns" -o jsonpath='{.status.containerStatuses[0].ready}')
    ready_status=$(kubectl get pod "$mongo" -n "$mongo_ns" -o jsonpath='{.status.containerStatuses[0].ready}/{.status.containerStatuses[0].started}')
    ready_count=$(kubectl get pod "$mongo" -n "$mongo_ns" -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep -o 'true' | wc -l)
    total_count=$(kubectl get pod "$mongo" -n "$mongo_ns" -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' | wc -l)

    if [[ "$pod_status" != "Running" ]]; then
      error "$mongo is not ready (Status: $pod_status)"
      mongo_error=1
      continue
    fi

    if [[ "$pod_ready" == "true" ]]; then
      good "$mongo is ready (Status: $pod_status, Ready: $ready_count/$total_count)"
    else
      error "$mongo is not ready (Status: $pod_status, Ready: $ready_count/$total_count)"
      mongo_error=1
    fi


    # Depending on the version of mongo we might have a sidecar.  We want to give kubectl the right container.
    if kubectl -n $mongo_ns get pod $mongo --no-headers |awk '{ print $2 }' |grep -q '[0-2]/2'; then
        mongo_container="-c mongodb"
    else
        mongo_container=""
    fi
    cur_mongo=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "db.serverStatus()" |mongo' 2>&1|grep  '"ismaster"')
    if [[  $cur_mongo =~ "true" ]];then
        echo "$mongo is master"
        mongo_master="$mongo_master $mongo"
        mongo_masters=$((mongo_masters+ 1));
    else
        if [[  $cur_mongo =~ "false" ]];then
            echo "$mongo is a slave"
        else
            warn "$mongo is not master or slave! (Are we standalone?)"
            mongo_error=1
            kubectl -n $mongo_ns get pod $mongo --no-headers -o wide
        fi
    fi
    mongo_df=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- df /data/db | awk '{ print $5; }' |tail -1|sed s/%//)
    if [[ $mongo_df -gt $df_free_mongo ]];then
        error "Found MongoDB volume at ${mongo_df}% usage on $mongo"
        kubectl -n $mongo_ns exec $mongo $mongo_container -- du --all -h /data/db/ |grep '^[0-9,.]*G'
    else
        good "Found MongoDB volume at ${mongo_df}% usage on $mongo"
    fi
    kubectl -n $mongo_ns exec $mongo $mongo_container -- du  -h /data/db/WiredTigerLAS.wt |grep '[0-9]G' && \
        warn "WiredTiger lookaside file is very large on $mongo. Consider increasing Mongodb memory."
    mongo_num=$((mongo_num + 1));
    mongo_stateStr_full=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "rs.status()" |mongo' 2>&1)
    if [[ $mongo = mongodb-0 ]]; then
        mongo_stateStr=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "rs.status()" |mongo' 2>&1 | grep stateStr |awk 'NR==1{ print; }')
    elif [[ $mongo = mongodb-1 ]]; then
        mongo_stateStr=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "rs.status()" |mongo' 2>&1 | grep stateStr |awk 'NR==2{ print; }')
    else
        mongo_stateStr=$(kubectl -n $mongo_ns exec $mongo $mongo_container -- sh -c 'echo "rs.status()" |mongo' 2>&1 | grep stateStr |awk 'NR==3{ print; }')
    fi
    if [[ $mongo_stateStr =~ RECOVERING || $mongo_stateStr =~ DOWN || $mongo_stateStr =~ STARTUP ]];then
        echo $mongo_stateStr_full
        if [[ $mongo_stateStr =~ RECOVERING ]];then warn "Detected recovering Mongodb from this node!"; mongo_error=1; fi
        if [[ $mongo_stateStr =~ DOWN ]];then error "Detected Mongodb in down state from this node!"; mongo_error=1 ; fi
        if [[ $mongo_stateStr =~ STARTUP ]];then warn "Detected Mongodb in startup state from this node!"; mongo_error=2; fi
    fi
done
if [[ $mongo_num -gt 3 ]];then
    # Are we ever goign to run more than 3 pods?
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
zoo_ns=$(kubectl get pod --all-namespaces -l 'nirmata.io/service.name in (zookeeper, zk)' --no-headers | awk '{print $1}'|head -1)
zoos=$(kubectl get pod -n $zoo_ns -l 'nirmata.io/service.name in (zookeeper, zk)' --no-headers | awk '{print $1}')
zoo_num=0
zoo_leader=""
for zoo in $zoos; do
    # Checking the Zookeeper pod status
    pod_status=$(kubectl get pod "$zoo" -n "$zoo_ns" -o jsonpath='{.status.phase}')
    pod_ready=$(kubectl get pod "$zoo" -n "$zoo_ns" -o jsonpath='{.status.containerStatuses[0].ready}')
    ready_count=$(kubectl get pod "$zoo" -n "$zoo_ns" -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep -o 'true' | wc -l)
    total_count=$(kubectl get pod "$zoo" -n "$zoo_ns" -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' | wc -l)

    if [[ "$pod_status" != "Running" ]]; then
      error "$zoo is not ready (Status: $pod_status)"
      zoo_error=1
      continue
    fi

    if [[ "$pod_ready" == "true" ]]; then
      good "$zoo is ready (Status: $pod_status, Ready: $ready_count/$total_count)"
    else
      error "$zoo is not ready (Status: $pod_status, Ready: $ready_count/$total_count)"
      zoo_error=1
    fi

    # zoo_num=$((zoo_num + 1))

    curr_zoo=$(kubectl -n $zoo_ns exec $zoo -- sh -c "/opt/zookeeper-*/bin/zkServer.sh status" 2>&1|grep Mode)
    # High node counts indicate a resource issue or a cleanup failure.
    zoo_node_count=$(kubectl exec $zoo -n $zoo_ns -- sh -c "echo srvr | nc localhost 2181" |grep Node.count: |awk '{ print $3; }')
    if [ $zoo_node_count -lt $zoo_node_max ];then
        good $zoo node count is $zoo_node_count
    else
        warn $zoo node count is $zoo_node_count
        kubectl exec $zoo -n $zoo_ns --  sh -c "echo srvr | nc localhost 2181"
    fi
    # High latency indicate a resource issue
    zoo_latency=$(kubectl exec $zoo -n $zoo_ns -- sh -c "echo srvr | nc localhost 2181" |grep Latency |tr "/" " " |awk '{ print $6; }')
    if [ $zoo_latency -lt $zoo_latency_max ];then
        good $zoo node latency is $zoo_latency
    else
        warn $zoo node latency is $zoo_latency
        #kubectl exec $zoo -n $zoo_ns -- sh -c "echo srvr | nc localhost 2181"
    fi
    if [[  $curr_zoo =~ "leader" ]];then
        echo "$zoo is zookeeper leader"
        zoo_leader="$zoo_leader $zoo"
    else
        if [[  $curr_zoo =~ "follower" ]];then
            echo "$zoo is zookeeper follower"
        else
            if [[  $curr_zoo =~ "standalone" ]];then
                warn "$zoo is zookeeper standalone!"
                zoo_leader="$zoo_leader $zoo"
            else
                error "$zoo appears to have failed!! (not follower/leader/standalone)"
                kubectl -n $zoo_ns get pod $zoo --no-headers -o wide
                zoo_error=1
            fi
        fi

    fi
    zoo_num=$((zoo_num + 1));
    zoo_df=$(kubectl -n $zoo_ns exec $zoo -- df /var/lib/zookeeper | awk '{ print $5; }' |tail -1|sed s/%//)
    [[ $zoo_df -gt $df_free ]] && error "Found zookeeper volume at ${zoo_df}% usage on $zoo!!"
done

# Many kafkas are connected?
# Crude parse, but it will do for now.
zkCli=$(kubectl exec $zoo -n $zoo_ns -- sh -c "ls /opt/zoo*/bin/zkCli.sh|head -1")
connected_kaf=$(kubectl exec $zoo -n $zoo_ns -- sh -c "echo ls /brokers/ids | $zkCli")
con_kaf_num=0
# What was I thinking here? Sure there is a more readable shell aproved means to do this.
# shellcheck disable=SC2076
if [[ $connected_kaf =~ '[0, 1, 2]' ]];then
    con_kaf_num=3
fi
# shellcheck disable=SC2076
if [[ $connected_kaf =~ '[0, 1]' ]];then
    con_kaf_num=2
fi
# shellcheck disable=SC2076
if [[ $connected_kaf =~ '[0]' ]];then
    con_kaf_num=1
fi

if [[ $zoo_num -gt 3 ]];then
    error "Found $zoo_num Zookeeper Pods $zoos!!"
    zoo_error=1
fi
if [[ $zoo_num -eq 0 ]];then
    error "Found Zero Zookeeper Pods !!"
    zoo_error=1
else
    [[ $zoo_num -eq 1 ]] && warn "Found One Zookeeper Pod." && zoo_error=1
fi
if [ -z $zoo_leader ];then
    error "No Zookeeper Leader found!!"
    zoo_error=1
fi
if [[ $(echo $zoo_leader|wc -w) -gt 1 ]];then
    warn "Found Zookeeper Leaders $zoo_leader!"
    zoo_error=1
fi
[ $zoo_error -eq 0 ] && good "Zookeeper passed tests"

if [[ $con_kaf_num -eq 3 ]];then
    good "Found 3 connected Kafkas"
else
    if [[ $con_kaf_num -gt 0 ]];then
        warn "Found $con_kaf_num connected Kafkas!"
    else
        warn "Found no connected Kafkas!"
    fi
fi
}

# testing kafka pods
kafka_test(){
echo "Testing Kafka pods"
kafka_ns=$(kubectl get pod --all-namespaces -l nirmata.io/service.name=kafka --no-headers | awk '{print $1}'|head -1)
kafkas=$(kubectl get pod -n $kafka_ns -l nirmata.io/service.name=kafka --no-headers | awk '{print $1}')
kaf_num=0
for kafka in $kafkas; do
        # Check if the Kafka pod is ready
        pod_status=$(kubectl get pod "$kafka" -n "$kafka_ns" -o jsonpath='{.status.phase}')
        pod_ready=$(kubectl get pod "$kafka" -n "$kafka_ns" -o jsonpath='{.status.containerStatuses[0].ready}')
        ready_count=$(kubectl get pod "$kafka" -n "$kafka_ns" -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' | grep -o 'true' | wc -l)
        total_count=$(kubectl get pod "$kafka" -n "$kafka_ns" -o jsonpath='{range .status.containerStatuses[*]}{.ready}{"\n"}{end}' | wc -l)

        if [[ "$pod_status" != "Running" ]]; then
            error "$kafka is not ready (Status: $pod_status)"
            kaf_error=1
            continue
        fi

        if [[ "$pod_ready" == "true" ]]; then
            good "$kafka is ready (Status: $pod_status, Ready: $ready_count/$total_count)"
        else
            error "$kafka is not ready (Status: $pod_status, Ready: $ready_count/$total_count)"
            kaf_error=1
        fi
    echo "Found Kafka Pod $kafka"
    kafka_df=$(kubectl -n $kafka_ns exec $kafka -- df /var/lib/kafka | awk '{ print $5; }' |tail -1|sed s/%//)
    [[ $kafka_df -gt $df_free ]] && error "Found Kafka volume at ${kafka_df}% usage on $kafka"
    kaf_num=$((kaf_num + 1));
done
[[ $kaf_num -gt 3 ]] && error "Found $kaf_num Kafka Pods $kafkas!!!" && kaf_error=1
if [[ $kaf_num -eq 0 ]];then
    error "Found Zero Kafka Pods!!!"
    kaf_error=1
else
    [[ $kaf_num -lt 3 ]] && warn "Found $kaf_num Kafka Pod!"
    kaf_error=1
fi
[[ $kaf_error -eq 0 ]] && good "Kafka passed tests"
# Is there more to test is it enough that the zookeeper test verifies the number of connection?
}

check_deployments() {
  echo "Checking Deployments in Namespace: $namespace"
  deployments=$(kubectl get deployments -n "$namespace" -o jsonpath='{.items[*].metadata.name}' | tr " " "\n")
  error_count=0

  for deployment in $deployments; do
    echo "Checking $deployment deployment"
    replica_count=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.spec.replicas}')
    ready_count=$(kubectl get deployment "$deployment" -n "$namespace" -o jsonpath='{.status.readyReplicas}')

    if [[ -z "$ready_count" ]]; then
      error "Deployment $deployment is not ready (Ready: 0/$replica_count)"
      error_count=$((error_count + 1))
    elif [[ $ready_count -ne $replica_count ]]; then
      error "Deployment $deployment is not fully available (Ready: $ready_count/$replica_count)"
      error_count=$((error_count + 1))
    else
      good "Deployment $deployment is available (Ready: $ready_count/$replica_count)"
    fi
  done

  if [[ $error_count -eq 0 ]]; then
    good "All deployments passed tests"
  else
    error "Some deployments failed tests"
  fi
}


#function to email results
do_email(){
if [[ $email -eq 0 ]];then
    # Check for certs in the cronjob's container as sendEmail won't use a server that doesn't auth.
    # This won't work for any that isn't debianish.
    if [ -e /certs/ ];then
        cp -f /certs/*.crt /usr/local/share/ca-certificates/
        update-ca-certificates
    fi
    [ -z $logfile ] && logfile="/tmp/k8_test.$$"
    [ -z $EMAIL_USER ] && EMAIL_USER="" #would this ever work?
    [ -z $EMAIL_PASSWD ] && EMAIL_PASSWD="" #would this ever work?
    [ -z "$TO" ] && error "No TO address given!!!" && exit 1 # Why did I comment this out?
    [ -z "$SUBJECT" ] && SUBJECT="K8 test script error" && echo -e "\e[33mYou provided no Subject using $SUBJECT \e[0m"
    # This needs to be redone with less nesting and more sanity.
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
            if [[ $localmail -eq 0 ]];then
              echo Using local mail client
              echo "$BODY" |mail -s \""$SUBJECT"\" "$email_to"
            else
              [ -z $FROM ] && FROM="k8@nirmata.com" && warn "You provided no From address using $FROM"
              [ -z $SMTP_SERVER ] && error "No smtp server given!!!" && exit 1
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
            fi
        done
    fi
fi
}

# This tests the sanity of your k8 cluster
cluster_test(){
    command -v kubectl &>/dev/null || error 'No kubectl found in path!!!'
    echo "Starting Cluster Tests"
    # Setup a DaemonSet to run tests on all nodes.
    echo 'apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: nirmata-net-test-all
  labels:
    app.kubernetes.io/name: nirmata-net-test-all-app
spec:
  selector:
    matchLabels:
        app.kubernetes.io/name: nirmata-net-test-all-app
  template:
    metadata:
      labels:
        app.kubernetes.io/name: nirmata-net-test-all-app
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
    echo -n 'Waiting for nirmata-net-test-all pods to start'
    until [[ $(kubectl get pods -l app.kubernetes.io/name=nirmata-net-test-all-app --no-headers --all-namespaces|awk '{print $4}' |grep -c Running) -ge $required_pods ]]|| \
      [[ $times = 60 ]];do
        sleep 1;
        echo -n .;
        times=$((times + 1));
    done
    echo

    # Do we have at least as many pods as nodes? (Do we care enough to do a compare node to pod?)
    if [[ $(kubectl -n $namespace get pods -l app.kubernetes.io/name=nirmata-net-test-all-app --no-headers |awk '{print $3}' |grep -c Running) -ne \
      $(kubectl get node --no-headers | awk '{print $2}' |grep -c Ready) ]] ;then
        error 'Failed to start nirmata-net-test-all on all nodes!!'
        echo Debugging:
        kubectl get pods -l app.kubernetes.io/name=nirmata-net-test-all-app -o wide
        kubectl get node
    fi

    dns_error=0
    for ns in $namespaces;do
        echo Testing $ns namespace
    for pod in $(kubectl -n $ns get pods -l app.kubernetes.io/name=nirmata-net-test-all-app --no-headers |grep Running |awk '{print $1}');do
        node=$(kubectl get pod $pod -o=custom-columns=NODE:.spec.nodeName -n $ns --no-headers)
        echo "Testing DNS on Node $node in Namespace $ns"
        if  kubectl exec $pod -- nslookup $DNSTARGET 2>&1|grep -e can.t.resolve -e does.not.resolve -e can.t.find -e No.answer;then
            warn "Can not resolve external DNS name $DNSTARGET in $ns."
            kubectl -n $ns get pod $pod -o wide
            kubectl -n $ns exec $pod -- sh -c "nslookup $DNSTARGET"
            echo
        else
            good "DNS test $DNSTARGET on $node in $ns suceeded."
        fi
        #kubectl -n $ns exec $pod -- nslookup $SERVICETARGET
        if kubectl -n $ns exec $pod -- nslookup $SERVICETARGET 2>&1|grep -e can.t.resolve -e does.not.resolve -e can.t.find -e No.answer;then
            warn "Can not resolve $SERVICETARGET service on $node in $ns"
            echo 'Debugging info:'
            kubectl get pod $pod -o wide
            dns_error=1
            kubectl -n $ns exec $pod -- nslookup $DNSTARGET
            kubectl -n $ns exec $pod -- nslookup $SERVICETARGET
            kubectl -n $ns exec $pod -- cat /etc/resolv.conf
            error "DNS test failed to find $SERVICETARGET service on $node in $ns"
        else
            good "DNS test $SERVICETARGET on $node in $ns suceeded."
        fi
        if [[ $curl -eq 0 ]];then
             if [[ $http -eq 0 ]];then
                 if  kubectl -n $ns exec $pod -- sh -c "if curl --max-time 5 http://$SERVICETARGET; then exit 0; else exit 1; fi" 2>&1|grep -e 'command terminated with exit code 1';then
                     error "http://$SERVICETARGET failed to respond to curl in 5 seconds!"
                 else
                     good "HTTP test $SERVICETARGET on $node in $ns suceeded."
                 fi
             else
                 if  kubectl -n $ns exec $pod -- sh -c "if curl --max-time 5 -k https://$SERVICETARGET; then exit 0; else exit 1; fi" 2>&1|grep -e 'command terminated with exit code 1';then
                     error "https://$SERVICETARGET failed to respond to curl in 5 seconds!"
                 else
                     good "HTTPS test $SERVICETARGET on $node in $ns suceeded."
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
    echo Testing space availble on docker partition.
    for pod in $(kubectl -n $ns get pods -l app.kubernetes.io/name=nirmata-net-test-all-app --no-headers |grep Running |awk '{print $1}');do
      root_df=$(kubectl -n $ns exec $pod -- df / | awk '{ print $5; }' |tail -1|sed s/%//)
      node=$(kubectl get pod $pod -o=custom-columns=NODE:.spec.nodeName -n $ns --no-headers)
      if [[ $root_df -gt $df_free_root ]];then
        error "Found docker partition at ${root_df}% usage on $node"
      else
        good "Found docker partition at ${root_df}% usage on $node"
      fi
    done
    namespaces="$(kubectl get ns  --no-headers | awk '{print $1}')"
    for ns in $namespaces;do
      kubectl --namespace=$ns delete ds nirmata-net-test-all --ignore-not-found=true &>/dev/null
    done



}

# test if your local system can run k8
local_test(){
echo "Starting Local Tests"

# Kubelet generally won't run if swap is enabled.
if [[ $(swapon -s | wc -l) -gt 1 ]] ;  then
    if [[ $fix_issues -eq 0 ]];then
        warn "Found swap enabled"
        echo_cmd swapoff -a
        echo_cmd sed -i '/[[:space:]]*swap[[:space:]]*swap/d' /etc/fstab
    else
        error "Found swap enabled!"
        echo Consider if you are having issues:
        echo "sed -i '/[[:space:]]*swap[[:space:]]*swap/d' /etc/fstab"
        echo "swapoff -a"
    fi
  else
    good No swap found
fi

# It's possible to run docker with selinux, but we don't support that.
if type sestatus &>/dev/null;then
    if sestatus | grep "Current mode:" |grep -e enforcing ;then
        warn 'SELinux enabled'
        sestatus
        if [[ $fix_issues -eq 0 ]];then
            echo "Applying the following fixes"
            echo_cmd sed -i s/^SELINUX=.*/SELINUX=permissive/ /etc/selinux/config
            echo_cmd setenforce 0
        else
            echo Consider the following changes to disabled SELinux if you are having issues:
            echo '  sed -i s/^SELINUX=.*/SELINUX=permissive/ /etc/selinux/config'
            echo '  setenforce 0'
        fi
    else
      good Selinux not enforcing
    fi
else
    #Assuming debian/ubuntu don't do selinux if no sestatus binary
    if [ -e /etc/os-release ]  &&  ! grep -q -i -e debian -e ubuntu /etc/os-release;then
        warn 'sestatus binary not found assuming SELinux is disabled.'
    else
      good "No Selinux found"
    fi
fi

#test kernel ip forward settings
if grep -q 0 /proc/sys/net/ipv4/ip_forward;then
        if [[ $fix_issues -eq 0 ]];then
            warn net.ipv4.ip_forward is set to 0
            echo "Applying the following fixes"
            echo_cmd sysctl -w net.ipv4.ip_forward=1
            echo_cmd echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf
        else
            error net.ipv4.ip_forward is set to 0
            echo Consider the following changes:
            echo '  sysctl -w net.ipv4.ip_forward=1'
            echo '  echo net.ipv4.ip_forward=1 >> /etc/sysctl.conf'
        fi
else
    good ip_forward enabled
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
        warn "Bridge netfilter disabled!!"
        echo "Applying the following fixes"
        echo_cmd sysctl -w net.bridge.bridge-nf-call-iptables=1
        echo_cmd echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf
    else
        error "Bridge netfilter disabled!!"
        echo Consider the following changes:
        echo '  sysctl -w net.bridge.bridge-nf-call-iptables=1'
        echo '  echo net.bridge.bridge-nf-call-iptables=1 >> /etc/sysctl.conf'
    fi
else
    good bridge-nf-call-iptables enabled
fi

#Test if firewalld is disabled
if  systemctl is-active firewalld &>/dev/null ; then
    warn 'firewalld service is active! This may prevent Kubernetes cluster from operating properly.'
    if [[ $fix_issues -eq 0 ]];then
      echo_cmd sudo systemctl stop firewalld
    fi
  else
    good firewalld is disabled
  fi

#Test if systemd-resolved is running
if  ! systemctl is-active systemd-resolved &>/dev/null ; then
    warn 'systemd-resolved service is not active! Either run "systemctl start systemd-resolved" or install the package and then run it.'
    if [[ $fix_issues -eq 0 ]];then
      echo_cmd sudo systemctl start systemd-resolved
    fi
  else
    good systemd-resolved is enabled
  fi


#TODO check for proxy settings, how, what, why
# Do we really need this has anyone complained?

#test for docker
if ! systemctl is-active docker &>/dev/null ; then
    warn 'Docker service is not active? Maybe you are using some other CRI??'
    if [[ $fix_issues -eq 0 ]];then
      echo_cmd sudo systemctl start docker
    fi
  else
    good Docker is running
fi

if ! systemctl is-enabled docker &>/dev/null;then
    warn 'Docker service is not starting at boot. Maybe you are using some other CRI??'
    if [[ $fix_issues -eq 0 ]];then
      echo_cmd sudo systemctl enable docker
    fi
  else
    good Docker is starting at boot
fi

if docker info 2>/dev/null|grep mountpoint;then
  warn 'Docker does not have its own mountpoint'
  # What is the fix for this??? How does this happen I've never seen it.
fi

# Is the version of docker locked/held if not we are going to suffer death by upgrade.
if [ ! -e /usr/bin/docker ];then
  error no /usr/bin/docker
fi
if [ -e /usr/bin/dpkg ];then
  dockerpkg=$(dpkg -S /usr/bin/docker |awk '{print $1}' |sed 's/:$//')
  if [[ $dockerpkg =~ docker.io ]];then
    if  sudo apt-mark showhold |grep -q docker.io; then
      good docker.io package held
    else
       warn docker.io package is not held
       if [[ $fix_issues -eq 0 ]];then
         echo_cmd sudo apt-mark hold docker.io
       fi
    fi
  else
    if [[ $dockerpkg =~ docker-ce ]];then
      if  sudo apt-mark showhold |grep -q docker-ce; then
        good docker-ce package held
      else
        warn docker-ce package is not held
        if [[ $fix_issues -eq 0 ]];then
          echo_cmd sudo apt-mark hold docker-ce
        fi
      fi
    fi
  fi
else
  if [ -e /usr/bin/rpm ];then
    if yum versionlock list |grep -q docker-ce;then
      good docker versionlocked
    else
      warn docker is not versionlocked
      if [[ $fix_issues -eq 0 ]];then
        echo_cmd sudo yum versionlock docker-ce
      fi
    fi
  fi
fi

#Customers often have time issues, which can cause cert issues.  Ex:cert is in future.
if type chronyc &>/dev/null;then
  if chronyc activity |grep -q "^0 sources online";then
    warn "Chrony found, but no ntp sources reported!"
  else
    good Found Chrony with valid ntp sources.
  fi
else
  if type ntpq &>/dev/null;then
    if ntpq -c rv |grep -q 'leap=00,'; then
      good Found ntp and we appear to be syncing.
    else
      warn "Found ntp client, but it appears to not be synced"
    fi
  else
    warn "No ntp client found!!"
  fi
fi

# Are we running the agent or kubelet?
if [ -e /etc/systemd/system/nirmata-agent.service ];then
    echo Found nirmata-agent.service testing Nirmata agent
    test_agent
else
    if type kubelet &>/dev/null;then
        #test for k8 service
        echo Found kubelet binary running local kubernetes tests
        echo -e "\e[33mNote if you plan on running the Nirmata agent remove this kubelet!!! \nIf this kubelet is running it will prevent Nirmata's kubelet from running. \e[0m"
        if ! systemctl is-active kubelet &>/dev/null;then
            error 'Kubelet is not active?'
        else
            good Kublet is active
        fi
        if ! systemctl is-enabled kubelet &>/dev/null;then
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
    else
        error No Kubelet or Nirmata Agent!!!
    fi
    if [ ! -e /opt/cni/bin/bridge ];then
        warn '/opt/cni/bin/bridge not found is your CNI installed?'
    fi
fi


}

# Test nirmata agent for nirmata built clusters
test_agent(){
echo Test Nirmata Agent
if systemctl is-active nirmata-agent &>/dev/null ; then
    good Nirmata Agent is running
else
    error Nirmata Agent is not running
fi
if systemctl is-enabled nirmata-agent &>/dev/null ; then
    good Nirmata Agent is enabled at boot
else
    error Nirmata Agent is not enabled at boot
fi
if docker ps |grep -q -e nirmata-agent -e nirmata/nirmata-host-agent;then
    good Found nirmata-host-agent
else
    error nirmata-host-agent is not running!
fi
if docker ps |grep -q -e "hyperkube proxy";then
    good Found hyperkube proxy
  else
    if docker ps |grep -q -e "kube-proxy";then
      good Found kube proxy
    else
      error Hyperkube proxy is not running!
    fi
fi
if docker ps --no-trunc|grep -q -e 'hyperkube kubelet' ;then
    good Found hyperkube kubelet
else
    error Hyperkube kubelet is not running!
fi
if docker ps --no-trunc|grep -q -e /opt/bin/flanneld ;then
    good Found flanneld
  else
    if docker ps --no-trunc|grep -q -e /usr/local/bin/kube-router; then
      good Found kube-router

    else
      error Flanneld or Kube Router are not running! Are you using a different CNI?
    fi
fi
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

# test kubernetes cluster
if [[ $run_remote -eq 0 ]];then
    kubectl get namespace $namespace >/dev/null || error "Can not find namespace $namespace tests may fail!!!"
    cluster_test
fi

# This tests nirmata's mongodb
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

# This tests nirmata deployment
if [[ $run_deploy -eq 0 ]];then
    kubectl get namespace $namespace >/dev/null || error "Can not find namespace $namespace tests may fail!!!"
    check_deployments
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
