# 🌐 Network Configuration Table

**Last Updated:** 2025-11-24  
**Status:** ✅ Operational (1 DNS issue)  
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
                            └─► VLAN 50: Neighbor (192.168.50.0/24) [ISOLATED]
```

## 🔢 VLAN Configuration

| VLAN ID | Name | Network | Gateway | DHCP Range | DNS | Purpose | Isolation |
|---------|------|---------|---------|------------|-----|---------|-----------|
| 1 | Default | 192.168.1.0/24 | 192.168.1.1 | .10-.245 | 192.168.40.53 | Physical LAN | None |
| 10 | Management | 192.168.10.0/24 | 192.168.10.1 | .100-.200 | 192.168.40.53 | Infrastructure | Partial |
| 20 | Corosync | 192.168.20.0/24 | None | None | None | Cluster heartbeat | Full |
| 30 | Storage | 192.168.30.0/24 | None | None | None | Ceph traffic | Full |
| 40 | Services | 192.168.40.0/24 | 192.168.40.1 | None | 192.168.40.53 | Containers/VMs | None |
| 50 | Neighbor | 192.168.50.0/24 | 192.168.50.1 | .100-.200 | 192.168.40.53 | Guest WiFi | Full |

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
| .53 | Pi-hole | CT101 | pihole.homelab.local | 53,80 | ✅ Running |
| .61 | n8n | CT112 | automation.homelab.local | 5678 | ✅ Running |
| .105 | Ubuntu Laptop | - | - | - | Static IP |

### IoT Network (10.1.1.0/24) - ISP Network
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

## 🔤 DNS Configuration

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
| pihole.homelab.local | 192.168.40.53 | A Record | ❌ Wrong - should be .22 |

**DNS Resolution Flow:**
1. Client queries Pi-hole (192.168.40.53)
2. Pi-hole checks local entries
3. If not found, forwards to upstream (8.8.8.8, 1.1.1.1)

## 🔀 Routing Configuration

### OPNsense Routes
| Destination | Gateway | Interface | Notes |
|-------------|---------|-----------|-------|
| 0.0.0.0/0 | 10.1.1.1 | WAN | Default route |
| 192.168.10.0/24 | * | VLAN10 | Direct |
| 192.168.20.0/24 | * | VLAN20 | Direct |
| 192.168.30.0/24 | * | VLAN30 | Direct |
| 192.168.40.0/24 | * | VLAN40 | Direct |
| 192.168.50.0/24 | * | VLAN50 | Direct |

## 🔥 Firewall Rules Matrix

| Source VLAN | Can Access | Cannot Access |
|-------------|------------|---------------|
| Management (10) | All VLANs, Internet | - |
| Corosync (20) | Own VLAN only | All others, Internet |
| Storage (30) | Own VLAN only | All others, Internet |
| Services (40) | Internet, DNS | Corosync, Storage |
| Neighbor (50) | Internet only | All internal VLANs |

### Special Rules
- All VLANs can access Pi-hole DNS (192.168.40.53:53)
- NAT enabled for Internet access from internal VLANs
- Corosync and Storage VLANs completely isolated

## 🔌 Switch Port Assignments

| Port | Device | VLAN Config | PoE | Status |
|------|--------|-------------|-----|--------|
| 1 | Empty | - | Yes | Available |
| 2 | Empty | - | Yes | Available |
| 3 | OPNsense | Trunk (ALL) | No | Active |
| 4 | Empty | - | Yes | Available |
| 5 | Empty | - | No | Available |
| 6 | Empty | - | Yes | Available |
| 7-8 | Reserved | - | Yes | Future |
| 9 | Ubuntu Laptop | Access (1) | No | Active |
| 10 | pve1 | Trunk (1,10,20,30,40) | No | Active |
| 11 | Empty | - | Yes | Available |
| 12 | pve2 | Trunk (1,10,20,30,40) | No | Active |
| 13 | Pi (IoT) | Access (1) | Yes | Active |
| 14 | pve3 | Trunk (1,10,20,30,40) | No | Active |
| 15 | Mac Pro NAS | Access (30) | No | Active |
| 16 | Empty | - | Yes | Available |

**PoE Budget:** 45W total, 5W used, 40W available

## 🌍 External Access

### Tailscale VPN Configuration
| Device | Tailscale IP | Advertised Routes | Status |
|--------|--------------|-------------------|--------|
| Gateway (CT100) | 100.89.200.114 | 192.168.10.0/24, 192.168.40.0/24, 10.1.1.0/24 | Active |
| Laptop | 100.102.3.77 | None | Active |
| Phone | 100.103.101.25 | None | Active |

### Internet Connection
- **Type:** NBN HFC (50/20 Mbps)
- **ISP Gateway:** 10.1.1.1
- **OPNsense WAN:** 10.1.1.17 (DHCP)
- **MTU:** 1500

## 📏 Network Standards & Best Practices

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
- 50-99: Guest/Isolated

## 🔧 Quick Network Diagnostics

```bash
# Test connectivity
ping -c 1 192.168.10.1    # Management gateway
ping -c 1 192.168.40.53   # Pi-hole DNS

# DNS tests
nslookup google.com 192.168.40.53
nslookup pve1.homelab.local 192.168.40.53

# Routing test
traceroute 8.8.8.8

# Check VLAN interfaces (on Proxmox)
ip addr show | grep vmbr0

# View ARP table
arp -a | grep 192.168
```

## 📝 Recent Network Changes

- **2025-11-24:** Discovered Pi-hole DNS misconfiguration
- **2025-11-16:** Switch port reorganization for PoE
- **2025-11-12:** All VLANs configured and operational

---

*This document is the single source of truth for network configuration*  
*Reference this file - do not duplicate network information elsewhere*