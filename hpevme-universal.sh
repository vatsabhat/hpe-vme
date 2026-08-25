====================================================================================================
      HPE VM ESSENTIALS (VME) UNIVERSAL PLATFORM, STORAGE & LIFECYCLE MANAGEMENT CHEATSHEET
====================================================================================================

CATEGORY               | COMMAND                                         | OPERATIONAL DESCRIPTION
-----------------------+-------------------------------------------------+-------------------------------------------------
Maintenance Mode       | pcs node standby <NODE_NAME>                    | Evacuates VM computing loads and enters standby.
Maintenance Mode       | pcs node unstandby <NODE_NAME>                  | Exits standby mode and returns node to service.
-----------------------+-------------------------------------------------+-------------------------------------------------
Cluster Split & Status | pcs status                                      | Shows cluster, node, and resource health.
Cluster Split & Status | pcs quorum status                               | Displays quorum state and voting membership.
Cluster Split & Status | pcs resource refresh                            | Probes and updates the status of resources.
Cluster Split & Status | pcs resource cleanup                            | Clears resource error history and locks.
Cluster Split & Status | pcs fence <NODE_NAME>                           | Manually triggers fencing for an isolated node.
-----------------------+-------------------------------------------------+-------------------------------------------------
iSCSI Storage          | iscsiadm -m discovery -t st -p <TARGET_IP>      | Discovers targets on a specific storage portal.
iSCSI Storage          | iscsiadm -m node -T <IQN_NAME> -l               | Manually logs into a discovered iSCSI target.
iSCSI Storage          | iscsiadm -m session -P 1                        | Displays active iSCSI sessions and link states.
iSCSI Storage          | cat /etc/iscsi/initiatorname.iscsi              | Views local Node IQN address for array masking.
-----------------------+-------------------------------------------------+-------------------------------------------------
iSCSI Network Errors   | ip route get <STORAGE_TARGET_IP>                | Verifies which network interface handles iSCSI.
iSCSI Network Errors   | nc -zv <STORAGE_TARGET_IP> 3260                 | Tests if port 3260 is blocked, open, or refused.
iSCSI Network Errors   | sudo ovs-ofctl show <STORAGE_BRIDGE_NAME>       | Audits internal vSwitch carrier health for drops.
-----------------------+-------------------------------------------------+-------------------------------------------------
Multipath (MPIO)       | multipath -ll                                   | Shows status of redundant multipath block paths.
Multipath (MPIO)       | multipath -v2                                   | Re-scans and auto-configures active storage paths.
-----------------------+-------------------------------------------------+-------------------------------------------------
Network Routing        | ip route show                                   | Displays active network routing and gateways.
Network Routing        | traceroute -T -p 3260 <TARGET_IP>               | Traces network path using exact iSCSI TCP port.
-----------------------+-------------------------------------------------+-------------------------------------------------
Network Sync & OVS     | corosync-cmapctl \| grep runtime.totem          | Checks low-level Corosync network performance.
Network Sync & OVS     | sudo ovs-vsctl show                             | Displays Open vSwitch network and bridge paths.
Network Sync & OVS     | sudo netplan get                                | Views active storage and management net maps.
-----------------------+-------------------------------------------------+-------------------------------------------------
Time Synchronization   | timedatectl status                              | Verifies active NTP and clock synchronization.
Time Synchronization   | sudo systemctl restart systemd-timesyncd       | Forces a local host time resynchronization.
-----------------------+-------------------------------------------------+-------------------------------------------------
Hypervisor & VMs       | sudo virsh list --all                           | Lists all local virtual machine instances.
Hypervisor & VMs       | sudo virsh start <VM_NAME>                      | Manually powers on a target virtual machine.
Hypervisor & VMs       | sudo virsh shutdown <VM_NAME>                   | Sends a graceful power-down request to a VM.
Hypervisor & VMs       | sudo virsh destroy <VM_NAME>                    | Forcefully terminates a non-responsive VM.
-----------------------+-------------------------------------------------+-------------------------------------------------
VME Platform Utilities | hpe-vm                                          | Launches the interactive text-based console.
VME Platform Utilities | /opt/hpe-vm/scripts/reset_host.sh              | Wipes a corrupted node setup to start clean.
-----------------------+-------------------------------------------------+-------------------------------------------------
Corosync Logging       | journalctl -u corosync -f                       | Follows live Corosync heartbeat events.
Corosync Logging       | journalctl -u corosync \| grep -i "token"       | Searches for token loss and heartbeat timeouts.
Corosync Logging       | journalctl -u corosync \| grep -i "retransmit"  | Finds packet drops and network retry requests.
Corosync Logging       | journalctl -u corosync -b 0 -p err              | Filters critical errors for current boot cycle.
-----------------------+-------------------------------------------------+-------------------------------------------------
OS Network & Latency   | sudo dmesg -T \| grep -E -i "eth\|bond\|switch" | Checks OS kernel for physical link drops/flaps.
OS Network & Latency   | ping -s 1472 -M do -c 100 <PEER_NODE_IP>        | Tests MTU size latency and network packet loss.
-----------------------+-------------------------------------------------+-------------------------------------------------
Manager Backup/Restore | sudo morpheus-db-dump -d /tmp/                  | Dumps operational state tracking database to file.
Manager Backup/Restore | sudo morpheus-db-restore -f <FILE_PATH>         | Imports saved relational data to active engine.
Manager Backup/Restore | sudo morpheus-ctl reconfigure                   | Re-aligns internal configurations and mappings.
-----------------------+-------------------------------------------------+-------------------------------------------------
Manager Maintenance    | sudo morpheus-ctl stop morpheus-ui              | Halts manager browser and UI service plane.
Manager Maintenance    | sudo morpheus-ctl stop mysql                    | Halts relational backend database daemon smoothly.
Manager Maintenance    | sudo morpheus-ctl tail morpheus-ui              | Follows console UI launch logs in real time.
-----------------------+-------------------------------------------------+-------------------------------------------------
Manager Upgrades       | sudo dpkg -i <BASE_VME_FILE>.deb                | Installs downloaded base engine update package.
Manager Upgrades       | sudo dpkg -i <SUPPLEMENTAL_FILE>.deb            | Applies air-gapped system update dependencies.
-----------------------+-------------------------------------------------+-------------------------------------------------
Host OS Updates        | sudo apt update && sudo apt upgrade             | Refreshes system baseline packages on local host.
====================================================================================================
