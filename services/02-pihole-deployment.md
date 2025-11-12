# Pi-hole Deployment - Network-Wide Ad Blocking

## Overview
Pi-hole provides DNS-based ad blocking for all devices on the network, improving browsing speed and privacy.

## Deployment Details
- **Container Type:** LXC (Proxmox CT)
- **Container ID:** 101
- **Hostname:** pihole
- **IP Address:** 192.168.40.53/24 (Services VLAN)
- **DNS Port:** 53 (standard DNS)
- **Web Interface:** http://192.168.40.53/admin
- **Resources:** 2 CPU cores, 512MB RAM, 8GB disk

## Installation Steps

### 1. Container Creation
Created Debian 12 LXC container with static IP 192.168.40.53 (using .53 for DNS service).

### 2. Network Configuration
Container configured with:
- Static IP: 192.168.40.53/24
- Gateway: 192.168.40.1
- DNS: 8.8.8.8 (for installation)

### 3. Pi-hole Installation
```bash
curl -sSL https://install.pi-hole.net | bash
```

Installation choices:
- Upstream DNS: Google (8.8.8.8)
- Blocklists: Default (StevenBlack)
- Web Interface: Yes
- Web Server: lighttpd
- Query Logging: Yes
- Privacy Mode: Show everything

### 4. Critical Configuration Fix
Pi-hole initially set to LOCAL listening mode. Fixed with:
```bash
sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml
systemctl restart pihole-FTL
```

### 5. Network DNS Configuration
Updated OPNsense DHCP to use Pi-hole:
- Services → DHCPv4 → [LAN]
- DNS Server: 192.168.40.53
- Applied to Management VLAN as well

## Admin Access
- URL: http://192.168.40.53/admin
- Password: Set with `pihole -a -p`

## Performance Metrics
- Typical block rate: 15-40%
- Blocklist domains: ~130,000
- Memory usage: <100MB
- CPU usage: Minimal

## Testing
```bash
# Test DNS resolution
nslookup google.com 192.168.40.53

# Test ad blocking (should return 0.0.0.0)
nslookup doubleclick.net 192.168.40.53
```

## Common Issues Resolved
1. DNS timeout: Changed listening mode from LOCAL to ALL
2. Container networking: Ensured static IP configuration
3. DHCP updates: Forced device renewal for new DNS
