# 🚀 Core Services Deployment Guide

**Last Updated:** 2025-11-25  
**Services Covered:** Tailscale, Pi-hole, Nginx Proxy Manager  
**Purpose:** Step-by-step deployment procedures for foundational homelab services

## 📚 Table of Contents

1. [Overview](#overview)
2. [Tailscale (CT100) - Remote Access](#tailscale-ct100---remote-access)
3. [Pi-hole (CT101) - DNS & Ad-blocking](#pi-hole-ct101---dns--ad-blocking)
4. [Nginx Proxy Manager (CT102) - Reverse Proxy](#nginx-proxy-manager-ct102---reverse-proxy)
5. [Post-Deployment Verification](#post-deployment-verification)
6. [Troubleshooting](#troubleshooting)
7. [Lessons Learned](#lessons-learned)

---

## Overview

These three services form the foundation of the homelab infrastructure:

| Service | Container | IP Address | Purpose | Priority |
|---------|-----------|------------|---------|----------|
| **Tailscale** | CT100 | 192.168.40.10 | Secure remote access without port forwarding | Critical |
| **Pi-hole** | CT101 | 192.168.40.53 | Network-wide DNS and ad-blocking | Critical |
| **Nginx Proxy Manager** | CT102 | 192.168.40.22 | Reverse proxy for clean URLs | High |

**Deployment Order:** Tailscale → Pi-hole → Nginx Proxy Manager

**Total Deployment Time:** ~2 hours

---

## Tailscale (CT100) - Remote Access

### Purpose
Provides secure remote access to the entire homelab without port forwarding, works perfectly with CGNAT.

### Container Creation

```bash
# On Proxmox host (pve1)
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname tailscale \
  --cores 2 \
  --memory 512 \
  --swap 512 \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1

# Set static IP
pct set 100 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.10/24,gw=192.168.40.1

# CRITICAL: Add TUN/TAP device access for VPN functionality
cat >> /etc/pve/lxc/100.conf << EOF
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
EOF

# Start container
pct start 100
```

### Tailscale Installation

```bash
# Enter container
pct enter 100

# Update system
apt update && apt upgrade -y

# Install Tailscale
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | \
  tee /usr/share/keyrings/tailscale-archive-keyring.gpg

curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | \
  tee /etc/apt/sources.list.d/tailscale.list

apt update && apt install tailscale -y

# Enable IP forwarding for subnet routing
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p
```

### Configure Tailscale

```bash
# Authenticate and advertise subnet routes
tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24,10.1.1.0/24 --accept-routes

# This will provide a URL to authenticate
# Open the URL in browser and log in
```

### Enable Subnet Routes (Admin Panel)

1. Go to https://login.tailscale.com/admin/machines
2. Find your tailscale container
3. Click the three dots → Edit route settings
4. Enable all subnet routes
5. Save

### Verification

```bash
# Check Tailscale status
tailscale status

# Should show:
# - Container online
# - Subnet routes advertised
# - Tailscale IP (100.89.200.114)

# Exit container
exit
```

### Key Issues Encountered

**Issue:** tailscaled won't start  
**Solution:** Added TUN/TAP device configuration to container config

**Issue:** Subnet routes not working  
**Solution:** Enabled IP forwarding and approved routes in admin panel

---

## Pi-hole (CT101) - DNS & Ad-blocking

### Purpose
Provides network-wide ad blocking and local DNS resolution for homelab services.

### Container Creation

```bash
# On Proxmox host
pct create 101 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname pihole \
  --cores 2 \
  --memory 512 \
  --swap 512 \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1

# Set static IP (.53 for DNS port 53)
pct set 101 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.53/24,gw=192.168.40.1

# Start container
pct start 101
```

### Pi-hole Installation

```bash
# Enter container
pct enter 101

# Update system
apt update && apt upgrade -y

# Install Pi-hole (automatic method)
curl -sSL https://install.pi-hole.net | bash
```

**Installation choices:**
- Upstream DNS: Google (8.8.8.8, 8.8.4.4)
- Blocklists: Default (StevenBlack's list)
- Web Interface: Yes
- Web Server: lighttpd
- Query Logging: Yes
- Privacy Mode: Show everything

### Critical Configuration Fix

Pi-hole defaults to LOCAL listening mode which blocks network access:

```bash
# Fix listening mode
sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml

# Restart Pi-hole
systemctl restart pihole-FTL
```

### Set Admin Password

```bash
# Set web interface password
pihole -a -p
# Enter your secure password
```

### Configure Local DNS Entries

```bash
# Edit Pi-hole configuration
nano /etc/pihole/pihole.toml

# Find the hosts array section and add:
hosts = [
  # Infrastructure (Direct Access)
  "192.168.10.1 opnsense.homelab.local",
  "192.168.10.11 pve1.homelab.local",
  "192.168.10.12 pve2.homelab.local",
  "192.168.10.13 pve3.homelab.local",
  "192.168.40.10 tailscale.homelab.local",
  
  # Services (Via Proxy - will be 192.168.40.22 after NPM setup)
  "192.168.40.53 pihole.homelab.local"  # Temporary, will change to .22
]

# Save and restart
systemctl restart pihole-FTL

# Exit container
exit
```

### Configure OPNsense DHCP

In OPNsense web interface:
1. Services → DHCPv4 → [LAN]
2. DNS Server: 192.168.40.53
3. Save and Apply
4. Repeat for Management VLAN

### Verification

```bash
# Test DNS resolution
nslookup google.com 192.168.40.53

# Test ad blocking (should return 0.0.0.0)
nslookup doubleclick.net 192.168.40.53

# Access web interface
# http://192.168.40.53/admin
```

### Key Issues Encountered

**Issue:** DNS queries timeout  
**Solution:** Changed listening mode from LOCAL to ALL

**Issue:** Can't access web interface  
**Solution:** Ensure static IP is configured correctly and firewall allows access

---

## Nginx Proxy Manager (CT102) - Reverse Proxy

### Purpose
Provides centralized reverse proxy with SSL certificate management for all web services.

### Container Creation

```bash
# On Proxmox host
pct create 102 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname nginx \
  --cores 2 \
  --memory 2048 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:8 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1 \
  --features nesting=1

# Set static IP
pct set 102 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.22/24,gw=192.168.40.1

# CRITICAL: Enable Docker in LXC
cat >> /etc/pve/lxc/102.conf << EOF
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
EOF

# Start container
pct start 102
```

### System Preparation

```bash
# Enter container
pct enter 102

# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y curl sudo gnupg ca-certificates

# Install Docker
curl -fsSL https://get.docker.com | sh

# Enable and start Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
apt install -y docker-compose-plugin

# Verify Docker
docker --version
docker compose version
```

### Deploy Nginx Proxy Manager

```bash
# Create directory
mkdir -p /opt/nginx-proxy-manager
cd /opt/nginx-proxy-manager

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  app:
    image: 'jc21/nginx-proxy-manager:latest'
    restart: unless-stopped
    ports:
      - '80:80'
      - '81:81'
      - '443:443'
    volumes:
      - ./data:/data
      - ./letsencrypt:/etc/letsencrypt
    environment:
      DB_SQLITE_FILE: "/data/database.sqlite"
EOF

# Start NPM
docker compose up -d

# Check status
docker compose ps
# Should show container running

# View logs if needed
docker compose logs -f
```

### Initial Configuration

1. Access NPM at http://192.168.40.22:81
2. Default login:
   - Email: admin@example.com
   - Password: changeme
3. Change admin credentials immediately
4. Set your email and new password

### Update Pi-hole DNS Entry

Now that NPM is running, update Pi-hole to point to proxy:

```bash
# Enter Pi-hole container
pct enter 101

# Edit Pi-hole configuration
nano /etc/pihole/pihole.toml

# Update the hosts array to include NPM entries:
hosts = [
  # Infrastructure (Direct Access)
  "192.168.10.1 opnsense.homelab.local",
  "192.168.10.11 pve1.homelab.local",
  "192.168.10.12 pve2.homelab.local",
  "192.168.10.13 pve3.homelab.local",
  "192.168.40.10 tailscale.homelab.local",
  
  # Services (Via Proxy)
  "192.168.40.22 nginx.homelab.local",
  "192.168.40.22 pihole.homelab.local"  # Changed from .53 to .22
]

# Restart Pi-hole
systemctl restart pihole-FTL

# Exit
exit
```

### Configure Proxy Hosts

In NPM web interface (http://192.168.40.22:81):

#### 1. Pi-hole Admin Panel

**Add Proxy Host:**
- Domain Names: `pihole.homelab.local`
- Scheme: `http`
- Forward Hostname/IP: `192.168.40.53`
- Forward Port: `80`
- Cache Assets: ✓
- Block Common Exploits: ✓
- Websockets Support: ✓

**Pi-hole Configuration Update:**
```bash
pct enter 101
nano /etc/pihole/pihole.toml

# Find and update:
[webserver]
  domain = "pihole.homelab.local"  # Changed from "pi.hole"

systemctl restart pihole-FTL
exit
```

#### 2. Nginx Proxy Manager (Self)

**Add Proxy Host:**
- Domain Names: `nginx.homelab.local`
- Scheme: `http`
- Forward Hostname/IP: `192.168.40.22`
- Forward Port: `81`
- Cache Assets: ✓
- Block Common Exploits: ✓
- Websockets Support: ✓

### Verification

```bash
# Test DNS resolution
nslookup nginx.homelab.local 192.168.40.53
nslookup pihole.homelab.local 192.168.40.53
# Both should return 192.168.40.22

# Test proxy access
curl -I http://nginx.homelab.local
curl -I http://pihole.homelab.local

# Access via browser
# http://nginx.homelab.local - NPM admin
# http://pihole.homelab.local - Pi-hole admin
```

### Key Issues Encountered

**Issue:** Docker won't start in LXC  
**Solution:** Added AppArmor and cgroup configuration to container

**Issue:** 403 Forbidden on proxied services  
**Solution:** Services need domain configuration to match proxy hostname

---

## Post-Deployment Verification

### Complete Service Test

```bash
# From your Ubuntu laptop

# 1. Test DNS resolution for all services
for domain in pihole nginx opnsense pve1; do
  echo -n "$domain.homelab.local: "
  nslookup $domain.homelab.local 192.168.40.53 | grep "Address:" | tail -1
done

# 2. Test HTTP access
for service in pihole nginx; do
  echo -n "Testing $service.homelab.local: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://$service.homelab.local"
done

# 3. Test Tailscale connectivity
tailscale status
ping 100.89.200.114

# 4. Test ad blocking
nslookup doubleclick.net 192.168.40.53
# Should return 0.0.0.0
```

### Expected Results

| Test | Expected Result | Status |
|------|----------------|--------|
| DNS Resolution | All .homelab.local resolve | ✓ |
| Pi-hole Web | HTTP 308 (redirect to /admin) | ✓ |
| NPM Web | HTTP 200 | ✓ |
| Tailscale | Connected, routes active | ✓ |
| Ad Blocking | ~25% queries blocked | ✓ |

---

## Troubleshooting

### Common Issues and Solutions

#### Tailscale Won't Start
```bash
# Check TUN device
ls -la /dev/net/tun

# If missing, add to container config:
echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> /etc/pve/lxc/100.conf
pct reboot 100
```

#### Pi-hole Not Blocking Ads
```bash
# Check listening mode
pct exec 101 -- grep listeningMode /etc/pihole/pihole.toml
# Should show: listeningMode = "ALL"

# Check if Pi-hole is set as DNS
pct exec 101 -- pihole status
```

#### NPM 502 Bad Gateway
```bash
# Check if backend service is running
pct exec 102 -- docker compose ps

# Check proxy host configuration
# Ensure Forward Hostname/IP is correct
# Verify port numbers match service
```

#### Services Not Accessible via Domain Names
```bash
# Check DNS resolution
nslookup service.homelab.local 192.168.40.53

# Should return 192.168.40.22 for proxied services
# Should return actual IP for direct services (opnsense, pve nodes)
```

---

## Lessons Learned

### Critical Insights

1. **Container Permissions Matter**
   - Tailscale needs TUN/TAP device access
   - Docker in LXC requires AppArmor configuration
   - Unprivileged containers have limitations

2. **DNS Architecture is Key**
   - All proxied services must resolve to proxy IP (192.168.40.22)
   - Direct services (Proxmox, OPNsense) keep their actual IPs
   - Document DNS strategy clearly

3. **Service Order Matters**
   - Deploy Tailscale first for remote access during setup
   - Pi-hole before NPM for DNS resolution
   - NPM last to proxy existing services

4. **Default Configurations Need Adjustment**
   - Pi-hole defaults to LOCAL listening (must change to ALL)
   - Services need domain configuration for proxy
   - Always change default passwords immediately

5. **Testing is Critical**
   - Test each service before moving to next
   - Verify DNS resolution at each step
   - Document working configurations immediately

### Best Practices Established

1. **Use Static IPs**
   - Predictable addressing
   - Easier troubleshooting
   - Better documentation

2. **Enable Auto-Start**
   - Set `onboot: 1` for all containers
   - Use `restart: unless-stopped` for Docker
   - Services recover from host reboots

3. **Document Everything**
   - Container IDs and IPs
   - Configuration changes
   - Passwords (in password manager)
   - Issues and solutions

4. **Backup Early and Often**
   - Before major changes
   - After successful configuration
   - Test restore procedures

---

## Quick Recovery Procedures

### If Tailscale Fails
```bash
# Restart service
pct exec 100 -- systemctl restart tailscaled

# Re-authenticate if needed
pct exec 100 -- tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24,10.1.1.0/24

# Check status
pct exec 100 -- tailscale status
```

### If Pi-hole Fails
```bash
# Restart service
pct exec 101 -- systemctl restart pihole-FTL

# Check status
pct exec 101 -- pihole status

# Emergency DNS bypass
# On laptop: sudo nmcli connection modify "Wired connection 1" ipv4.dns "192.168.10.1"
```

### If NPM Fails
```bash
# Restart Docker containers
pct exec 102 -- bash -c "cd /opt/nginx-proxy-manager && docker compose restart"

# Check logs
pct exec 102 -- bash -c "cd /opt/nginx-proxy-manager && docker compose logs --tail 50"

# Services still accessible via direct IP if proxy down
```

---

## Summary

These three core services provide:
- **Tailscale:** Secure remote access from anywhere
- **Pi-hole:** Network-wide ad blocking and local DNS
- **Nginx Proxy Manager:** Clean URLs and centralized web access

Total resources used:
- CPU: 6 cores allocated
- RAM: 3GB allocated
- Storage: 24GB allocated
- Actual usage: <10% CPU, <1GB RAM

All services configured for high availability with auto-start and proper monitoring.

---

**Next:** Deploy storage and automation services (Nextcloud, MariaDB, n8n)