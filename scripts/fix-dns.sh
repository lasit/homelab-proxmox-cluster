#!/bin/bash

# DNS Fix Utility for Proxmox Homelab
# Diagnoses and fixes common DNS issues
# Version: 1.0
# Last Updated: 2025-11-25

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
PIHOLE_IP="192.168.40.53"
PIHOLE_CT="101"
PROXY_IP="192.168.40.22"
OPNSENSE_IP="192.168.10.1"
PROXMOX_NODE="192.168.10.11"

# Service mappings for DNS
declare -A DNS_ENTRIES=(
    ["opnsense.homelab.local"]="192.168.10.1"
    ["pve1.homelab.local"]="192.168.10.11"
    ["pve2.homelab.local"]="192.168.10.12"
    ["pve3.homelab.local"]="192.168.10.13"
    ["tailscale.homelab.local"]="192.168.40.10"
    ["pihole.homelab.local"]="$PROXY_IP"
    ["nginx.homelab.local"]="$PROXY_IP"
    ["status.homelab.local"]="$PROXY_IP"
    ["cloud.homelab.local"]="$PROXY_IP"
    ["automation.homelab.local"]="$PROXY_IP"
)

# Functions
print_header() {
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}                 DNS DIAGNOSTIC & FIX UTILITY${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo "─────────────────────────────────────"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

info() {
    echo -e "  $1"
}

# Main script
clear
print_header

# ═══════════════════════════════════════════════════════════════
# STEP 1: Test DNS Servers
# ═══════════════════════════════════════════════════════════════
section "Testing DNS Servers"

# Test Pi-hole
echo -n "Pi-hole DNS ($PIHOLE_IP): "
if nslookup google.com $PIHOLE_IP &>/dev/null; then
    success "Responding"
    PIHOLE_OK=true
else
    error "Not responding"
    PIHOLE_OK=false
fi

# Test OPNsense DNS
echo -n "OPNsense DNS ($OPNSENSE_IP): "
if nslookup google.com $OPNSENSE_IP &>/dev/null; then
    success "Responding"
    OPNSENSE_DNS_OK=true
else
    error "Not responding"
    OPNSENSE_DNS_OK=false
fi

# Test public DNS
echo -n "Public DNS (8.8.8.8): "
if nslookup google.com 8.8.8.8 &>/dev/null; then
    success "Responding"
    PUBLIC_DNS_OK=true
else
    error "No internet or DNS blocked"
    PUBLIC_DNS_OK=false
fi

# ═══════════════════════════════════════════════════════════════
# STEP 2: Check Pi-hole Container
# ═══════════════════════════════════════════════════════════════
section "Pi-hole Container Status"

# Check container status
CT_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PROXMOX_NODE "pct status $PIHOLE_CT 2>/dev/null" 2>/dev/null || echo "unknown")

if [[ "$CT_STATUS" == *"running"* ]]; then
    success "Container CT$PIHOLE_CT is running"
    
    # Check Pi-hole FTL service
    echo -n "Pi-hole FTL service: "
    FTL_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PROXMOX_NODE \
        "pct exec $PIHOLE_CT -- systemctl is-active pihole-FTL 2>/dev/null" 2>/dev/null || echo "unknown")
    
    if [[ "$FTL_STATUS" == "active" ]]; then
        success "Active"
    else
        error "Not active - needs restart"
        NEEDS_FTL_RESTART=true
    fi
else
    error "Container not running!"
    NEEDS_CT_START=true
fi

# ═══════════════════════════════════════════════════════════════
# STEP 3: Check Pi-hole Configuration
# ═══════════════════════════════════════════════════════════════
section "Pi-hole Configuration"

if [ "$PIHOLE_OK" = true ]; then
    # Check listening mode
    echo -n "Listening mode: "
    LISTEN_MODE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PROXMOX_NODE \
        "pct exec $PIHOLE_CT -- grep 'listeningMode' /etc/pihole/pihole.toml 2>/dev/null | grep -v '#' | head -1" 2>/dev/null)
    
    if [[ "$LISTEN_MODE" == *"ALL"* ]]; then
        success "Set to ALL (correct)"
    elif [[ "$LISTEN_MODE" == *"LOCAL"* ]]; then
        error "Set to LOCAL (needs fix)"
        NEEDS_LISTEN_FIX=true
    else
        warning "Unable to determine"
    fi
    
    # Check domain setting
    echo -n "Domain configuration: "
    DOMAIN=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PROXMOX_NODE \
        "pct exec $PIHOLE_CT -- grep '^[[:space:]]*domain =' /etc/pihole/pihole.toml 2>/dev/null | grep -v '#' | head -1" 2>/dev/null)
    
    if [[ "$DOMAIN" == *"pihole.homelab.local"* ]]; then
        success "Set to pihole.homelab.local"
    else
        warning "Different domain: $DOMAIN"
    fi
    
    # Check for duplicate hosts arrays
    echo -n "Hosts arrays count: "
    HOST_COUNT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PROXMOX_NODE \
        "pct exec $PIHOLE_CT -- grep -c 'hosts = \[' /etc/pihole/pihole.toml 2>/dev/null" 2>/dev/null || echo "0")
    
    if [ "$HOST_COUNT" = "1" ]; then
        success "Single hosts array (correct)"
    elif [ "$HOST_COUNT" -gt 1 ]; then
        error "Multiple hosts arrays found ($HOST_COUNT) - needs fix"
        NEEDS_HOSTS_FIX=true
    else
        warning "Unable to determine"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# STEP 4: Test Local DNS Entries
# ═══════════════════════════════════════════════════════════════
section "Testing Local DNS Entries"

ENTRIES_OK=0
ENTRIES_FAILED=0

for domain in "${!DNS_ENTRIES[@]}"; do
    expected_ip="${DNS_ENTRIES[$domain]}"
    echo -n "$domain: "
    
    # Resolve the domain
    resolved_ip=$(nslookup $domain $PIHOLE_IP 2>/dev/null | grep "Address:" | tail -1 | awk '{print $2}')
    
    if [ "$resolved_ip" = "$expected_ip" ]; then
        success "→ $expected_ip ✓"
        ((ENTRIES_OK++))
    elif [ ! -z "$resolved_ip" ]; then
        warning "→ $resolved_ip (expected $expected_ip)"
        ((ENTRIES_FAILED++))
    else
        error "Not resolving"
        ((ENTRIES_FAILED++))
    fi
done

echo ""
info "Results: $ENTRIES_OK correct, $ENTRIES_FAILED incorrect"

# ═══════════════════════════════════════════════════════════════
# STEP 5: Check Client DNS Configuration
# ═══════════════════════════════════════════════════════════════
section "Client DNS Configuration"

# Check system DNS
echo "System DNS servers:"
if [ -f /etc/resolv.conf ]; then
    grep "nameserver" /etc/resolv.conf | while read -r line; do
        info "$line"
    done
fi

# Check NetworkManager DNS (if applicable)
echo ""
echo "NetworkManager DNS (if configured):"
if command -v nmcli &>/dev/null; then
    DEFAULT_CONN=$(nmcli -t -f NAME connection show --active | head -1)
    if [ ! -z "$DEFAULT_CONN" ]; then
        DNS_SERVERS=$(nmcli connection show "$DEFAULT_CONN" | grep "ipv4.dns:" | awk '{print $2}')
        if [ ! -z "$DNS_SERVERS" ]; then
            info "Connection: $DEFAULT_CONN"
            info "DNS: $DNS_SERVERS"
        else
            warning "No DNS servers configured in NetworkManager"
        fi
    fi
fi

# ═══════════════════════════════════════════════════════════════
# STEP 6: Available Fixes
# ═══════════════════════════════════════════════════════════════
section "Available Fixes"

FIX_COUNT=0

if [ "$NEEDS_CT_START" = true ]; then
    ((FIX_COUNT++))
    echo -e "${YELLOW}$FIX_COUNT.${NC} Start Pi-hole container"
    info "Command: pct start $PIHOLE_CT"
fi

if [ "$NEEDS_FTL_RESTART" = true ]; then
    ((FIX_COUNT++))
    echo -e "${YELLOW}$FIX_COUNT.${NC} Restart Pi-hole FTL service"
    info "Command: pct exec $PIHOLE_CT -- systemctl restart pihole-FTL"
fi

if [ "$NEEDS_LISTEN_FIX" = true ]; then
    ((FIX_COUNT++))
    echo -e "${YELLOW}$FIX_COUNT.${NC} Fix Pi-hole listening mode"
    info "Change from LOCAL to ALL in /etc/pihole/pihole.toml"
fi

if [ "$NEEDS_HOSTS_FIX" = true ]; then
    ((FIX_COUNT++))
    echo -e "${YELLOW}$FIX_COUNT.${NC} Fix duplicate hosts arrays"
    info "Remove duplicate hosts arrays in /etc/pihole/pihole.toml"
fi

if [ $ENTRIES_FAILED -gt 0 ]; then
    ((FIX_COUNT++))
    echo -e "${YELLOW}$FIX_COUNT.${NC} Fix incorrect DNS entries"
    info "Update hosts array in /etc/pihole/pihole.toml"
fi

if [ $FIX_COUNT -eq 0 ]; then
    success "No fixes needed - DNS is working correctly!"
else
    echo ""
    echo -e "${BLUE}──────────────────────────────────${NC}"
    echo "Would you like to apply fixes automatically? (y/n)"
    read -r response
    
    if [[ "$response" == "y" ]]; then
        section "Applying Fixes"
        
        # Fix 1: Start container
        if [ "$NEEDS_CT_START" = true ]; then
            echo -n "Starting Pi-hole container: "
            if ssh root@$PROXMOX_NODE "pct start $PIHOLE_CT" 2>/dev/null; then
                success "Started"
                sleep 5
            else
                error "Failed to start"
            fi
        fi
        
        # Fix 2: Restart FTL
        if [ "$NEEDS_FTL_RESTART" = true ]; then
            echo -n "Restarting Pi-hole FTL: "
            if ssh root@$PROXMOX_NODE "pct exec $PIHOLE_CT -- systemctl restart pihole-FTL" 2>/dev/null; then
                success "Restarted"
                sleep 3
            else
                error "Failed to restart"
            fi
        fi
        
        # Fix 3: Fix listening mode
        if [ "$NEEDS_LISTEN_FIX" = true ]; then
            echo -n "Fixing listening mode: "
            ssh root@$PROXMOX_NODE << 'EOF' &>/dev/null
pct exec 101 -- bash -c "
    sed -i 's/listeningMode = \"LOCAL\"/listeningMode = \"ALL\"/' /etc/pihole/pihole.toml
    systemctl restart pihole-FTL
"
EOF
            if [ $? -eq 0 ]; then
                success "Fixed"
            else
                error "Failed to fix"
            fi
        fi
        
        # Fix 4: Fix duplicate hosts
        if [ "$NEEDS_HOSTS_FIX" = true ]; then
            echo -n "Fixing duplicate hosts arrays: "
            ssh root@$PROXMOX_NODE << 'EOF' &>/dev/null
pct exec 101 -- bash -c "
cat > /tmp/fix_hosts.py << 'PYEOF'
#!/usr/bin/env python3
with open('/etc/pihole/pihole.toml', 'r') as f:
    lines = f.readlines()
new_lines = []
in_hosts = False
hosts_count = 0
skip_until_bracket = False
for line in lines:
    if line.strip().startswith('hosts = ['):
        hosts_count += 1
        if hosts_count == 1:
            new_lines.append(line)
            in_hosts = True
        else:
            skip_until_bracket = True
    elif skip_until_bracket:
        if line.strip() == ']':
            skip_until_bracket = False
    elif in_hosts and line.strip() == ']':
        new_lines.append(line)
        in_hosts = False
    else:
        new_lines.append(line)
with open('/etc/pihole/pihole.toml', 'w') as f:
    f.writelines(new_lines)
PYEOF
python3 /tmp/fix_hosts.py
systemctl restart pihole-FTL
"
EOF
            if [ $? -eq 0 ]; then
                success "Fixed"
            else
                error "Failed to fix"
            fi
        fi
        
        # Fix 5: Update DNS entries
        if [ $ENTRIES_FAILED -gt 0 ]; then
            echo -n "Updating DNS entries: "
            
            # Build the hosts array string
            HOSTS_ARRAY="hosts = [\n"
            for domain in "${!DNS_ENTRIES[@]}"; do
                ip="${DNS_ENTRIES[$domain]}"
                HOSTS_ARRAY="$HOSTS_ARRAY    \"$ip $domain\",\n"
            done
            HOSTS_ARRAY="$HOSTS_ARRAY  ]"
            
            # Update Pi-hole configuration
            ssh root@$PROXMOX_NODE << EOF &>/dev/null
pct exec 101 -- bash -c "
# Backup current config
cp /etc/pihole/pihole.toml /etc/pihole/pihole.toml.bak

# Update hosts array
sed -i '/hosts = \[/,/\]/d' /etc/pihole/pihole.toml
echo -e '$HOSTS_ARRAY' >> /etc/pihole/pihole.toml

# Restart Pi-hole
systemctl restart pihole-FTL
"
EOF
            if [ $? -eq 0 ]; then
                success "Updated"
            else
                error "Failed to update"
            fi
        fi
        
        # Verify fixes
        section "Verifying Fixes"
        
        echo -n "Testing DNS resolution: "
        if nslookup google.com $PIHOLE_IP &>/dev/null; then
            success "Working!"
        else
            error "Still having issues"
        fi
        
        echo -n "Testing local domain: "
        if nslookup pihole.homelab.local $PIHOLE_IP &>/dev/null; then
            success "Working!"
        else
            error "Still having issues"
        fi
    else
        info "Manual fixes required. See recommendations above."
    fi
fi

# ═══════════════════════════════════════════════════════════════
# STEP 7: Additional Recommendations
# ═══════════════════════════════════════════════════════════════
section "Recommendations"

if [ "$PIHOLE_OK" = false ]; then
    warning "Configure dual DNS for redundancy:"
    info "nmcli connection modify \"Wired connection 1\" ipv4.dns \"$PIHOLE_IP,$OPNSENSE_IP\""
fi

if [ $ENTRIES_FAILED -gt 0 ]; then
    warning "Some DNS entries are incorrect. Review and update /etc/pihole/pihole.toml"
fi

echo ""
if [ "$PIHOLE_OK" = true ] && [ $ENTRIES_FAILED -eq 0 ]; then
    echo -e "${GREEN}▶ DNS system is healthy!${NC}"
else
    echo -e "${YELLOW}▶ DNS system needs attention${NC}"
fi

echo ""
echo "═══════════════════════════════════════════════════════════════"
echo "DNS diagnostic completed: $(date '+%Y-%m-%d %H:%M:%S')"
echo ""

# Exit code
if [ "$PIHOLE_OK" = false ]; then
    exit 1
elif [ $ENTRIES_FAILED -gt 0 ]; then
    exit 2
else
    exit 0
fi