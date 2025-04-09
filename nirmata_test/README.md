This is the Nirmata test script.  It will check either your nirmata install, local system for Kubernetes compatiblity, or perform a basic health check of your kubernetes cluster.  

The get_logs script will grab logs from the nirmata namespace.  See -h for Flags.

See README.kubejobs for making it a K8 cronjob.

The nirmata test script has 3 basic modes: (Yes they should be different scripts, but it's nice to have single script to download for customers in "air gapped" sites.)

Test Nirmata application (default)  
./nirmata_test.sh --nirmata

Test local node for Nirmata Agent compatiblity:  
./nirmata_test.sh --local

Cluster testing (requires working kubectl config):  
./nirmata_test.sh --cluster  

There are also a host of other features such as email support, and ssh support.  See --help for more info.

Examples:  
Run local tests on remote host.  
./nirmata_test.sh --local --ssh "user@host.name user2@host2.name2"  

Email on error (Note using gmail requires an app password)  
./nirmata_test.sh --cluster --email --to testy@nirmata.com --smtp smtp.gmail.com:587  --user sam.silbory --passwd 'foo!foo'   


Return codes are as follows:  
0 Good  
1 Error  
2 Warning  

Example output on kubernetes node:
```
root@silbory-nirmata0:~# ~nirmata/nirmata_test.sh --local
./nirmata_test.sh version 2.0.0
Starting Local Tests
Checking Docker proxy configuration...
Warn: Missing proxy configurations in /usr/lib/systemd/system/docker.service: HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy
Checking containerd proxy configuration...
Warn: Missing proxy configurations in /usr/lib/systemd/system/containerd.service: HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy
Checking node level proxy settings...
Warn: Missing proxy configurations in /etc/profile.d/proxy.sh: HTTP_PROXY HTTPS_PROXY NO_PROXY http_proxy https_proxy no_proxy
Proxy configuration check completed.
GOOD: No swap found
GOOD: Selinux not enforcing
GOOD: ip_forward enabled
GOOD: bridge-nf-call-iptables module loaded
GOOD: bridge-nf-call-iptables enabled
GOOD: Port 2379/tcp is enabled in iptables.
GOOD: Port 2380/tcp is enabled in iptables.
GOOD: Port 6443/tcp is enabled in iptables.
GOOD: Port 8090/tcp is enabled in iptables.
GOOD: Port 8091/tcp is enabled in iptables.
GOOD: Port 8472/udp is enabled in iptables.
GOOD: Port 10250/tcp is enabled in iptables.
GOOD: Port 10251/tcp is enabled in iptables.
GOOD: Port 10252/tcp is enabled in iptables.
GOOD: Port 10255/tcp is enabled in iptables.
GOOD: Port 10256/tcp is enabled in iptables.
GOOD: Port 10257/tcp is enabled in iptables.
GOOD: Port 10259/tcp is enabled in iptables.
GOOD: Port 179/tcp is enabled in iptables.
GOOD: Port 9099/tcp is enabled in iptables.
GOOD: Port 4789/udp is enabled in iptables.
GOOD: Port 53/udp is enabled in iptables.
GOOD: Port 443/tcp is enabled in iptables.
GOOD: Port 30000:32768/tcp is enabled in iptables.
GOOD: Port 67/udp is enabled in iptables.
GOOD: Port 68/udp is enabled in iptables.
GOOD: Protocol 4 is enabled in iptables.
GOOD: Docker is running
GOOD: Docker is starting at boot
Warn: docker is not versionlocked
GOOD: Containerd is active
Checking for Kubernetes-related processes...
Warn: Process 'kube-proxy' is running. Verify it by running 'ps -ef | grep kube-proxy' and remove it using 'kill -9 kube-proxy'.
Warn: Process 'kube-apiserver' is running. Verify it by running 'ps -ef | grep kube-apiserver' and remove it using 'kill -9 kube-apiserver'.
Warn: Process 'kubelet' is running. Verify it by running 'ps -ef | grep kubelet' and remove it using 'kill -9 kubelet'.
Warn: Process 'kube-scheduler' is running. Verify it by running 'ps -ef | grep kube-scheduler' and remove it using 'kill -9 kube-scheduler'.
Warn: Process 'kube-controller-manager' is running. Verify it by running 'ps -ef | grep kube-controller-manager' and remove it using 'kill -9 kube-controller-manager'.
Warn: Process 'etcd' is running. Verify it by running 'ps -ef | grep etcd' and remove it using 'kill -9 etcd'.
Process check completed.
GOOD: systemd-resolved is active
GOOD: firewalld is inactive
GOOD: Found Chrony with valid ntp sources.
Found nirmata-agent.service testing Nirmata agent
Test Nirmata Agent
GOOD: Nirmata Agent is running
GOOD: Nirmata Agent is enabled at boot
GOOD: Found nirmata-host-agent
GOOD: /etc/containerd is correctly mounted.
GOOD: /var/lib/docker exists.
Warn: Test completed with warnings.
[root@master3 ~]# ./nirmata_test.sh --base-cluster-local
./nirmata_test.sh version 2.0.0
Warn: /apps/nirmata/zk is not mounted.
Warn: /apps/nirmata/kafka is not mounted.
Warn: /apps/nirmata/mongodb is not mounted.
Warn: /apps/nirmata is not found.
Warn: Test completed with warnings.


root@silbory-nirmata0:~# ~nirmata/nirmata_test.sh --cluster
Starting Cluster Tests

Found the following nodes:
silbory-nirmata0   Ready   master   29h   v1.13.3

Waiting for nirmata-net-test-all pods to start..
Testing default namespace
Testing silbory-nirmata0 Namespace default
DNS test nirmata.com on nirmata-net-test-all-tmjl4 suceeded.
DNS test kubernetes.default.svc.cluster.local on nirmata-net-test-all-tmjl4 suceeded.
Testing completed without errors or warning
root@silbory-nirmata0:~# 
```

Example on Nirmata installed cluster:
```
root@ubuntu:~#  /home/nirmata/nirmata_test.sh --local
Starting Local Tests
Checking for swap
Testing SELinux
ip_forward enabled
bridge-nf-call-iptables enabled
Docker is active
Containerd is active
Found nirmata-agent.service testing Nirmata agent
Test Nirmata Agent
Nirmata Agent is running
Nirmata Agent is enabled at boot
Found nirmata-host-agent
Testing completed without errors or warning
```

Example testing Nirmata services on non-HA cluster: (warnings are due to the non HA state)
```
root@silbory-nirmata0:~# ~nirmata/nirmata_test.sh --nirmata  ;echo return is $?
Testing MongoDB Pods
mongodb-0 is master
Found One Mongo Pod
Testing Zookeeper pods
zk-0 is zookeeper standalone
Found One Zookeeper Pod.
Testing Kafka pods
Found Kafka Pod kafka-0
Testing Kafka controller pods
kafka-0 API is healthy!
Found Kafka Controller Pod kafka-controller-0
kafka-controller-0 API is healthy!
Test completed with warnings.
return is 2
```
