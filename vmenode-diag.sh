#!/bin/bash
# ==============================================================================
# HPE VM Essentials 9.0.0 - Node Diagnostic & Automated Troubleshooting Script
# ==============================================================================

# Ensure script runs as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] ERROR: This script must be run as root (sudo)."
  exit 1
fi

echo "=============================================================================="
echo "               HPE VME 9.0.0 DIAGNOSTIC REPORT: $(hostname)"
echo "=============================================================================="

# 1. CHECK HPE VME HOST AGENT
echo -n "[*] Checking VME Host Agent (morphd)... "
if systemctl is-active --quiet morphd; then
    AGENT_STATUS="ACTIVE"
    echo "OK"
else
    AGENT_STATUS="FAILED"
    echo "CRITICAL: Agent is stopped or failing!"
fi

# 2. CHECK LEGACY CONTROL PLANE (PACEMAKER)
echo -n "[*] Checking Legacy Control Plane (Pacemaker)... "
if systemctl is-active --quiet pacemaker; then
    PACEMAKER_STATUS="RUNNING"
    echo "RUNNING (Migration required for VME 9.0.0)"
else
    PACEMAKER_STATUS="INACTIVE"
    echo "INACTIVE (Expected behavior if fully migrated)"
fi

# 3. CHECK DISTRIBUTED LOCK MANAGER (DLM)
echo -n "[*] Checking DLM Kernel Module... "
if lsmod | grep -q dlm; then
    DLM_KMOD="LOADED"
    echo "LOADED"
else
    DLM_KMOD="MISSING"
    echo "MISSING"
fi

# 4. CHECK MULTIPATH & TUR PATH STATUS
echo -n "[*] Scanning for TUR Checker Path Down Errors... "
TUR_ERRORS=$(journalctl -u multipathd --since "24 hours ago" | grep -i "tur checker reports path is down" | tail -n 3)
MULTIPATH_DUPS=$(grep -E "multipath \{|wwid" /etc/multipath.conf | awk '{print $2}' | sort | uniq -d)

if [ -n "$TUR_ERRORS" ]; then
    PATH_STATUS="DEGRADED"
    echo "FAILED PATHS FOUND!"
else
    PATH_STATUS="HEALTHY"
    echo "OK"
fi

# ==============================================================================
#                      TABULAR ACTIONABLE INTIMATION REPORT
# ==============================================================================
echo ""
echo "=============================================================================="
echo "                           VME NODE STATUS SUMMARY                            "
echo "=============================================================================="
printf "%-25s | %-15s | %-30s\n" "COMPONENT" "STATUS" "RECOMMENDED ACTION"
printf "%-25s + %-15s + %-30s\n" "-------------------------" "---------------" "------------------------------"
printf "%-25s | %-15s | %-30s\n" "HVM Host Agent (morphd)" "$AGENT_STATUS" "$( [ "$AGENT_STATUS" = "ACTIVE" ] && echo "None" || echo "sudo systemctl restart morphd" )"
printf "%-25s | %-15s | %-30s\n" "Legacy Cluster (Pacemaker)" "$PACEMAKER_STATUS" "$( [ "$PACEMAKER_STATUS" = "RUNNING" ] && echo "Upgrade to VME Layout 1.3" || echo "None" )"
printf "%-25s | %-15s | %-30s\n" "DLM Core Engine" "$DLM_KMOD" "$( [ "$DLM_KMOD" = "LOADED" ] && echo "None" || echo "sudo modprobe dlm" )"
printf "%-25s | %-15s | %-30s\n" "SAN Storage Links" "$PATH_STATUS" "$( [ "$PATH_STATUS" = "DEGRADED" ] && echo "Check SAN Switch Fabric/Ports" || echo "None" )"
echo "=============================================================================="

# 5. PRINT SPECIFIC TROUBLESHOOTING INSTRUCTIONS
echo ""
echo "=============================================================================="
echo "                        TROUBLESHOOTING INSTRUCTIONS                          "
echo "=============================================================================="

if [ "$PACEMAKER_STATUS" = "RUNNING" ]; then
    echo "--> ISSUE: Legacy Cluster Control Plane Is Active"
    echo "    VME 9.0.0 uses HVM Cluster Layout 1.3, decoupling storage from Pacemaker."
    echo "    FIX: Navigate to VME Manager UI > Infrastructure > Clusters > Select Cluster."
    echo "         Click the 'Upgrade Layout' banner to migrate storage orchestration."
    echo ""
fi

if [ -n "$TUR_ERRORS" ]; then
    echo "--> ISSUE: Active Storage Multi-Path Drops Found"
    echo "    Recent TUR log snips:"
    echo "$TUR_ERRORS"
    echo "    FIX: Check Fibre Channel or iSCSI fabrics. Force a manual bus rescan via:"
    echo "         echo '- - -' | sudo tee /sys/class/scsi_host/host*/scan"
    echo "         sudo multipathr reload"
    echo ""
fi

if [ -n "$MULTIPATH_DUPS" ]; then
    echo "--> ISSUE: Duplicate Configurations Found in multipath.conf"
    echo "    FIX: Open /etc/multipath.conf and ensure each WWID and Alias block is unique."
    echo ""
fi

if [ "$DLM_KMOD" = "MISSING" ]; then
    echo "--> ISSUE: Kernel Lock Manager Not Loaded"
    echo "    FIX: Force-load the module: sudo modprobe dlm"
    echo "         Ensure persistency: echo 'dlm' | sudo tee -a /etc/modules-load.d/dlm.conf"
    echo ""
fi

echo "Diagnostic complete. Monitor live UI agent strings in /var/log/morpheus/morpheus-ui/current."
