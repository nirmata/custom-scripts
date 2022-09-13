#!/bin/bash 

namespace="nirmata"
pod=""
taillines="--tail 50000"
datastamp=$(date "+%Y%m%d-%H%M%S")
startdir=$(pwd)
if command -v xz &> /dev/null;then
    zip="xz"
    zip_ext=$zip
else
    zip="gzip"
    zip_ext="gz"
fi

helpfunction(){
    echo "script usage: $(basename "$0") [-n namespace] [-t number_of_log_lines] [ -p pod_name_regex ] [-a] [-x] [-l compression_level] " >&2
    echo "  -a  All lines (default is $taillines if no -a or -t)" >&2
    echo "  -x  Use xz compression" >&2
    echo "  -l  Use this compression level" >&2
}

while getopts 't:p:n:l:hax' OPTION; do
  case "$OPTION" in
    p)
      pod+=" $OPTARG "
      ;;
    n)
      namespace="$OPTARG"
      ;;
    t)
      taillines="--tail $OPTARG"
      ;;
    a)
      taillines=""
      ;;
    x)
      if command -v xz &> /dev/null;then
          zip="xz"
          zip_ext=$zip
      else
          echo "xz not found in PATH using gzip"
      fi
      ;;
    l)
      level="-$OPTARG"
      ;;
    h)
      helpfunction
      exit 0
      ;;
    ?)
      helpfunction
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

if [ -z "$pod" ];then 
    pod="."
fi

# xz -0 is better and faster than gzip default, and for text the standard level isn't much better and much slower.
if [[ $zip == "xz" ]];then
    if [ -z "$level" ];then
        level="-0"
    fi
fi

echo "namespace is $namespace"
echo "pod match string is $pod"

for p in $pod;do 
    running_pods+=$(kubectl get pods --no-headers -o custom-columns=":metadata.name" -n "$namespace"  |grep "$p")
    running_pods+=" "
done

if [ -z "$running_pods" ]; then
    echo "No pods found for $pod in  $namespace"
    exit 1
fi
echo -e "Found runing pods: \n$running_pods"
echo

# Make a temp log dir
rm -rf "/tmp/k8-logs-script-$namespace-$datastamp"
if [ -e /tmp/k8-logs-script-"$namespace-$datastamp" ];then echo "/tmp/k8-logs-script-$namespace-$datastamp exists bailing out"; exit 1; fi
mkdir "/tmp/k8-logs-script-$namespace-$datastamp"
cd /tmp/k8-logs-script-"$namespace"-"$datastamp" || exit 1

# Loop thru found pods and grab logs
for curr_pod in $running_pods; do
   # Compress as we create
   kubectl -n "$namespace" logs "$curr_pod" --all-containers=true $taillines | $zip $level > "${curr_pod}.log.$zip_ext"
   kubectl -n "$namespace" describe pods "$curr_pod"  2>&1 >>"${curr_pod}".describe
   # Less awk more formating with kubectl?
   (kubectl -n "$namespace" describe $(kubectl -n "$namespace" describe $(kubectl -n "$namespace" describe pod "$curr_pod" 2>/dev/null|grep Controlled.By: |awk '{print $3}')  |grep Controlled.By: |awk '{print $3}') --show-events 2>&1) >>"${curr_pod}".describe
done

# We these are small we can do compression aftwards
for described in $(ls *.describe);do
    $zip $level $described
done


cd "$startdir" || exit 1
# No compression as it's all compressed.
tar czf "k8-logs-script-$namespace-$datastamp.tar" -C /tmp "k8-logs-script-$namespace-$datastamp"
echo "Created k8-logs-script-$namespace-$datastamp.tar"

rm -rf "/tmp/k8-logs-script-$namespace-$datastamp"
