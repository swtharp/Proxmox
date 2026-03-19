#!/bin/bash
# Description: Proxmox VM and LXC Reporting Script

REPORT_FILE="/var/log/proxmox-report-$(date +%F).txt"

{
echo "======================================="
echo " Proxmox Report - $(date)"
echo "======================================="

# --- Function: Get VM IPs via qemu-guest-agent ---
get_vm_ip() {
    local vmid=$1
    local ip_json
    ip_json=$(qm guest cmd $vmid network-get-interfaces --verbose 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$ip_json" ]; then
        echo "$ip_json" | jq -r '.[] | .["ip-addresses"][] | select(."ip-address-type" == "ipv4") | select(."ip-address" | test("^127\\.") | not) | ."ip-address"' | paste -sd ", "
    else
        echo "guest-agent unavailable"
    fi
}

# --- Function: Get LXC IPs ---
get_lxc_ip() {
    local vmid=$1
    local ips
    ips=$(pct exec $vmid -- ip -4 -br addr show 2>/dev/null | awk '{print $3}' | cut -d'/' -f1 | grep -v '^127\.')
    if [ -n "$ips" ]; then
        echo "$ips" | paste -sd ", "
    else
        config_ip=$(pct config $vmid | grep 'ip=' | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+\.[0-9]\+')
        [ -n "$config_ip" ] && echo "$config_ip (from config)" || echo "none found"
    fi
}

# --- Virtual Machines ---
echo ""
echo "======================================="
echo " Virtual Machines"
echo "======================================="

for vmid in $(qm list | awk 'NR>1 {print $1}'); do
    name=$(qm config $vmid   | grep '^name:'    | awk '{print $2}')
    status=$(qm list          | awk -v id=$vmid '$1==id {print $3}')
    cores=$(qm config $vmid  | grep '^cores:'   | awk '{print $2}')
    mem=$(qm config $vmid    | grep '^memory:'  | awk '{print $2}')
    disk=$(qm config $vmid   | grep '^scsi0:'   | grep -o 'size=[^,]*' | cut -d= -f2)
    ips=$(get_vm_ip $vmid)
    os=$(qm config $vmid     | grep '^ostype:'  | awk '{print $2}')

    echo ""
    echo "  VM $vmid — $name"
    echo "  ─────────────────────────────"
    printf "  %-12s %s\n"  "Status:"  "$status"
    printf "  %-12s %s\n"  "OS:"      "$os"
    printf "  %-12s %s\n"  "CPU:"     "${cores} core(s)"
    printf "  %-12s %s\n"  "Memory:"  "${mem} MB"
    printf "  %-12s %s\n"  "Disk:"    "$disk"
    printf "  %-12s %s\n"  "IP(s):"   "$ips"
done

# --- LXC Containers ---
echo ""
echo "======================================="
echo " LXC Containers"
echo "======================================="

for vmid in $(pct list | awk 'NR>1 {print $1}'); do
    name=$(pct config $vmid   | grep '^hostname:' | awk '{print $2}')
    status=$(pct list          | awk -v id=$vmid '$1==id {print $2}')
    cores=$(pct config $vmid  | grep '^cores:'    | awk '{print $2}')
    mem=$(pct config $vmid    | grep '^memory:'   | awk '{print $2}')
    disk=$(pct config $vmid   | grep '^rootfs:'   | grep -o 'size=[^,]*' | cut -d= -f2)
    ips=$(get_lxc_ip $vmid)
    os=$(pct config $vmid     | grep '^ostype:'   | awk '{print $2}')

    echo ""
    echo "  CT $vmid — $name"
    echo "  ─────────────────────────────"
    printf "  %-12s %s\n"  "Status:"  "$status"
    printf "  %-12s %s\n"  "OS:"      "$os"
    printf "  %-12s %s\n"  "CPU:"     "${cores} core(s)"
    printf "  %-12s %s\n"  "Memory:"  "${mem} MB"
    printf "  %-12s %s\n"  "Disk:"    "$disk"
    printf "  %-12s %s\n"  "IP(s):"   "$ips"
done

echo ""
echo "======================================="
echo " End of Report"
echo "======================================="

} | tee $REPORT_FILE | mail -s "Proxmox Report $(date +%F)" steven@steventharp.com

echo "Report saved to $REPORT_FILE"
