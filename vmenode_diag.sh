#!/bin/bash
# ==============================================================================
# HPE VM Essentials (VME) Node Diagnostic Tool & Remediation Script
# ==============================================================================

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[31m[ERROR] Please run this diagnostic script with sudo or as root.\e[0m"
  exit 1
fi

echo "===================================================================="
echo " Starting HPE VME Node Diagnostic & Fix Wizard"
echo "===================================================================="

# 1. Check Morpheus Engine/VME Manager Services
echo -e "\n[*] Checking VME Manager / Morpheus Service Status..."
if command -v morpheus-ctl >/dev/null 2>&1; then
    SERVICE_STATUS=$(morpheus-ctl status 2>&1)
    echo "$SERVICE_STATUS"
    
    if echo "$SERVICE_STATUS" | grep -q "fail\|down"; then
        echo -e "\e[31m[FAIL] One or more Morpheus engine services are down or failing.\e[0m"
        echo -e "\e[32m[FIX] Attempting to restart the Morpheus service supervisor...\e[0m"
        systemctl restart morpheus-runsvdir
        sleep 5
        morpheus-ctl reconfigure
        morpheus-ctl restart
        echo -e "\e[32m[INFO] Service reconfigure commands pushed. Please wait 2-5 minutes for stack stabilization.\e[0m"
    else
        echo -e "\e[32m[PASS] VME Manager services are healthy.\e[0m"
    fi
else
    echo -e "\e[33m[WARN] 'morpheus-ctl' tool not found on this node. Skipping control-plane engine health.\e[0m"
fi

# 2. Check Network & Cluster Communication (Pacemaker / Corosync)
echo -e "\n[*] Checking Node High-Availability & Cluster State (Pacemaker)..."
if command -v pcs >/dev/null 2>&1; then
    PCS_STATUS=$(pcs status 2>&1)
    echo "$PCS_STATUS"
    
    if echo "$PCS_STATUS" | grep -q "Stopped\|Error\|Offline"; then
        FAILED_NODE=$(echo "$PCS_STATUS" | grep "Stopped" | awk '{print $2}' | tr -d ':')
        echo -e "\e[31m[FAIL] Cluster degradation detected. Nodes or resources are stopped.\e[0m"
        if [ ! -z "$FAILED_NODE" ]; then
            echo -e "\e[32m[FIX] Clearing maintenance flags and forcing node unstandby for: $FAILED_NODE\e[0m"
            pcs node unstandby "$FAILED_NODE"
        fi
    else
        echo -e "\e[32m[PASS] High-Availability cluster nodes are online and fully synced.\e[0m"
    fi
else
    echo -e "\e[33m[WARN] 'pcs' command not found. Node may not be part of a multi-node HA cluster setup.\e[0m"
fi

# 3. Check Local Network Resolution (DNS & Host Verification)
echo -e "\n[*] Validating Network & Host DNS Resolution mappings..."
CURRENT_HOSTNAME=$(hostname -f 2>/dev/null || hostname)
echo "Current Node Hostname: $CURRENT_HOSTNAME"

# Test name resolution
if command -v nslookup >/dev/null 2>&1; then
    DNS_RESOLVE=$(nslookup "$CURRENT_HOSTNAME" 2>&1)
    if echo "$DNS_RESOLVE" | grep -q "NXDOMAIN\|can't find"; then
        echo -e "\e[31m[FAIL] DNS Name resolution failed for '$CURRENT_HOSTNAME'.\e[0m"
        echo -e "\e[33m[WARN] VME clusters require consistent internal lookup mapping to function safely.\e[0m"
        
        # Fallback fix to Hostfile validation
        NODE_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7}' || hostname -I | awk '{print $1}')
        echo -e "\e[32m[FIX] Patching local /etc/hosts matrix to preserve node identity fallback..."
        if ! grep -q "$CURRENT_HOSTNAME" /etc/hosts; then
            echo "$NODE_IP $CURRENT_HOSTNAME" >> /etc/hosts
            echo "Added localized fallback pointer mapping: $NODE_IP -> $CURRENT_HOSTNAME"
        fi
    else
        echo -e "\e[32m[PASS] Local Hostname DNS mapping is fully operational.\e[0m"
    fi
else
    echo -e "\e[33m[WARN] 'nslookup' tool not found. Ensure DNS configurations are stable.\e[0m"
fi

# 4. Critical UI Port Accessibility Diagnostics
echo -e "\n[*] Testing Critical Infrastructure Listening Ports..."
for PORT in 22 443 5985; do
    if ss -tuln | grep -q ":$PORT "; then
        echo -e "\e[32m[PASS] Port $PORT is active and listening.\e[0m"
    else
        echo -e "\e[31m[FAIL] Required VME service Port $PORT is unreachable or down.\e[0m"
        if [ "$PORT" -eq 443 ]; then
            echo -e "\e[32m[FIX] Port 443 down implies UI issues. Tail log files for active errors: /var/log/morpheus/morpheus-ui/current\e[0m"
        fi
    fi
done

echo -e "\n===================================================================="
echo " Diagnostic Sweep Completed."
echo "===================================================================="
