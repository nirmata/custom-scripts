## Kyverno Rule Name Lister
This script retrieves and lists all rule names defined within Kyverno cluster policies deployed on your Kubernetes cluster.

## Requirements
- kubectl: kubectl CLI: https://kubernetes.io/docs/reference/kubectl/
- jq: jq (JSON processor): https://stedolan.github.io/jq/
## Usage
1. Clone this repository or download the script directly.
2. Make the script executable: chmod +x list_kyverno_rules.sh
3. Run the script: ./list_kyverno_rules.sh

``` 
$ ./list_kyverno_rules.sh
require-drop-cap-net_raw
require-drop-cap-net_bind_service
require-drop-cap-setuid
require-drop-cap-setgid
require-drop-cap-sys_admin
require-drop-cap-net_admin
require-drop-cap-audit_control
require-drop-cap-audit_read
require-drop-cap-block_suspend
require-drop-cap-bpf
require-drop-cap-checkpoint_restore
require-drop-cap-dac_read_search
require-drop-cap-ipc_lock
require-drop-cap-ipc_owner
require-drop-cap-lease
require-drop-cap-linux_immutable
require-drop-cap-mac_admin
require-drop-cap-mac_override
require-drop-cap-net_broadcast
require-drop-cap-perfmon
require-drop-cap-sys_boot
require-drop-cap-sys_module
require-drop-cap-sys_nice
require-drop-cap-sys_pacct
require-drop-cap-sys_ptrace
require-drop-cap-sys_rawio
require-drop-cap-sys_resource
require-drop-cap-sys_time
require-drop-cap-sys_tty_config
require-drop-cap-syslog
require-drop-cap-wake_alarm
require-drop-cap-dac_override
require-drop-cap-fowner
disallow-host-hostpid-namespaces
disallow-host-ipc-namespaces
disallow-host-network-namespaces
host-path
disallow-host-ports
disallow-host-ports-range
disallow-privilege-escalation
disallow-privileged-containers
validate-readonly-root-filesystem
run-as-non-root-fs-group-id
run-as-non-root-supplemental-group-id
run-as-non-root-user-id
run-as-non-root
restricted-volumes
volumes-hostpath-readonly
```

The script will list all Kyverno rule names from your cluster policies
