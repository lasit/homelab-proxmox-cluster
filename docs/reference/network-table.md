# 🌐 Network Configuration Table

**Last Updated:** 2025-12-03  
**Status:** ✅ Operational  
**Single Source of Truth for ALL Network Information**

## 📊 Network Overview

```
INTERNET
    │
    └─► ISP Router (10.1.1.1)
            │
            └─► OPNsense (WAN: 10.1.1.17)
                    │
                    └─► UniFi Switch (Trunk Port 3)
                            │
                            ├─► VLAN 10: Management (192.168.10.0/24)
                            ├─► VLAN 20: Corosync (192.168.20.0/24) [ISOLATED]
                            ├─► VLAN 30: Storage (192.168.30.0/24) [ISOLATED]
                            ├─► VLAN 40: Services (192.168.40.0/24)
                            ├─► VLAN 50: Neighbor (192.168.50.0/24) [ISOLATED]
                            └─► VLAN 60: IoT (192.168.60.0/24) [PARTIAL ISOLATION]
```

## 📢 VLAN Configuration

| VLAN ID | Name | Network | Gateway | DHCP Range | DNS | Purpose | Isolation |
|---------|------|---------|---------|------------|-----|---------|-----------|
| 1 | Default | 192.168.1.0/24 | 192.168.1.1 | .10-.245 | 192.168.40.53 | Physical LAN | None |
| 10 | Management | 192.168.10.0/24 | 192.168.10.1 | .100-.200 | 192.168.40.53 | Infrastructure | Partial |
| 20 | Corosync | 192.168.20.0/24 | None | None | None | Cluster heartbeat | Full |
| 30 | Storage | 192.168.30.0/24 | None | None | None | Ceph traffic | Full |
| 40 | Services | 192.168.40.0/24 | 192.168.40.1 | None | 192.168.40.53 | Containers/VMs | None |
| 50 | Neighbor | 192.168.50.0/24 | 192.168.50.1 | .100-.200 | 192.168.40.53 | Guest WiFi | Full |
| 60 | IoT | 192.168.60.0/24 | 192.168.60.1 | .100-.200 | 192.168.40.53 | Smart devices | Partial |

## 📡 WiFi Networks

| SSID | VLAN | Network | Security | Broadcast APs | Purpose |
|------|------|---------|----------|---------------|---------|
| HomeNet | 40 | 192.168.40.0/24 | WPA2 | AP-Upstairs, AP-Downstairs | Trusted devices |
| IoT | 60 | 192.168.60.0/24 | WPA2 | AP-Upstairs, AP-Downstairs | Smart home devices |
| Neighbor | 50 | 192.168.50.0/24 | WPA2 | AP-Neighbor | Neighbor internet only |

### Access Points

| Name | IP | MAC Address | Switch Port | Location | SSIDs |
|------|-----|-------------|-------------|----------|-------|
| AP-Upstairs | 192.168.1.143 | - | Port 1 | Office/Upstairs | HomeNet, IoT |
| AP-Downstairs | 192.168.1.142 | 6c:63:f8:6b:9f:e5 | Port 2 | Downstairs | HomeNet, IoT |
| AP-Neighbor | 192.168.1.141 | - | Port 4 | Neighbor Garage | Neighbor |

**Note:** AP IPs are assigned via DHCP from the default VLAN. They may change after reboot unless static DHCP reservations are configured.

## 📍 Complete IP Address Registry

### Management VLAN (192.168.10.0/24)
| IP | Device | Hostname | Type | Notes |
|----|--------|----------|------|-------|
| .1 | OPNsense | opnsense.homelab.local | Gateway | Router/Firewall |
| .11 | HP Elite Mini 1 | pve1.homelab.local | Proxmox Node | Cluster master |
| .12 | HP Elite Mini 2 | pve2.homelab.local | Proxmox Node | Cluster member |
| .13 | HP Elite Mini 3 | pve3.homelab.local | Proxmox Node | Cluster member |
| .21-29 | Reserved | - | Infrastructure | Future expansion |
| .100-200 | DHCP Pool | - | Dynamic | Management devices |
| .101 | Ubuntu Laptop | xavier-laptop | Static DHCP | Management workstation |

### Corosync VLAN (192.168.20.0/24) - ISOLATED
| IP | Device | Purpose | Notes |
|----|--------|---------|-------|
| .11 | pve1 | Cluster communication | No gateway |
| .12 | pve2 | Cluster communication | No gateway |
| .13 | pve3 | Cluster communication | No gateway |

### Storage VLAN (192.168.30.0/24) - ISOLATED
| IP | Device | Purpose | Notes |
|----|--------|---------|-------|
| .11 | pve1 | Ceph storage network | No gateway |
| .12 | pve2 | Ceph storage network | No gateway |
| .13 | pve3 | Ceph storage network | No gateway |
| .20 | Mac Pro NAS | Backup storage | SSHFS mount |

### Services VLAN (192.168.40.0/24)
| IP | Service | Container | Hostname | Port(s) | Status |
|----|---------|-----------|----------|---------|--------|
| .1 | OPNsense | - | gateway | - | Gateway |
| .10 | Tailscale | CT100 | tailscale.homelab.local | 22 | ✅ Running |
| .11 | pve1 bridge | - | - | - | Bridge only |
| .12 | pve2 bridge | - | - | - | Bridge only |
| .13 | pve3 bridge | - | - | - | Bridge only |
| .22 | Nginx Proxy Manager | CT102 | nginx.homelab.local | 80,81,443 | ✅ Running |
| .23 | Uptime Kuma | CT103 | status.homelab.local | 3001 | ✅ Running |
| .31 | Nextcloud | CT104 | cloud.homelab.local | 80 | ✅ Running |
| .32 | MariaDB | CT105 | mariadb | 3306 | ✅ Running |
| .33 | Redis | CT106 | redis | 6379 | ⚠️ Container only |
| .40 | UniFi Controller | CT107 | unifi.homelab.local | 8443,8080 | ✅ Running |
| .53 | Pi-hole | CT101 | pihole.homelab.local | 53,80 | ✅ Running |
| .61 | n8n | CT112 | automation.homelab.local | 5678 | ✅ Running |
| .100-200 | DHCP Pool | - | - | - | HomeNet WiFi clients |

### Neighbor VLAN (192.168.50.0/24) - ISOLATED
| IP | Device | Purpose | Notes |
|----|--------|---------|-------|
| .1 | OPNsense | Gateway | Internet only |
| .100-.200 | DHCP Pool | Neighbor WiFi clients | No internal access |

### IoT VLAN (192.168.60.0/24) - PARTIAL ISOLATION
| IP | Device | Purpose | Notes |
|----|--------|---------|-------|
| .1 | OPNsense | Gateway | Internet + DNS only |
| .100-.200 | DHCP Pool | IoT WiFi clients | DNS to Pi-hole, internet allowed |

### Legacy IoT Network (10.1.1.0/24) - ISP Network
| IP | Device | Purpose | Integration |
|----|--------|---------|-------------|
| .1 | ISP Router | Gateway | NBN HFC |
| .12 | ESP-01 | Shed alert | MQTT |
| .15 | Roller Door | Garage control | Home Assistant |
| .17 | OPNsense WAN | Router WAN interface | - |
| .20 | Daikin AC | Living room climate | Home Assistant |
| .46 | Reolink Cameras | Security | Home Assistant |
| .60 | Xiaomi Gateway | Zigbee hub | Home Assistant |
| .63 | pi-front-door | Home Assistant server | Main instance |
| .67 | mqtt-broker | MQTT broker | Port 1883 |
| .114 | ESP-02 | Shed alert | MQTT |
| .174 | Fronius Inverter | Solar monitoring | Web interface |
| .211 | Daikin AC | Bedroom climate | Home Assistant |

## 📤 DNS Configuration

### Pi-hole Local DNS Entries
Current configuration in `/etc/pihole/pihole.toml`:

| Hostname | IP Address | Type | Status |
|----------|------------|------|--------|
| opnsense.homelab.local | 192.168.10.1 | A Record | ✅ Correct |
| pve1.homelab.local | 192.168.10.11 | A Record | ✅ Correct |
| pve2.homelab.local | 192.168.10.12 | A Record | ✅ Correct |
| pve3.homelab.local | 192.168.10.13 | A Record | ✅ Correct |
| tailscale.homelab.local | 192.168.40.10 | A Record | ✅ Correct |
| nginx.homelab.local | 192.168.40.22 | A Record | ✅ Correct |
| status.homelab.local | 192.168.40.22 | A Record | ✅ Correct |
| cloud.homelab.local | 192.168.40.22 | A Record | ✅ Correct |
| automation.homelab.local | 192.168.40.22 | A Record | ✅ Correct |
| pihole.homelab.local | 192.168.40.22 | A Record | ✅ Correct |
| unifi.homelab.local | 192.168.40.40 | A Record | ✅ Correct |

**DNS Resolution Flow:**
1. Client queries Pi-hole (192.168.40.53)
2. Pi-hole checks local entries
3. If not found, forwards to upstream (8.8.8.8, 1.1.1.1)

### Tailscale DNS Configuration
Configured at https://login.tailscale.com/admin/dns

| Setting | Value | Purpose |
|---------|-------|---------|
| Global Nameserver | 192.168.40.53 | Pi-hole for all Tailscale clients |
| Search Domain | homelab.local | Allows short names (e.g., `status` instead of `status.homelab.local`) |
| Override DNS servers | ✅ Enabled | Forces Tailscale clients to use Pi-hole |

## 📀 Routing Configuration

### OPNsense Gateways (System → Gateways → Configuration)
| Name | Interface | IP Address | Monitor | Description |
|------|-----------|------------|---------|-------------|
| WAN_GW | WAN | 10.1.1.1 | Yes | Internet gateway (ISP) |
| Tailscale_GW | VMsVLAN (opt4) | 192.168.40.10 | No | Tailscale subnet router |

### OPNsense Static Routes (System → Routes → Configuration)
| Destination | Gateway | Description |
|-------------|---------|-------------|
| 100.64.0.0/10 | Tailscale_GW | Tailscale CGNAT return traffic |

**Why this route is needed:** When Tailscale clients (100.x.x.x IPs) connect to homelab services, the services respond to the Tailscale IP. Without this route, OPNsense doesn't know how to reach 100.64.0.0/10 and drops the response packets. This route tells OPNsense to send all Tailscale-bound traffic through the Tailscale container (CT100).

### Default Routes
| Destination | Gateway | Interface | Notes |
|-------------|---------|-----------|-------|
| 0.0.0.0/0 | 10.1.1.1 | WAN | Default route |
| 192.168.10.0/24 | * | VLAN10 | Direct |
| 192.168.20.0/24 | * | VLAN20 | Direct |
| 192.168.30.0/24 | * | VLAN30 | Direct |
| 192.168.40.0/24 | * | VLAN40 | Direct |
| 192.168.50.0/24 | * | VLAN50 | Direct |
| 192.168.60.0/24 | * | VLAN60 | Direct |

## 🔥 Firewall Rules Matrix

| Source VLAN | Can Access | Cannot Access |
|-------------|------------|---------------|
| Management (10) | All VLANs, Internet | - |
| Corosync (20) | Own VLAN only | All others, Internet |
| Storage (30) | Own VLAN only | All others, Internet |
| Services (40) | Internet, DNS | Corosync, Storage |
| Neighbor (50) | Internet only | All internal VLANs |
| IoT (60) | Internet, Pi-hole DNS only | All internal VLANs |

### IoT VLAN Firewall Rules (Firewall → Rules → IoT)
| Order | Action | Protocol | Source | Destination | Port | Description |
|-------|--------|----------|--------|-------------|------|-------------|
| 1 | Pass | TCP/UDP | IoT net | 192.168.40.53/32 | 53 | Allow DNS to Pi-hole |
| 2 | Block | Any | IoT net | 192.168.0.0/16 | * | Block access to internal networks |
| 3 | Pass | Any | IoT net | Any | * | Allow internet access |

**Rule order is critical** - DNS must be allowed before the block rule.

### Special Rules
- All VLANs can access Pi-hole DNS (192.168.40.53:53)
- NAT enabled for Internet access from internal VLANs
- Corosync and Storage VLANs completely isolated
- IoT VLAN can only reach Pi-hole on port 53, blocked from all other internal

## 📌 Switch Port Assignments

| Port | Device | VLAN Config | PoE | Status |
|------|--------|-------------|-----|--------|
| 1 | AP-Upstairs | Trunk (All) | Yes | ✅ Active |
| 2 | AP-Downstairs | Trunk (All) | Yes | ✅ Active |
| 3 | OPNsense | Custom (10,20,30,40,50,60) | No | ✅ Active |
| 4 | AP-Neighbor | Trunk (All) | Yes | ✅ Active |
| 5 | Empty | - | No | Available |
| 6 | Empty | - | Yes | Available |
| 7-8 | Reserved | - | Yes | Future |
| 9 | Ubuntu Laptop | Access (1) | No | ✅ Active |
| 10 | pve1 | Trunk (1,10,20,30,40) | No | ✅ Active |
| 11 | Empty | - | Yes | Available |
| 12 | pve2 | Trunk (1,10,20,30,40) | No | ✅ Active |
| 13 | Pi (IoT) | Access (1) | Yes | ✅ Active |
| 14 | pve3 | Trunk (1,10,20,30,40) | No | ✅ Active |
| 15 | Mac Pro NAS | Access (30) | No | ✅ Active |
| 16 | Empty | - | Yes | Available |

**PoE Budget:** 45W total, ~35W used (3 APs + Pi), 10W available

**Critical Note:** Port 3 (OPNsense) must use **Custom** tagged VLAN selection, not "Allow All". When creating new VLANs, manually add them to Port 3's tagged list and restart the switch.

## 🌐 External Access

### Tailscale VPN Configuration
| Device | Tailscale IP | Advertised Routes | Status |
|--------|--------------|-------------------|--------|
| Gateway (CT100) | 100.89.200.114 | 192.168.10.0/24, 192.168.40.0/24, 10.1.1.0/24 | ✅ Active |
| Laptop | 100.70.57.108 | None | ✅ Active |
| Phone | 100.103.101.25 | None | ✅ Active |

### Internet Connection
- **Type:** NBN HFC (50/20 Mbps)
- **ISP Gateway:** 10.1.1.1
- **OPNsense WAN:** 10.1.1.17 (DHCP)
- **MTU:** 1500

## 📐 Network Standards & Best Practices

### IP Assignment Guidelines
- .1-.9: Infrastructure (routers, gateways)
- .10-.19: Core servers and nodes
- .20-.99: Services and applications
- .100-.200: DHCP ranges
- .201-.254: Reserved for future use

### VLAN Numbering
- 10-19: Infrastructure
- 20-29: Cluster-specific
- 30-39: Storage
- 40-49: Services
- 50-59: Guest/Isolated
- 60-69: IoT

## 🔧 Quick Network Diagnostics

```bash
# Test connectivity
ping -c 1 192.168.10.1    # Management gateway
ping -c 1 192.168.40.53   # Pi-hole DNS
ping -c 1 192.168.60.1    # IoT gateway

# DNS tests
nslookup google.com 192.168.40.53
nslookup pve1.homelab.local 192.168.40.53

# Routing test
traceroute 8.8.8.8

# Check VLAN interfaces (on Proxmox)
ip addr show | grep vmbr0

# View ARP table
arp -a | grep 192.168

# Check switch VLAN config (SSH to switch)
ssh tao.wuwei@192.168.1.104
swctrl vlan show id 3  # Verify OPNsense port has all VLANs

# Check AP ebtables (if VLAN issues)
ssh tao.wuwei@192.168.1.145
ebtables -t broute -L

# Verify Tailscale route on OPNsense
# System → Routes → Configuration should show 100.64.0.0/10 → Tailscale_GW
```

## 📝 Recent Network Changes

- **2025-12-03:** Fixed HomeNet SSID broadcasting (was only AP-Downstairs, now both APs)
- **2025-12-03:** Updated AP IP addresses in documentation (DHCP assigned)
- **2025-12-03:** Added Tailscale static route (100.64.0.0/10 → Tailscale_GW)
- **2025-12-03:** Configured Tailscale DNS (Pi-hole + homelab.local search domain)
- **2025-11-28:** Deployed UniFi WiFi infrastructure (3 APs, 3 SSIDs)
- **2025-11-28:** Created VLAN 60 (IoT) with isolation firewall rules
- **2025-11-28:** Fixed Port 3 to use Custom VLAN selection (not "Allow All")
- **2025-11-28:** Upgraded UniFi Controller to 10.0.160
- **2025-11-25:** Fixed Pi-hole DNS entries
- **2025-11-24:** Discovered Pi-hole DNS misconfiguration
- **2025-11-16:** Switch port reorganization for PoE
- **2025-11-12:** All VLANs configured and operational

## ⚠️ Known Issues & Workarounds

### ProtonVPN Blocks Tailscale DNS
- **Issue:** ProtonVPN's DNS leak protection intercepts all DNS queries
- **Symptom:** .homelab.local domains don't resolve when ProtonVPN is connected
- **Workaround:** Disconnect ProtonVPN when accessing homelab remotely
- **Alternative:** Configure ProtonVPN split tunneling to exclude Tailscale

### UniFi SSID Not Visible on Some APs (RESOLVED 2025-12-03)
- **Issue:** SSID configured but not broadcasting from all expected APs
- **Symptom:** WiFi network visible in one location but not another
- **Cause:** SSID "Broadcasting APs" set to "Specific" with only some APs selected
- **Fix:** 
  1. UniFi Controller → Settings → WiFi → [SSID Name]
  2. Check "Broadcasting APs" section
  3. Change to "All" or select all intended APs under "Specific"
  4. Save and wait 30-60 seconds for provisioning

### UniFi AP ebtables DROP rules
- **Issue:** APs may add ebtables rules that block VLAN traffic
- **Symptom:** WiFi connects but no DHCP/connectivity
- **Fix:** SSH to AP and run `ebtables -t broute -F`
- **Note:** Rules may return after AP restart

### Switch "Allow All" doesn't include new VLANs
- **Issue:** Creating a new VLAN doesn't automatically add it to ports set to "Allow All"
- **Workaround:** Use Custom selection for Port 3 (OPNsense) and manually add all VLANs
- **Verify:** SSH to switch and run `swctrl vlan show id 3`

---

*This document is the single source of truth for network configuration*  
*Reference this file - do not duplicate network information elsewhere*