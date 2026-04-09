# Homelab Proxmox Cluster — Claude Code Context

## Project Overview

This is Xavier's homelab infrastructure documentation and automation repository. It covers a 3-node Proxmox VE cluster in Darwin, Australia, with OPNsense routing, Ceph distributed storage, and various self-hosted services.

**Project Owner:** Xavier Espiau
**Location:** Darwin, Northern Territory, Australia
**Repository:** https://github.com/lasit/homelab-proxmox-cluster

**Project Philosophy:**
- Reliability over bleeding edge — 10-year operational horizon
- Documentation driven — everything documented for future reference
- Learn by doing — hands-on experience with enterprise tech
- Family-friendly — changes must not disrupt household services

## Communication Preferences

**DO:**
- Give step-by-step instructions with exact commands
- Explain WHY before showing HOW
- Warn about potential issues BEFORE they happen
- Provide copy-paste ready commands with explanations
- Include verification steps after each major action
- Suggest documentation updates after changes

**DON'T:**
- Give multiple commands at once without explanation
- Assume knowledge of enterprise networking concepts
- Skip verification steps
- Make changes without explaining the impact

**Response Format for Technical Tasks:**
1. **Objective:** What we're achieving
2. **Prerequisites:** What must be ready first
3. **Procedure:** Step-by-step with commands
4. **Verification:** How to confirm success
5. **Documentation:** Which files to update
6. **Next Steps:** What comes after

## How To Access The Homelab

Xavier works from either a Windows 11 laptop or Ubuntu laptop. Both connect via Tailscale VPN.

```bash
# SSH to Proxmox nodes
ssh root@192.168.10.11    # pve1 (primary)
ssh root@192.168.10.12    # pve2
ssh root@192.168.10.13    # pve3

# Access container shells (from a Proxmox node)
pct exec <CTID> -- bash

# Web interfaces
https://192.168.10.11:8006   # Proxmox pve1
https://192.168.10.12:8006   # Proxmox pve2
https://192.168.10.13:8006   # Proxmox pve3
https://192.168.10.1         # OPNsense router
https://192.168.40.40:8443   # UniFi Controller
```

---

## Infrastructure Summary

### Compute Nodes

| Node | Model | CPU | RAM | Storage | Mgmt IP | Status |
|------|-------|-----|-----|---------|---------|--------|
| **pve1** | HP Elite Mini 800 G9 | i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.11 | ✅ Active |
| **pve2** | HP Elite Mini 800 G9 | i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.12 | ✅ Active |
| **pve3** | HP Elite Mini 800 G9 | i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.13 | ✅ Active |

**Aggregate:** 18 cores / 36 threads, 96GB RAM, 1.5TB NVMe (172GB usable with Ceph 3x replication)

### Network Infrastructure

| Device | Model | IP | Purpose | Status |
|--------|-------|----|---------|--------|
| **Router** | Protectli FW4C (OPNsense 25.1) | 192.168.10.1 | Firewall/routing | ✅ Active |
| **Switch** | UniFi Switch Lite 16 PoE (45W) | 192.168.1.104 | Core switching | ✅ Active |
| **ISP Router** | NBN HFC 50/20 Mbps | 10.1.1.1 | Internet gateway (WiFi DISABLED) | ✅ Active |
| **AP-Upstairs** | UniFi U6+ | 192.168.1.143 | WiFi — Office/Upstairs | ✅ Active |
| **AP-Downstairs** | UniFi U6+ | 192.168.1.142 | WiFi — Downstairs | ✅ Active |
| **AP-Neighbor** | UniFi U6+ | 192.168.1.141 | WiFi — Neighbor Garage | ✅ Active |

### VLANs

| VLAN ID | Name | Network | Gateway | DHCP Range | Purpose | Isolation |
|---------|------|---------|---------|------------|---------|-----------|
| 1 | Default | 192.168.1.0/24 | 192.168.1.1 | .10-.245 | Physical LAN, APs, switch | None |
| 10 | Management | 192.168.10.0/24 | 192.168.10.1 | .100-.200 | Proxmox nodes, admin | Partial |
| 20 | Corosync | 192.168.20.0/24 | None | None | Cluster heartbeat | Full — no gateway |
| 30 | Storage | 192.168.30.0/24 | None | None | Ceph OSD traffic | Full — no gateway |
| 40 | Services | 192.168.40.0/24 | 192.168.40.1 | None (static) | Containers, VMs, HomeNet WiFi | None |
| 50 | Neighbor | 192.168.50.0/24 | 192.168.50.1 | .100-.200 | Neighbor internet only | Full |
| 60 | IoT | 192.168.60.0/24 | 192.168.60.1 | .100-.200 | Smart home devices | Partial |

**Critical VLAN rule:** All VLANs are TAGGED (not native) because the ISP router uplink shares the switch's default VLAN 1.

### WiFi Networks

| SSID | VLAN | Broadcast APs | Purpose |
|------|------|---------------|---------|
| HomeNet | 40 | AP-Upstairs, AP-Downstairs | Trusted devices |
| IoT | 60 | AP-Upstairs, AP-Downstairs | Smart home devices |
| iiNetBC09FB | 60 | AP-Upstairs, AP-Downstairs | Migrated ISP IoT devices (same creds as old ISP WiFi) |
| Neighbor | 50 | AP-Neighbor only | Neighbor internet access |

### Running Services

| CT ID | Service | IP | Port(s) | Hostname | Purpose | Status |
|-------|---------|-----|---------|----------|---------|--------|
| 100 | Tailscale | 192.168.40.10 | 22 | tailscale.homelab.local | VPN subnet routing | ✅ Running |
| 101 | Pi-hole | 192.168.40.53 | 53, 80 | pihole.homelab.local | DNS & ad blocking | ✅ Running |
| 102 | Nginx Proxy Manager | 192.168.40.22 | 80, 81, 443 | nginx.homelab.local | Reverse proxy | ✅ Running |
| 103 | Uptime Kuma | 192.168.40.23 | 3001 | status.homelab.local | Service monitoring | ✅ Running |
| 104 | Nextcloud | 192.168.40.31 | 80 | cloud.homelab.local | Cloud storage | ✅ Running |
| 105 | MariaDB | 192.168.40.32 | 3306 | mariadb | Database (10.11) | ✅ Running |
| 106 | Redis | 192.168.40.33 | 6379 | redis | Cache (container only, service not running) | ⚠️ |
| 107 | UniFi Controller | 192.168.40.40 | 8443, 8080 | unifi.homelab.local | Network management | ✅ Running |
| 112 | n8n | 192.168.40.61 | 5678 | automation.homelab.local | Workflow automation | ✅ Running |

**Total resources used:** 16 CPU cores, 14GB RAM, 103GB disk
**Next available CT ID:** 113+
**Next available VM ID:** 200+

### Service URLs (via Nginx Proxy Manager)

All DNS entries point to proxy IP (192.168.40.22), not individual service IPs.

```
http://pihole.homelab.local       # Pi-hole admin
http://nginx.homelab.local        # Nginx Proxy Manager (port 81)
http://status.homelab.local       # Uptime Kuma
http://cloud.homelab.local        # Nextcloud
http://automation.homelab.local   # n8n
https://192.168.40.40:8443        # UniFi Controller (direct)
```

### Storage

| System | Hardware | Capacity | Location | Purpose | Status |
|--------|----------|----------|----------|---------|--------|
| **Ceph Cluster** | 3× 500GB NVMe | 515GB raw / 172GB usable | Distributed | VM/Container storage | ✅ Active |
| **G-Drive** | HGST 10TB USB-C | 9.1TB (8.6TB usable) | pve1 USB-C | Backup storage | ✅ Active |

### Backup Configuration

| Setting | Value |
|---------|-------|
| Schedule | Daily at 02:00 |
| Storage | G-Drive on pve1 (/mnt/backup-storage/proxmox-backups/dump/) |
| Retention | 7 daily backups |
| Proxmox Storage ID | backup-gdrive |

### Power Protection

| Property | Value |
|----------|-------|
| UPS Model | CyberPower CP1600EPFCLCD-AU (1600VA/1000W) |
| Load | ~17% (~142W) |
| Runtime | ~34-45 minutes |
| NUT Master | pve1 (USB connected) |
| NUT Slaves | pve2, pve3 |
| Protected | pve1, pve2, pve3, OPNsense, UniFi Switch, G-Drive |

### IoT / Smart Home

| Device | IP | Network | Notes |
|--------|----|---------|-------|
| Fronius Solar Inverter | 192.168.40.107 | VLAN 40 (HomeNet WiFi) | Solar monitoring, web UI on port 80/443, MAC 78:C4:0E:B4:98:E4 |
| Home Assistant | 192.168.1.146 | Default VLAN (wired) | Raspberry Pi, HA OS 16.3 |
| MQTT Broker | 10.1.1.67 | ISP | Separate Pi |
| Reolink NVR + 5 cameras | 10.1.1.46 | ISP | Security cameras |
| Daikin AC units | Various | IoT VLAN | Climate control |

### Remote Access

| Machine | Tailscale IP | OS | Notes |
|---------|-------------|-----|-------|
| tailscale (CT100) | 100.89.200.114 | Linux | Subnet router |
| wuwei | 100.70.57.108 | Windows 11 | Xavier's Windows laptop |
| xavier-hp-probook-440-g10 | 100.102.3.77 | Ubuntu 24.04 | Xavier's Ubuntu laptop |

---

## Key Files

| File | Purpose | Update When |
|------|---------|-------------|
| `CURRENT_STATUS.md` | Live system state | After ANY infrastructure change |
| `QUICKSTART.md` | Essential daily reference | When procedures change |
| `infrastructure.md` | Hardware inventory | Hardware changes |
| `services.md` | Service catalog & config | Service deployments |
| `network-table.md` | Complete network reference | Network/VLAN changes |
| `commands.md` | Command reference | New procedures learned |
| `troubleshooting.md` | Problem solutions | Issues encountered |
| `lessons-learned.md` | What we've learned | After incidents |
| `design-decisions.md` | Architecture rationale | Major decisions |
| `backup-recovery.md` | Backup procedures | Backup changes |
| `ups-configuration.md` | UPS & power management | Power changes |
| `core-services.md` | Service deployment guides | Service changes |
| `storage-automation.md` | Nextcloud, n8n setup | Storage service changes |

**Scripts:**

| Script | Purpose |
|--------|---------|
| `daily-health.sh` | Morning health check — run daily |
| `verify-state.sh` | Deep system verification |
| `fix-dns.sh` | DNS troubleshooting |
| `backup-test.sh` | Backup verification |

---

## Important Constraints

### Family Impact — DO NOT DISRUPT
- **Pi-hole (CT101)** — Family depends on ad blocking, verify before changes
- **Tailscale (CT100)** — Required for Xavier's remote work access
- **WiFi networks** — Kids/partner use these, no surprise outages

### Network Safety
- Never change VLAN 10 (management) IPs without console access ready
- Never modify OPNsense firewall rules without understanding impact
- Test DNS changes before making them default
- All service DNS entries must point to proxy IP (192.168.40.22), not individual service IPs

### Hardware
- Darwin tropical climate — heat/humidity considerations
- Power costs $0.30/kWh — efficiency matters
- UPS provides ~34-45 minutes runtime at current load

### Known Technical Gotchas
- Hardware offloading on NICs can prevent Linux bridge transmission — disable with ethtool
- Redis has systemd namespace issues in unprivileged LXC containers
- DNS over Tailscale can conflict with VPN DNS leak protection (ProtonVPN)
- Use specific version tags for container deployments, not "latest"

---

## Common Tasks

### Daily Health Check
```bash
ssh root@192.168.10.11 "pvecm status && ceph -s"
```

### Check All Containers
```bash
ssh root@192.168.10.11 "pct list"
```

### Restart a Container
```bash
ssh root@192.168.10.11 "pct restart <CTID>"
```

### Check Backups
```bash
ssh root@192.168.10.11 "ls -lht /mnt/backup-storage/proxmox-backups/dump/ | head -10"
```

### UPS Status
```bash
ssh root@192.168.10.11 "upsc cyberpower@localhost | grep -E '^(ups.status|ups.load|battery.charge|battery.runtime):'"
```

### Test DNS
```bash
nslookup pihole.homelab.local 192.168.40.53
```

### Check Ceph Storage
```bash
ssh root@192.168.10.11 "ceph -s && ceph df"
```

---

## Git Workflow

```bash
cd ~/Documents/homelab-proxmox-cluster    # or wherever this repo is cloned
git add .
git commit -m "Update: Brief description"
git push
```

**Commit prefixes:**
- `Add:` — New service or feature
- `Update:` — Documentation changes
- `Fix:` — Corrections
- `Remove:` — Deletions
- `Incident:` — Post-mortem documentation

---

## Emergency Procedures

### Lost Access to Services
```bash
# Check DNS
nslookup pihole.homelab.local 192.168.40.53

# If DNS down, use direct IPs
ssh root@192.168.10.11 "pct restart 101"   # Restart Pi-hole
ssh root@192.168.10.11 "pct restart 100"   # Restart Tailscale
```

### Cluster Issues
```bash
ssh root@192.168.10.11 "pvecm status"
ssh root@192.168.10.11 "ceph -s"
```

### Power Outage Recovery
1. Wait for all systems to boot (~20 minutes)
2. Run verify-state.sh
3. Check Ceph health before using services
4. See ups-configuration.md for full procedure

---

*This file is read by Claude Code to understand the project context.*
*Update when project structure or key information changes.*
