#!/bin/bash

# Daily Health Check Script for Proxmox Homelab
# Run this each morning to verify all systems operational
# Version: 1.1
# Last Updated: 2025-12-02

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MANAGEMENT_IPS="192.168.10.11 192.168.10.12 192.168.10.13"
SERVICE_CONTAINERS="100 101 102 103 104 105 107 112"
CRITICAL_SERVICES=(
    "192.168.40.10:Tailscale"
    "192.168.40.53:Pi-hole"
    "192.168.40.22:Nginx-Proxy"
    "192.168.40.23:Uptime-Kuma"
    "192.168.40.31:Nextcloud"
    "192.168.40.32:MariaDB"
    "192.168.40.40:UniFi-Controller"
    "192.168.40.61:n8n"
)
MAC_PRO_IP="192.168.30.20"
BACKUP_DIR="/mnt/macpro/proxmox-backups/dump"

# UPS Configuration
UPS_NAME="cyberpower"
UPS_HOST="localhost"
UPS_LOW_BATTERY_WARN=30
UPS_HIGH_LOAD_WARN=80

# Counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNINGS=0

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}     PROXMOX HOMELAB DAILY HEALTH CHECK${NC}"
    echo -e "${BLUE}     $(date '+%Y-%m-%d %H:%M:%S')${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

check_pass() {
    echo -e "${GREEN}✓${NC} $1"
    ((TOTAL_CHECKS++))
    ((PASSED_CHECKS++))
}

check_fail() {
    echo -e "${RED}✗${NC} $1"
    ((TOTAL_CHECKS++))
    ((FAILED_CHECKS++))
}

check_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
    ((TOTAL_CHECKS++))
    ((WARNINGS++))
}

section_header() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo "─────────────────────────────────────"
}

# Start health check
clear
print_header

# ═══════════════════════════════════════════════════════════════
# SECTION 1: UPS Status (Check First - Most Critical)
# ═══════════════════════════════════════════════════════════════
section_header "UPS Power Protection"

# Check UPS status from pve1
echo -n "UPS Connection: "
UPS_DATA=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@192.168.10.11 "upsc $UPS_NAME@$UPS_HOST 2>/dev/null" 2>/dev/null)

if [ ! -z "$UPS_DATA" ]; then
    check_pass "Connected to NUT server"
    
    # Parse UPS values
    UPS_STATUS=$(echo "$UPS_DATA" | grep "^ups.status:" | cut -d' ' -f2)
    UPS_LOAD=$(echo "$UPS_DATA" | grep "^ups.load:" | cut -d' ' -f2)
    UPS_CHARGE=$(echo "$UPS_DATA" | grep "^battery.charge:" | cut -d' ' -f2)
    UPS_RUNTIME=$(echo "$UPS_DATA" | grep "^battery.runtime:" | cut -d' ' -f2)
    UPS_INPUT=$(echo "$UPS_DATA" | grep "^input.voltage:" | cut -d' ' -f2)
    
    # Convert runtime to minutes
    if [ ! -z "$UPS_RUNTIME" ]; then
        UPS_RUNTIME_MIN=$((UPS_RUNTIME / 60))
    else
        UPS_RUNTIME_MIN="?"
    fi
    
    # Check UPS status
    echo -n "UPS Status: "
    case "$UPS_STATUS" in
        OL)
            check_pass "Online (Mains Power)"
            ;;
        OB)
            check_fail "ON BATTERY - Power failure!"
            ;;
        OL\ CHRG|"OL CHRG")
            check_pass "Online, Charging"
            ;;
        OB\ DISCHRG|"OB DISCHRG")
            check_fail "ON BATTERY, Discharging!"
            ;;
        *)
            check_warn "Status: $UPS_STATUS"
            ;;
    esac
    
    # Check battery charge
    echo -n "Battery Charge: "
    if [ ! -z "$UPS_CHARGE" ]; then
        if [ "$UPS_CHARGE" -ge 90 ]; then
            check_pass "${UPS_CHARGE}%"
        elif [ "$UPS_CHARGE" -ge "$UPS_LOW_BATTERY_WARN" ]; then
            check_warn "${UPS_CHARGE}% - Not fully charged"
        else
            check_fail "${UPS_CHARGE}% - LOW BATTERY!"
        fi
    else
        check_warn "Unable to read battery charge"
    fi
    
    # Check load
    echo -n "UPS Load: "
    if [ ! -z "$UPS_LOAD" ]; then
        if [ "$UPS_LOAD" -lt "$UPS_HIGH_LOAD_WARN" ]; then
            check_pass "${UPS_LOAD}% (~${UPS_RUNTIME_MIN} min runtime)"
        else
            check_warn "${UPS_LOAD}% - High load! (~${UPS_RUNTIME_MIN} min runtime)"
        fi
    else
        check_warn "Unable to read UPS load"
    fi
    
    # Check input voltage
    echo -n "Input Voltage: "
    if [ ! -z "$UPS_INPUT" ]; then
        # Check if voltage is in acceptable range (200-250V for AU)
        INPUT_INT=${UPS_INPUT%.*}
        if [ "$INPUT_INT" -ge 200 ] && [ "$INPUT_INT" -le 250 ]; then
            check_pass "${UPS_INPUT}V"
        else
            check_warn "${UPS_INPUT}V - Outside normal range"
        fi
    else
        check_warn "Unable to read input voltage"
    fi
    
else
    check_fail "Cannot connect to UPS - NUT not responding!"
fi

# Check NUT services on all nodes
echo -n "NUT Monitor (pve1): "
if ssh -o ConnectTimeout=3 -o BatchMode=yes root@192.168.10.11 "systemctl is-active nut-monitor >/dev/null 2>&1" 2>/dev/null; then
    check_pass "Running"
else
    check_fail "Not running!"
fi

echo -n "NUT Monitor (pve2): "
if ssh -o ConnectTimeout=3 -o BatchMode=yes root@192.168.10.12 "systemctl is-active nut-monitor >/dev/null 2>&1" 2>/dev/null; then
    check_pass "Running"
else
    check_warn "Not running"
fi

echo -n "NUT Monitor (pve3): "
if ssh -o ConnectTimeout=3 -o BatchMode=yes root@192.168.10.13 "systemctl is-active nut-monitor >/dev/null 2>&1" 2>/dev/null; then
    check_pass "Running"
else
    check_warn "Not running"
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 2: Network Infrastructure
# ═══════════════════════════════════════════════════════════════
section_header "Network Infrastructure"

# Check OPNsense
echo -n "OPNsense Router (192.168.10.1): "
if ping -c 1 -W 1 192.168.10.1 &>/dev/null; then
    check_pass "Responding"
else
    check_fail "Not responding - CRITICAL!"
fi

# Check internet connectivity
echo -n "Internet Connectivity: "
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    check_pass "Working"
else
    check_fail "No internet access"
fi

# Check DNS resolution
echo -n "DNS Resolution (Pi-hole): "
if nslookup google.com 192.168.40.53 &>/dev/null; then
    check_pass "Working"
else
    check_warn "Pi-hole DNS not working, trying fallback"
    if nslookup google.com 192.168.10.1 &>/dev/null; then
        check_warn "Fallback DNS working (OPNsense)"
    else
        check_fail "All DNS failed!"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 3: Proxmox Cluster
# ═══════════════════════════════════════════════════════════════
section_header "Proxmox Cluster Status"

# Check each node
for node_ip in $MANAGEMENT_IPS; do
    node_name=$(echo $node_ip | cut -d. -f4)
    echo -n "Node pve$((node_name-10)) ($node_ip): "
    
    if ping -c 1 -W 1 $node_ip &>/dev/null; then
        # Try to get node status via SSH
        if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "pvesh get /nodes/pve$((node_name-10))/status" &>/dev/null; then
            check_pass "Online and responsive"
        else
            check_warn "Ping OK but SSH/API not responding"
        fi
    else
        check_fail "Not responding"
    fi
done

# Check cluster quorum (from first responsive node)
echo -n "Cluster Quorum: "
QUORUM_OK=false
for node_ip in $MANAGEMENT_IPS; do
    if timeout 5 ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "pvecm status 2>/dev/null | grep -q 'Quorate:.*Yes'" 2>/dev/null; then
        check_pass "Established"
        QUORUM_OK=true
        break
    fi
done
if [ "$QUORUM_OK" = false ]; then
    check_fail "No quorum - check cluster!"
fi

# Check Ceph health (if quorum OK)
if [ "$QUORUM_OK" = true ]; then
    echo -n "Ceph Storage: "
    CEPH_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@192.168.10.11 "ceph health 2>/dev/null" 2>/dev/null || echo "UNKNOWN")
    
    case "$CEPH_STATUS" in
        *HEALTH_OK*)
            check_pass "HEALTH_OK"
            ;;
        *HEALTH_WARN*)
            check_warn "HEALTH_WARN - Check details"
            ;;
        *HEALTH_ERR*)
            check_fail "HEALTH_ERR - Immediate attention needed!"
            ;;
        *)
            check_warn "Unable to determine Ceph status"
            ;;
    esac
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 4: Service Containers
# ═══════════════════════════════════════════════════════════════
section_header "Service Containers"

# Get container status from first responsive node
CONTAINERS_OK=0
CONTAINERS_TOTAL=0

for node_ip in $MANAGEMENT_IPS; do
    if ping -c 1 -W 1 $node_ip &>/dev/null; then
        for ct_id in $SERVICE_CONTAINERS; do
            ((CONTAINERS_TOTAL++))
            ct_status=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "pct status $ct_id 2>/dev/null" 2>/dev/null || echo "unknown")
            
            case "$ct_id" in
                100) SERVICE_NAME="Tailscale" ;;
                101) SERVICE_NAME="Pi-hole" ;;
                102) SERVICE_NAME="Nginx-Proxy" ;;
                103) SERVICE_NAME="Uptime-Kuma" ;;
                104) SERVICE_NAME="Nextcloud" ;;
                105) SERVICE_NAME="MariaDB" ;;
                107) SERVICE_NAME="UniFi-Controller" ;;
                112) SERVICE_NAME="n8n" ;;
                *) SERVICE_NAME="Unknown" ;;
            esac
            
            echo -n "CT$ct_id ($SERVICE_NAME): "
            
            if [[ "$ct_status" == *"running"* ]]; then
                check_pass "Running"
                ((CONTAINERS_OK++))
            elif [[ "$ct_status" == *"stopped"* ]]; then
                check_fail "Stopped"
            else
                check_warn "Status unknown"
            fi
        done
        break
    fi
done

# ═══════════════════════════════════════════════════════════════
# SECTION 5: Service Availability
# ═══════════════════════════════════════════════════════════════
section_header "Service Accessibility"

for service in "${CRITICAL_SERVICES[@]}"; do
    IFS=':' read -r ip name <<< "$service"
    echo -n "$name ($ip): "
    
    # First try ping
    if ping -c 1 -W 1 $ip &>/dev/null; then
        # Then try HTTP if it's a web service
        case "$name" in
            Pi-hole|Nginx-Proxy|Uptime-Kuma|Nextcloud|n8n|UniFi-Controller)
                # Get appropriate port
                case "$name" in
                    Pi-hole) PORT=80; URL="http://$ip/admin/" ;;
                    Nginx-Proxy) PORT=81; URL="http://$ip:81" ;;
                    Uptime-Kuma) PORT=3001; URL="http://$ip:3001" ;;
                    Nextcloud) PORT=80; URL="http://$ip" ;;
                    UniFi-Controller) PORT=8443; URL="https://$ip:8443" ;;
                    n8n) PORT=5678; URL="http://$ip:5678" ;;
                esac
                
                HTTP_CODE=$(curl -sk -o /dev/null -w "%{http_code}" --max-time 3 "$URL" 2>/dev/null)
                
                if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]] || [[ "$HTTP_CODE" == "403" ]]; then
                    check_pass "Responding (HTTP $HTTP_CODE)"
                else
                    check_warn "Ping OK but HTTP issue (Code: $HTTP_CODE)"
                fi
                ;;
            *)
                check_pass "Responding to ping"
                ;;
        esac
    else
        check_fail "Not responding"
    fi
done

# ═══════════════════════════════════════════════════════════════
# SECTION 6: Storage & Backup
# ═══════════════════════════════════════════════════════════════
section_header "Storage & Backup"

# Check Mac Pro NAS
echo -n "Mac Pro NAS ($MAC_PRO_IP): "
if ping -c 1 -W 1 $MAC_PRO_IP &>/dev/null; then
    check_pass "Responding"
else
    # Check if mount exists on any node
    MOUNT_OK=false
    for node_ip in $MANAGEMENT_IPS; do
        if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "df -h | grep -q macpro" 2>/dev/null; then
            check_pass "Mount verified on pve$(($(echo $node_ip | cut -d. -f4)-10))"
            MOUNT_OK=true
            break
        fi
    done
    if [ "$MOUNT_OK" = false ]; then
        check_fail "Not mounted on any node"
    fi
fi

# Check Mac Pro NUT client
echo -n "Mac Pro NUT Monitor: "
if ssh -o ConnectTimeout=3 -o BatchMode=yes xavier@$MAC_PRO_IP "systemctl is-active nut-monitor 2>/dev/null" 2>/dev/null | grep -q "active"; then
    check_pass "Running"
else
    check_warn "Not verified (may not respond to ping)"
fi

# Check backup recency
echo -n "Recent Backups: "
TODAY=$(date +%Y_%m_%d)
YESTERDAY=$(date -d "yesterday" +%Y_%m_%d)

BACKUP_FOUND=false
for node_ip in $MANAGEMENT_IPS; do
    if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "ls $BACKUP_DIR/*$TODAY* 2>/dev/null | head -1" &>/dev/null; then
        check_pass "Today's backup found"
        BACKUP_FOUND=true
        break
    elif ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "ls $BACKUP_DIR/*$YESTERDAY* 2>/dev/null | head -1" &>/dev/null; then
        check_warn "Yesterday's backup found (today's pending)"
        BACKUP_FOUND=true
        break
    fi
done

if [ "$BACKUP_FOUND" = false ]; then
    check_fail "No recent backups found!"
fi

# Check Ceph usage
echo -n "Ceph Storage Usage: "
for node_ip in $MANAGEMENT_IPS; do
    if CEPH_USAGE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "ceph df 2>/dev/null | grep 'USED' -A1 | tail -1 | awk '{print \$4\" used of \"\$2\" (usage: \"\$5\")\"}'" 2>/dev/null); then
        if [ ! -z "$CEPH_USAGE" ]; then
            # Check if usage is over 80%
            USAGE_PCT=$(echo "$CEPH_USAGE" | grep -oP '\d+(?=%)')
            if [ ! -z "$USAGE_PCT" ] && [ "$USAGE_PCT" -gt 80 ]; then
                check_warn "$CEPH_USAGE - Getting full!"
            else
                check_pass "$CEPH_USAGE"
            fi
            break
        fi
    fi
done

# ═══════════════════════════════════════════════════════════════
# SECTION 7: Remote Access
# ═══════════════════════════════════════════════════════════════
section_header "Remote Access"

# Check Tailscale
echo -n "Tailscale VPN: "
# Check if Tailscale container is accessible and get status
for node_ip in $MANAGEMENT_IPS; do
    if TS_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "pct exec 100 -- tailscale status 2>/dev/null | head -1" 2>/dev/null); then
        if [[ "$TS_STATUS" == *"100.89.200.114"* ]]; then
            check_pass "Connected (100.89.200.114)"
        else
            check_warn "Container running but status unclear"
        fi
        break
    fi
done

# ═══════════════════════════════════════════════════════════════
# SECTION 8: Quick Performance Metrics
# ═══════════════════════════════════════════════════════════════
section_header "Performance Metrics"

# Get load average from nodes
for node_ip in $MANAGEMENT_IPS; do
    node_name=$(echo $node_ip | cut -d. -f4)
    echo -n "Node pve$((node_name-10)) Load: "
    
    if LOAD=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "uptime | grep -oP 'load average: \K.*'" 2>/dev/null); then
        # Parse first number (1-min load)
        LOAD_1MIN=$(echo $LOAD | cut -d, -f1 | tr -d ' ')
        
        # Check if load is high (>4 for 6-core system)
        if (( $(echo "$LOAD_1MIN > 4" | bc -l) )); then
            check_warn "High load: $LOAD"
        else
            check_pass "$LOAD"
        fi
    else
        check_warn "Unable to get load average"
    fi
done

# ═══════════════════════════════════════════════════════════════
# SUMMARY
# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}                          SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Calculate health score
if [ $TOTAL_CHECKS -gt 0 ]; then
    HEALTH_SCORE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))
else
    HEALTH_SCORE=0
fi

# Overall status
echo ""
if [ $FAILED_CHECKS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}▶ SYSTEM STATUS: HEALTHY${NC}"
elif [ $FAILED_CHECKS -eq 0 ]; then
    echo -e "${YELLOW}▶ SYSTEM STATUS: HEALTHY WITH WARNINGS${NC}"
else
    echo -e "${RED}▶ SYSTEM STATUS: ISSUES DETECTED${NC}"
fi

echo ""
echo "Total Checks:     $TOTAL_CHECKS"
echo -e "Passed:          ${GREEN}$PASSED_CHECKS${NC}"
echo -e "Warnings:        ${YELLOW}$WARNINGS${NC}"
echo -e "Failed:          ${RED}$FAILED_CHECKS${NC}"
echo "Health Score:    ${HEALTH_SCORE}%"
echo ""

# UPS Summary Line
if [ ! -z "$UPS_STATUS" ] && [ ! -z "$UPS_CHARGE" ] && [ ! -z "$UPS_LOAD" ]; then
    echo -e "${BLUE}▶ UPS Summary:${NC} Status: $UPS_STATUS | Battery: ${UPS_CHARGE}% | Load: ${UPS_LOAD}% | Runtime: ~${UPS_RUNTIME_MIN} min"
    echo ""
fi

# Recommendations
if [ $FAILED_CHECKS -gt 0 ] || [ $WARNINGS -gt 0 ]; then
    echo -e "${BLUE}▶ Recommendations:${NC}"
    
    if [ $FAILED_CHECKS -gt 0 ]; then
        echo -e "${RED}  • Address failed checks immediately${NC}"
        echo -e "${RED}  • Check /var/log/pve/tasks/ for errors${NC}"
        echo -e "${RED}  • Run 'journalctl -xe' on affected nodes${NC}"
    fi
    
    if [ $WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}  • Review warning items${NC}"
        echo -e "${YELLOW}  • Check service logs for issues${NC}"
        echo -e "${YELLOW}  • Consider running verify-state.sh for details${NC}"
    fi
else
    echo -e "${GREEN}  ✓ All systems operational!${NC}"
    echo -e "${GREEN}  ✓ UPS protection active${NC}"
    echo -e "${GREEN}  ✓ No action required${NC}"
fi

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo "Report generated: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Exit with appropriate code
if [ $FAILED_CHECKS -gt 0 ]; then
    exit 1
elif [ $WARNINGS -gt 0 ]; then
    exit 2
else
    exit 0
fi
