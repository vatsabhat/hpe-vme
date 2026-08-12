cat << 'EOF' > /tmp/vme_cluster_audit.sh
#!/bin/bash
# HPE VM Essentials (VME) Pure POSIX-Compliant Infrastructure Audit Script
# Generates both tabular *.txt and *.html reports natively.

TXT_OUT="/tmp/vme_audit_report.txt"
HTML_OUT="/tmp/vme_audit_report.html"

# Initialize text file
echo "====================================================================================================" > $TXT_OUT
echo "                       HPE VM ESSENTIALS (VME) CLUSTER AUDIT REPORT                         " >> $TXT_OUT
echo "                       Generated on: $(date)" >> $TXT_OUT
echo "====================================================================================================" >> $TXT_OUT
printf "%-25s | %-45s | %-25s\n" "AUDIT CATEGORY" "DIAGNOSTIC TEST / COMMAND RUN" "HEALTH EXECUTION STATUS" >> $TXT_OUT
echo "--------------------------+-----------------------------------------------+-------------------------" >> $TXT_OUT

# Initialize HTML file
cat << 'HTMLHEAD' > $HTML_OUT
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <title>HPE VME Cluster Audit Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 30px; background-color: #f4f6f9; color: #333; }
        h1 { color: #01a982; border-bottom: 3px solid #01a982; padding-bottom: 10px; }
        .meta { font-style: italic; margin-bottom: 20px; color: #666; }
        table { width: 100%; border-collapse: collapse; margin-top: 10px; background: #fff; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
        th, td { border: 1px solid #ddd; padding: 12px; text-align: left; }
        th { background-color: #01a982; color: white; text-transform: uppercase; font-size: 14px; }
        tr:nth-child(even) { background-color: #f9f9f9; }
        .status-ok { color: #27ae60; font-weight: bold; }
        .status-warn { color: #e67e22; font-weight: bold; }
        pre { background: #222; color: #fff; padding: 10px; border-radius: 4px; overflow-x: auto; font-size: 12px; }
    </style>
</head>
<body>
    <h1>HPE VM Essentials (VME) Cluster Audit Report</h1>
    <div class="meta">Report Generation Timestamp: Run on $(date)</div>
    <table>
        <tr>
            <th>Audit Category</th>
            <th>Diagnostic Test / Command Run</th>
            <th>Health Execution Status</th>
        </tr>
HTMLHEAD

# Helper function to append results to both files (Fixed for strict POSIX compatibility)
log_audit_item() {
    local category="$1"
    local diagnostic="$2"
    local status="$3"
    
    # Append to TXT
    printf "%-25s | %-45s | %-25s\n" "$category" "$diagnostic" "$status" >> $TXT_OUT
    
    # Determine HTML style class using strict single bracket matching
    local st_class="status-ok"
    if [ "$status" != "COMPLETED" ] && [ "$status" != "SYNCHRONIZED" ] && [ "$status" != "ONLINE" ]; then
        st_class="status-warn"
    fi
    
    # Append to HTML
    echo "        <tr>" >> $HTML_OUT
    echo "            <td><b>$category</b></td>" >> $HTML_OUT
    echo "            <td><code>$diagnostic</code></td>" >> $HTML_OUT
    echo "            <td><span class=\"$st_class\">$status</span></td>" >> $HTML_OUT
    echo "        </tr>" >> $HTML_OUT
}

# --- Section 1: Clustering Status ---
if pcs status >/dev/null 2>&1; then log_audit_item "High Availability" "pcs status" "ONLINE"; else log_audit_item "High Availability" "pcs status" "OFFLINE/ERROR"; fi
if pcs quorum status >/dev/null 2>&1; then log_audit_item "High Availability" "pcs quorum status" "QUORUM_OK"; else log_audit_item "High Availability" "pcs quorum status" "NO_QUORUM"; fi

# --- Section 2: Storage Topology ---
if command -v ceph >/dev/null 2>&1 && ceph health >/dev/null 2>&1; then
    ceph_health=$(ceph health)
    log_audit_item "Storage (Converged)" "ceph status" "$ceph_health"
else
    log_audit_item "Storage (Converged)" "ceph status" "NOT_CONFIGURED"
fi
if iscsiadm -m session >/dev/null 2>&1; then log_audit_item "Storage (SAN)" "iscsiadm -m session" "SESSIONS_ACTIVE"; else log_audit_item "Storage (SAN)" "iscsiadm -m session" "NO_ISCSI_LINKS"; fi
if multipath -ll >/dev/null 2>&1; then log_audit_item "Storage (MPIO)" "multipath -ll" "MULTIPATH_ACTIVE"; else log_audit_item "Storage (MPIO)" "multipath -ll" "MPIO_NOT_FOUND"; fi

# --- Section 3: Networking Configuration ---
if sudo ovs-vsctl show >/dev/null 2>&1; then log_audit_item "Network & Bridges" "ovs-vsctl show" "OVS_OPERATIONAL"; else log_audit_item "Network & Bridges" "ovs-vsctl show" "OVS_FAILED"; fi
if corosync-cmapctl | grep -q "totem"; then log_audit_item "Network Sync" "corosync-cmapctl | grep totem" "TOTEM_LINK_OK"; else log_audit_item "Network Sync" "corosync-cmapctl | grep totem" "LINK_MISSMATCH"; fi

# --- Section 4: Time and Compute Baseline ---
if timedatectl status | grep -q "System clock synchronized: yes"; then log_audit_item "Time/NTP Sync" "timedatectl status" "SYNCHRONIZED"; else log_audit_item "Time/NTP Sync" "timedatectl status" "TIME_DRIFT_WARN"; fi
if sudo virsh list --all >/dev/null 2>&1; then log_audit_item "Hypervisor Base" "virsh list --all" "KVM_DAEMON_OK"; else log_audit_item "Hypervisor Base" "virsh list --all" "LIBVIRTD_CRASHED"; fi

# --- Section 5: VME Manager Database Infrastructure ---
if sudo morpheus-ctl status mysql | grep -q "run:"; then log_audit_item "Control Plane DB" "morpheus-ctl status mysql" "ONLINE"; else log_audit_item "Control Plane DB" "morpheus-ctl status mysql" "DB_OFFLINE_WARN"; fi
if sudo test -f /etc/morpheus/morpheus-secrets.json; then log_audit_item "Control Plane Crypt" "secrets.json file check" "ENCRYPTION_KEYS_OK"; else log_audit_item "Control Plane Crypt" "secrets.json file check" "KEYS_MISSING_ALERT"; fi

# Close out layout files
echo "====================================================================================================" >> $TXT_OUT
cat << 'HTMLFOOT' >> $HTML_OUT
    </table>
    <br>
    <h3>Detailed Raw Log Diagnostic Appendices</h3>
    <p>Review standard journal strings if components report warnings or offline states:</p>
    <pre>
# Review live packet losses or token failures:
journalctl -u corosync --no-pager -n 20
    </pre>
</body>
</html>
HTMLFOOT

chmod +x /tmp/vme_cluster_audit.sh
/tmp/vme_cluster_audit.sh

echo "========================================================================"
echo "SUCCESS: Audit processing complete."
echo "Plain-Text Tabular Table Generated: $TXT_OUT"
echo "Web-Browser Tabular Document Generated: $HTML_OUT"
echo "========================================================================"
EOF
