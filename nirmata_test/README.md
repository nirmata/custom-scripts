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
Starting Local Tests
Checking for swap
Testing SELinux
ip_forward enabled
bridge-nf-call-iptables enabled
Docker is active
Found kubelet running local kubernetes tests
Kublet is active
Kublet is enabled at boot
Testing completed without errors or warning

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
Found Kafka Pod kafka-0   1/1   Running   2     3d17h
Found One Kafka Pod.
Test completed with warnings.
return is 2
```
