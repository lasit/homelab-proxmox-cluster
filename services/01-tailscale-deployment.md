# Tailscale Deployment - Remote Access Solution

## Overview
Tailscale provides secure remote access to the entire homelab without port forwarding, working perfectly with CGNAT.

## Deployment Details
- **Container Type:** LXC (Proxmox CT)
- **Container ID:** 100
- **Hostname:** tailscale
- **IP Address:** 192.168.40.10/24 (Services VLAN)
- **Tailscale IP:** 100.89.200.114
- **Resources:** 2 CPU cores, 512MB RAM, 8GB disk

## Installation Steps

### 1. Container Creation
Created Debian 12 LXC container on Proxmox with static IP on Services VLAN.

### 2. Container Configuration (Critical for VPN)
```bash
# Added to /etc/pve/lxc/100.conf on Proxmox host:
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

### 3. Tailscale Installation
```bash
# Inside container
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.noarmor.gpg | tee /usr/share/keyrings/tailscale-archive-keyring.gpg
curl -fsSL https://pkgs.tailscale.com/stable/debian/bookworm.tailscale-keyring.list | tee /etc/apt/sources.list.d/tailscale.list
apt update && apt install tailscale -y
```

### 4. Enable IP Forwarding (for subnet routing)
```bash
echo 'net.ipv4.ip_forward=1' >> /etc/sysctl.conf
sysctl -p
```

### 5. Configure Subnet Routes
```bash
tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24,10.1.1.0/24 --accept-routes
```

### 6. Admin Panel Configuration
- Enabled subnet routes in https://login.tailscale.com/admin/machines
- Routes: Management, Services, and Home networks

## Access Examples
From any device with Tailscale:
- Proxmox: https://192.168.10.11:8006
- Home Assistant: http://10.1.1.63:8123
- OPNsense: https://192.168.10.1
- Pi-hole: http://192.168.40.53/admin

## Troubleshooting
- If tailscaled won't start: Check TUN/TAP device configuration
- If routes don't work: Verify IP forwarding is enabled
- Container must have TUN/TAP access for VPN functionality
