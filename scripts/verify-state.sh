#!/bin/bash

# Complete State Verification Script for Proxmox Homelab
# Deep inspection of all systems and services
# Version: 1.0
# Last Updated: 2025-11-25

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PRIMARY_NODE="192.168.10.11"
ALL_NODES="192.168.10.11 192.168.10.12 192.168.10.13"
LOG_FILE="/tmp/verify-state-$(date +%Y%m%d-%H%M%S).log"

# Service definitions
declare -A CONTAINERS=(
    [100]="tailscale:192.168.40.10:Tailscale"
    [101]="pihole:192.168.40.53:Pi-hole"
    [102]="nginx:192.168.40.22:Nginx-Proxy-Manager"
    [103]="uptime-kuma:192.168.40.23:Uptime-Kuma"
    [104]="nextcloud:192.168.40.31:Nextcloud"
    [105]="mariadb:192.168.40.32:MariaDB"
    [112]="n8n:192.168.40.61:n8n"
)

# Test results storage
declare -A TEST_RESULTS
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Logging function
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log_no_newline() {
    echo -n "$1" | tee -a "$LOG_FILE"
}

# Result functions
pass() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
    TEST_RESULTS["$1"]="PASS"
}

fail() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
    TEST_RESULTS["$1"]="FAIL"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
    ((TOTAL_TESTS++))
    TEST_RESULTS["$1"]="WARN"
}

info() {
    echo -e "${CYAN}ℹ${NC} $1" | tee -a "$LOG_FILE"
}

section() {
    log ""
    log "════════════════════════════════════════════════════════════════"
    log "  $1"
    log "════════════════════════════════════════════════════════════════"
}

subsection() {
    log ""
    log "──────────────────────────────────────"
    log "▶ $1"
    log "──────────────────────────────────────"
}

# Main execution
clear
log "╔════════════════════════════════════════════════════════════════╗"
log "║     PROXMOX HOMELAB COMPLETE STATE VERIFICATION                ║"
log "║     $(date '+%Y-%m-%d %H:%M:%S')                                ║"
log "╚════════════════════════════════════════════════════════════════╝"
log ""
log "Log file: $LOG_FILE"
log ""

# ═══════════════════════════════════════════════════════════════
# SECTION 1: Network Infrastructure
# ═══════════════════════════════════════════════════════════════
section "NETWORK INFRASTRUCTURE VERIFICATION"

subsection "Core Network Components"

# Test OPNsense
log_no_newline "OPNsense Router (192.168.10.1): "
if ping -c 1 -W 1 192.168.10.1 &>/dev/null; then
    if curl -k -s --max-time 3 https://192.168.10.1 | grep -q "OPNsense" 2>/dev/null; then
        pass "Responding (Web UI accessible)"
    else
        warn "Ping OK but Web UI not accessible"
    fi
else
    fail "Not responding"
fi

# Test Internet
log_no_newline "Internet Connectivity: "
if ping -c 1 -W 2 8.8.8.8 &>/dev/null; then
    if ping -c 1 -W 2 1.1.1.1 &>/dev/null; then
        pass "Multiple paths confirmed"
    else
        warn "Google DNS OK, Cloudflare DNS failed"
    fi
else
    fail "No internet connectivity"
fi

subsection "VLAN Connectivity Matrix"

VLANS=(
    "10:Management:192.168.10.1"
    "20:Corosync:192.168.20.11"
    "30:Storage:192.168.30.11"
    "40:Services:192.168.40.1"
)

for vlan_info in "${VLANS[@]}"; do
    IFS=':' read -r vlan_id vlan_name test_ip <<< "$vlan_info"
    log_no_newline "VLAN $vlan_id ($vlan_name): "
    
    # Test from primary node
    if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "ping -c 1 -W 1 $test_ip" &>/dev/null; then
        pass "Accessible from pve1"
    else
        fail "Not accessible from pve1"
    fi
done

subsection "DNS Resolution Tests"

# Test different DNS servers
DNS_SERVERS=(
    "192.168.40.53:Pi-hole"
    "192.168.10.1:OPNsense"
    "8.8.8.8:Google"
)

for dns_info in "${DNS_SERVERS[@]}"; do
    IFS=':' read -r dns_ip dns_name <<< "$dns_info"
    log_no_newline "DNS Server $dns_name ($dns_ip): "
    
    if nslookup google.com $dns_ip &>/dev/null; then
        # Test local domain too
        if [[ "$dns_name" == "Pi-hole" ]]; then
            if nslookup pihole.homelab.local $dns_ip &>/dev/null; then
                pass "External + Local domains working"
            else
                warn "External OK, Local domains failing"
            fi
        else
            pass "External resolution working"
        fi
    else
        fail "Not responding"
    fi
done

# ═══════════════════════════════════════════════════════════════
# SECTION 2: Proxmox Cluster Deep Dive
# ═══════════════════════════════════════════════════════════════
section "PROXMOX CLUSTER VERIFICATION"

subsection "Node Connectivity & Status"

for node_ip in $ALL_NODES; do
    node_num=$(($(echo $node_ip | cut -d. -f4) - 10))
    log ""
    log "═ Node pve${node_num} ($node_ip) ═"
    
    # Basic connectivity
    log_no_newline "  Ping test: "
    if ping -c 1 -W 1 $node_ip &>/dev/null; then
        pass "Responding"
    else
        fail "Not responding"
        continue
    fi
    
    # SSH access
    log_no_newline "  SSH access: "
    if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "echo test" &>/dev/null; then
        pass "Accessible"
    else
        fail "Cannot SSH"
        continue
    fi
    
    # Node services
    log_no_newline "  PVE services: "
    PVE_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "systemctl is-active pve-cluster pvedaemon pveproxy" 2>/dev/null | tr '\n' ' ')
    if [[ "$PVE_STATUS" == "active active active " ]]; then
        pass "All active"
    else
        warn "Some services not active: $PVE_STATUS"
    fi
    
    # CPU and Memory
    log_no_newline "  Resource usage: "
    LOAD=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "uptime | grep -oP 'load average: \K[^,]+'" 2>/dev/null)
    MEM_PERCENT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "free | grep Mem | awk '{print int(\$3/\$2 * 100)}'" 2>/dev/null)
    
    if [ ! -z "$LOAD" ] && [ ! -z "$MEM_PERCENT" ]; then
        if (( $(echo "$LOAD < 4" | bc -l) )) && [ "$MEM_PERCENT" -lt 80 ]; then
            pass "Load: $LOAD, Memory: ${MEM_PERCENT}%"
        else
            warn "Load: $LOAD, Memory: ${MEM_PERCENT}%"
        fi
    else
        fail "Cannot get resource info"
    fi
done

subsection "Cluster Quorum & Health"

log_no_newline "Cluster quorum: "
QUORUM=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "pvecm status 2>/dev/null | grep '^Quorate:' | awk '{print \$2}'" 2>/dev/null)
if [[ "$QUORUM" == "Yes" ]]; then
    pass "Established"
else
    fail "No quorum!"
fi

log_no_newline "Node membership: "
NODES=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "pvecm nodes 2>/dev/null | grep -c 'online'" 2>/dev/null)
if [[ "$NODES" == "3" ]]; then
    pass "All 3 nodes online"
else
    warn "Only $NODES nodes online"
fi

subsection "Ceph Storage Subsystem"

log_no_newline "Ceph health: "
CEPH_HEALTH=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "ceph health 2>/dev/null" 2>/dev/null)
if [[ "$CEPH_HEALTH" == *"HEALTH_OK"* ]]; then
    pass "HEALTH_OK"
elif [[ "$CEPH_HEALTH" == *"HEALTH_WARN"* ]]; then
    warn "$CEPH_HEALTH"
else
    fail "$CEPH_HEALTH"
fi

log_no_newline "Ceph OSDs: "
OSD_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "ceph osd stat 2>/dev/null | grep -oP '\d+ osds: \d+ up, \d+ in'" 2>/dev/null)
if [[ "$OSD_STATUS" == *"3 osds: 3 up, 3 in"* ]]; then
    pass "All 3 OSDs up and in"
else
    warn "$OSD_STATUS"
fi

log_no_newline "Ceph usage: "
CEPH_USAGE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "ceph df 2>/dev/null | grep 'TOTAL' -A1 | tail -1 | awk '{print \"Used: \"\$3\" of \"\$1\" (\"int(\$4)\"%)\" }'" 2>/dev/null)
if [ ! -z "$CEPH_USAGE" ]; then
    USAGE_PCT=$(echo "$CEPH_USAGE" | grep -oP '\(\K\d+(?=%)')
    if [ "$USAGE_PCT" -lt 80 ]; then
        pass "$CEPH_USAGE"
    else
        warn "$CEPH_USAGE - Getting full!"
    fi
else
    fail "Cannot determine usage"
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 3: Container Services
# ═══════════════════════════════════════════════════════════════
section "CONTAINER SERVICES VERIFICATION"

for ct_id in "${!CONTAINERS[@]}"; do
    IFS=':' read -r hostname ip service_name <<< "${CONTAINERS[$ct_id]}"
    
    subsection "CT$ct_id - $service_name"
    
    # Container status
    log_no_newline "  Container status: "
    CT_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "pct status $ct_id 2>/dev/null" 2>/dev/null)
    
    if [[ "$CT_STATUS" == *"running"* ]]; then
        pass "Running"
    else
        fail "Not running"
        continue
    fi
    
    # Network connectivity
    log_no_newline "  Network (ping $ip): "
    if ping -c 1 -W 1 $ip &>/dev/null; then
        pass "Responding"
    else
        fail "Not responding"
    fi
    
    # Service-specific checks
    case "$service_name" in
        "Tailscale")
            log_no_newline "  Tailscale status: "
            TS_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct exec $ct_id -- tailscale status 2>/dev/null | head -1" 2>/dev/null)
            if [[ "$TS_STATUS" == *"100.89.200.114"* ]]; then
                pass "Connected (100.89.200.114)"
            else
                warn "Status unclear"
            fi
            ;;
            
        "Pi-hole")
            log_no_newline "  FTL service: "
            FTL_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct exec $ct_id -- systemctl is-active pihole-FTL 2>/dev/null" 2>/dev/null)
            if [[ "$FTL_STATUS" == "active" ]]; then
                pass "Active"
            else
                fail "Not active"
            fi
            
            log_no_newline "  DNS queries: "
            if nslookup test.com $ip &>/dev/null; then
                pass "Resolving"
            else
                fail "Not resolving"
            fi
            ;;
            
        "Nginx-Proxy-Manager")
            log_no_newline "  Web interface: "
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$ip:81" 2>/dev/null)
            if [[ "$HTTP_CODE" == "200" ]]; then
                pass "Accessible (HTTP 200)"
            else
                warn "HTTP $HTTP_CODE"
            fi
            
            log_no_newline "  Docker status: "
            DOCKER_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct exec $ct_id -- docker ps 2>/dev/null | grep -c nginx" 2>/dev/null || echo "0")
            if [[ "$DOCKER_STATUS" -ge 1 ]]; then
                pass "Container running"
            else
                fail "Docker container not running"
            fi
            ;;
            
        "Uptime-Kuma")
            log_no_newline "  Web interface: "
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$ip:3001" 2>/dev/null)
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
                pass "Accessible (HTTP $HTTP_CODE)"
            else
                fail "HTTP $HTTP_CODE"
            fi
            ;;
            
        "Nextcloud")
            log_no_newline "  Apache service: "
            APACHE_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct exec $ct_id -- systemctl is-active apache2 2>/dev/null" 2>/dev/null)
            if [[ "$APACHE_STATUS" == "active" ]]; then
                pass "Active"
            else
                fail "Not active"
            fi
            
            log_no_newline "  Web interface: "
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$ip" 2>/dev/null)
            if [[ "$HTTP_CODE" == "302" ]] || [[ "$HTTP_CODE" == "200" ]]; then
                pass "Accessible"
            else
                warn "HTTP $HTTP_CODE"
            fi
            ;;
            
        "MariaDB")
            log_no_newline "  Database service: "
            MYSQL_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct exec $ct_id -- systemctl is-active mariadb 2>/dev/null" 2>/dev/null)
            if [[ "$MYSQL_STATUS" == "active" ]]; then
                pass "Active"
            else
                fail "Not active"
            fi
            
            log_no_newline "  Port 3306: "
            if nc -z -w1 $ip 3306 2>/dev/null; then
                pass "Listening"
            else
                fail "Not accessible"
            fi
            ;;
            
        "n8n")
            log_no_newline "  Docker status: "
            DOCKER_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct exec $ct_id -- docker ps 2>/dev/null | grep -c n8n" 2>/dev/null || echo "0")
            if [[ "$DOCKER_STATUS" -ge 1 ]]; then
                pass "Container running"
            else
                fail "Docker container not running"
            fi
            
            log_no_newline "  Web interface: "
            HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://$ip:5678" 2>/dev/null)
            if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]]; then
                pass "Accessible"
            else
                warn "HTTP $HTTP_CODE"
            fi
            ;;
    esac
    
    # Resource usage
    log_no_newline "  Resource usage: "
    RESOURCES=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "pct exec $ct_id -- bash -c 'echo \"CPU: \$(top -bn1 | grep \"Cpu(s)\" | awk \"{print \\$2}\")% MEM: \$(free -m | grep Mem | awk \"{print int(\\$3/\\$2 * 100)}\")%\"' 2>/dev/null" 2>/dev/null)
    
    if [ ! -z "$RESOURCES" ]; then
        info "$RESOURCES"
    else
        warn "Cannot determine"
    fi
done

# ═══════════════════════════════════════════════════════════════
# SECTION 4: Storage & Backups
# ═══════════════════════════════════════════════════════════════
section "STORAGE & BACKUP VERIFICATION"

subsection "Mac Pro NAS Status"

log_no_newline "Mac Pro ping (192.168.30.20): "
if ping -c 1 -W 1 192.168.30.20 &>/dev/null; then
    warn "Responding (unusual - normally doesn't ping)"
else
    info "Not responding to ping (normal)"
fi

log_no_newline "SSHFS mounts on nodes: "
MOUNT_COUNT=0
for node_ip in $ALL_NODES; do
    if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip "df -h | grep -q macpro" 2>/dev/null; then
        ((MOUNT_COUNT++))
    fi
done

if [ $MOUNT_COUNT -eq 3 ]; then
    pass "Mounted on all 3 nodes"
elif [ $MOUNT_COUNT -gt 0 ]; then
    warn "Mounted on $MOUNT_COUNT/3 nodes"
else
    fail "Not mounted on any nodes"
fi

subsection "Backup Status"

log_no_newline "Latest backup: "
LATEST_BACKUP=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "ls -t /mnt/macpro/proxmox-backups/dump/*.zst 2>/dev/null | head -1 | xargs basename 2>/dev/null" 2>/dev/null)

if [ ! -z "$LATEST_BACKUP" ]; then
    # Extract date from filename
    BACKUP_DATE=$(echo "$LATEST_BACKUP" | grep -oP '\d{4}_\d{2}_\d{2}')
    TODAY=$(date +%Y_%m_%d)
    YESTERDAY=$(date -d "yesterday" +%Y_%m_%d)
    
    if [[ "$BACKUP_DATE" == "$TODAY" ]]; then
        pass "Today's backup found"
    elif [[ "$BACKUP_DATE" == "$YESTERDAY" ]]; then
        warn "Yesterday's backup (today pending)"
    else
        warn "Backup from $BACKUP_DATE"
    fi
else
    fail "No backups found"
fi

log_no_newline "Backup count by container: "
for ct_id in "${!CONTAINERS[@]}"; do
    COUNT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "ls /mnt/macpro/proxmox-backups/dump/*lxc-${ct_id}-*.zst 2>/dev/null | wc -l" 2>/dev/null || echo "0")
    log "    CT${ct_id}: $COUNT backups"
done

# ═══════════════════════════════════════════════════════════════
# SECTION 5: Service Accessibility Tests
# ═══════════════════════════════════════════════════════════════
section "SERVICE ACCESSIBILITY VERIFICATION"

subsection "Web Services via Domain Names"

WEB_SERVICES=(
    "pihole.homelab.local:/admin/:Pi-hole Admin"
    "nginx.homelab.local::Nginx Proxy Manager"
    "status.homelab.local::Uptime Kuma"
    "cloud.homelab.local::Nextcloud"
    "automation.homelab.local::n8n"
)

for service_info in "${WEB_SERVICES[@]}"; do
    IFS=':' read -r domain path service_name <<< "$service_info"
    log_no_newline "$service_name (http://${domain}${path}): "
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 "http://${domain}${path}" 2>/dev/null)
    
    if [[ "$HTTP_CODE" == "200" ]] || [[ "$HTTP_CODE" == "302" ]] || [[ "$HTTP_CODE" == "308" ]]; then
        pass "Accessible (HTTP $HTTP_CODE)"
    elif [[ "$HTTP_CODE" == "403" ]]; then
        warn "Forbidden (HTTP 403)"
    else
        fail "Not accessible (HTTP $HTTP_CODE)"
    fi
done

subsection "Direct IP Access Tests"

log_no_newline "Pi-hole direct (192.168.40.53): "
if curl -s --max-time 3 "http://192.168.40.53/admin/" | grep -q "Pi-hole" 2>/dev/null; then
    pass "Admin interface accessible"
else
    fail "Not accessible"
fi

log_no_newline "NPM direct (192.168.40.22:81): "
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" --max-time 3 "http://192.168.40.22:81" 2>/dev/null)
if [[ "$HTTP_CODE" == "200" ]]; then
    pass "Admin interface accessible"
else
    warn "HTTP $HTTP_CODE"
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 6: Performance Metrics
# ═══════════════════════════════════════════════════════════════
section "PERFORMANCE METRICS"

subsection "Cluster Resource Usage"

TOTAL_CPU_USAGE=0
TOTAL_MEM_USAGE=0
NODE_COUNT=0

for node_ip in $ALL_NODES; do
    node_num=$(($(echo $node_ip | cut -d. -f4) - 10))
    
    CPU_IDLE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip \
        "top -bn1 | grep 'Cpu(s)' | awk '{print \$8}' | cut -d'%' -f1" 2>/dev/null)
    
    if [ ! -z "$CPU_IDLE" ]; then
        CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc)
        MEM_USAGE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$node_ip \
            "free | grep Mem | awk '{print int(\$3/\$2 * 100)}'" 2>/dev/null)
        
        log "  pve${node_num}: CPU: ${CPU_USAGE}%, Memory: ${MEM_USAGE}%"
        
        TOTAL_CPU_USAGE=$(echo "$TOTAL_CPU_USAGE + $CPU_USAGE" | bc)
        TOTAL_MEM_USAGE=$(echo "$TOTAL_MEM_USAGE + $MEM_USAGE" | bc)
        ((NODE_COUNT++))
    fi
done

if [ $NODE_COUNT -gt 0 ]; then
    AVG_CPU=$(echo "scale=1; $TOTAL_CPU_USAGE / $NODE_COUNT" | bc)
    AVG_MEM=$(echo "scale=0; $TOTAL_MEM_USAGE / $NODE_COUNT" | bc)
    
    log ""
    log_no_newline "Cluster averages: "
    if (( $(echo "$AVG_CPU < 50" | bc -l) )) && [ "$AVG_MEM" -lt 70 ]; then
        pass "CPU: ${AVG_CPU}%, Memory: ${AVG_MEM}%"
    else
        warn "CPU: ${AVG_CPU}%, Memory: ${AVG_MEM}%"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# SECTION 7: Configuration Verification
# ═══════════════════════════════════════════════════════════════
section "CONFIGURATION VERIFICATION"

subsection "Critical Configuration Files"

log_no_newline "Pi-hole config integrity: "
HOST_COUNT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "pct exec 101 -- grep -c 'hosts = \[' /etc/pihole/pihole.toml 2>/dev/null" 2>/dev/null || echo "0")

if [ "$HOST_COUNT" = "1" ]; then
    pass "Single hosts array (correct)"
else
    fail "Multiple hosts arrays detected"
fi

log_no_newline "Container auto-start: "
AUTOSTART_COUNT=0
for ct_id in "${!CONTAINERS[@]}"; do
    ONBOOT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "pct config $ct_id 2>/dev/null | grep -c 'onboot: 1'" 2>/dev/null || echo "0")
    if [ "$ONBOOT" = "1" ]; then
        ((AUTOSTART_COUNT++))
    fi
done

if [ $AUTOSTART_COUNT -eq ${#CONTAINERS[@]} ]; then
    pass "All containers set to auto-start"
else
    warn "Only $AUTOSTART_COUNT/${#CONTAINERS[@]} set to auto-start"
fi

# ═══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════
section "VERIFICATION SUMMARY"

log ""
log "╔════════════════════════════════════════════════════════════════╗"
log "║                        FINAL RESULTS                            ║"
log "╚════════════════════════════════════════════════════════════════╝"
log ""

# Calculate percentages
if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
else
    SUCCESS_RATE=0
fi

log "Total Tests:      $TOTAL_TESTS"
log "Passed:          ${GREEN}$PASSED_TESTS${NC}"
log "Failed:          ${RED}$FAILED_TESTS${NC}"
log "Success Rate:    ${SUCCESS_RATE}%"
log ""

# Overall health assessment
if [ $FAILED_TESTS -eq 0 ]; then
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║         ${GREEN}SYSTEM HEALTH: EXCELLENT - ALL TESTS PASSED${NC}         ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=0
elif [ $SUCCESS_RATE -ge 90 ]; then
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║         ${GREEN}SYSTEM HEALTH: GOOD - ${SUCCESS_RATE}% TESTS PASSED${NC}              ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=0
elif [ $SUCCESS_RATE -ge 75 ]; then
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║       ${YELLOW}SYSTEM HEALTH: FAIR - ATTENTION NEEDED${NC}                ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=1
else
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║       ${RED}SYSTEM HEALTH: CRITICAL - IMMEDIATE ACTION REQUIRED${NC}    ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=2
fi

# List failed tests if any
if [ $FAILED_TESTS -gt 0 ]; then
    log ""
    log "Failed Tests:"
    for test in "${!TEST_RESULTS[@]}"; do
        if [[ "${TEST_RESULTS[$test]}" == "FAIL" ]]; then
            log "  ${RED}✗${NC} $test"
        fi
    done
fi

log ""
log "═══════════════════════════════════════════════════════════════"
log "Verification completed: $(date '+%Y-%m-%d %H:%M:%S')"
log "Full log saved to: $LOG_FILE"
log ""

exit $EXIT_CODE