# 🖥️ Infrastructure Reference

Complete hardware inventory and specifications for the homelab cluster.

Last Updated: 2025-11-24  
Status: ✅ Verified via system audit

## 📊 Hardware Inventory

### Compute Nodes

| Node | Model | CPU | RAM | Storage | IP | MAC | Status |
|------|-------|-----|-----|---------|-----|-----|--------|
| **pve1** | HP Elite Mini 800 G9 | Intel i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.11 | TBD | ✅ Active |
| **pve2** | HP Elite Mini 800 G9 | Intel i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.12 | TBD | ✅ Active |
| **pve3** | HP Elite Mini 800 G9 | Intel i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.13 | TBD | ✅ Active |

**Aggregate Resources:**
- Total CPU: 18 cores / 36 threads
- Total RAM: 96GB DDR5
- Total Storage: 1.5TB NVMe (172GB usable with Ceph 3x replication)

### Network Infrastructure

| Device | Model | Specs | IP | Purpose | Status |
|--------|-------|-------|-----|---------|--------|
| **Router** | Protectli FW4C | 4× 2.5GbE Intel, 8GB RAM | 192.168.10.1 | OPNsense firewall | ✅ Active |
| **Switch** | UniFi Switch Lite 16 PoE | 16 ports, 8 PoE+, 45W | 192.168.1.104 | Core switching | ✅ Active |
| **ISP Router** | NBN HFC | 50/20 Mbps | 10.1.1.1 | Internet gateway | ✅ Active |

### Storage Systems

| System | Hardware | Capacity | Interface | IP | Purpose | Status |
|--------|----------|----------|-----------|-----|---------|--------|
| **Ceph Cluster** | 3× 500GB NVMe | 172GB usable | Internal | N/A | VM/Container storage | ✅ Active |
| **Mac Pro NAS** | Late 2013 + Pegasus R6 | 9.1TB | Thunderbolt + SSHFS | 192.168.30.20 | Backup storage | ⚠️ Partial |

### Management Systems

| Device | Model | OS | IP | Purpose | Status |
|--------|-------|-----|-----|---------|--------|
| **Laptop** | HP ProBook 440 G10 | Ubuntu 24.04 | 192.168.10.101 | Management workstation | ✅ Active |

## 🌐 Network Architecture

### VLAN Configuration

| VLAN | ID | Network | Gateway | DHCP | Purpose | Isolation |
|------|----|---------|---------|------|---------|-----------|
| **Default** | 1 | 192.168.1.0/24 | 192.168.1.1 | ✅ .10-.245 | Physical LAN | No |
| **Management** | 10 | 192.168.10.0/24 | 192.168.10.1 | ✅ .100-.200 | Infrastructure | Partial |
| **Corosync** | 20 | 192.168.20.0/24 | None | ❌ | Cluster heartbeat | Full |
| **Storage** | 30 | 192.168.30.0/24 | None | ❌ | Ceph traffic | Full |
| **Services** | 40 | 192.168.40.0/24 | 192.168.40.1 | ❌ | Containers/VMs | No |
| **Neighbor** | 50 | 192.168.50.0/24 | 192.168.50.1 | ✅ .100-.200 | Guest WiFi | Full |

### Switch Port Assignments

| Port | Device | VLAN Config | PoE | Cable | Notes | Verified |
|------|--------|-------------|-----|-------|-------|----------|
| 1 | Empty | - | ✅ | - | Available for AP | - |
| 2 | Empty | - | ✅ | - | Available for AP | - |
| 3 | OPNsense | Trunk (All) | ❌ | Cat6 | Router uplink | ✅ |
| 4 | Empty | - | ✅ | - | Available for AP | - |
| 5 | Empty | - | ❌ | - | Available | - |
| 6 | Empty | - | ✅ | - | Available | - |
| 7 | Reserved | - | ✅ | - | Future use | - |
| 8 | Reserved | - | ✅ | - | Future use | - |
| 9 | Ubuntu Laptop | Default | ❌ | Cat6 | Management | ✅ |
| 10 | pve1 | Trunk (10,20,30,40) | ❌ | Cat6 | Node 1 | ✅ |
| 11 | Empty | - | ✅ | - | Available | - |
| 12 | pve2 | Trunk (10,20,30,40) | ❌ | Cat6 | Node 2 | ✅ |
| 13 | Pi (IoT) | Default | ✅ | Cat5e | Home Assistant | ✅ |
| 14 | pve3 | Trunk (10,20,30,40) | ❌ | Cat6 | Node 3 | ✅ |
| 15 | Mac Pro | Native VLAN 30 | ❌ | Cat6 | NAS storage | ✅ |
| 16 | Empty | - | ✅ | - | Available | - |

**PoE Budget:** 45W total, ~5W used (Pi only), 40W available

### IP Address Allocations

#### Management VLAN (192.168.10.0/24)
| IP Range | Assignment | Notes |
|----------|------------|-------|
| .1 | OPNsense | Router/Gateway |
| .11-.13 | Proxmox nodes | pve1, pve2, pve3 |
| .20-.29 | Infrastructure services | Reserved |
| .100-.200 | DHCP pool | Dynamic assignments |
| .101 | Ubuntu laptop | Static DHCP reservation |

#### Services VLAN (192.168.40.0/24)
| IP Range | Assignment | Service | Notes |
|----------|------------|---------|-------|
| .1 | OPNsense | Gateway | - |
| .10 | CT100 | Tailscale | VPN gateway |
| .20-.29 | Infrastructure | NPM, monitoring | - |
| .22 | CT102 | Nginx Proxy Manager | Reverse proxy |
| .23 | CT103 | Uptime Kuma | Monitoring |
| .30-.39 | Storage services | Nextcloud, databases | - |
| .31 | CT104 | Nextcloud | Cloud storage |
| .32 | CT105 | MariaDB | Database |
| .33 | CT106 | Redis | Cache (not active) |
| .40-.49 | Media services | Reserved for future | - |
| .50-.59 | Development | Reserved for future | - |
| .53 | CT101 | Pi-hole | DNS server |
| .60-.69 | Automation | n8n, Home Assistant | - |
| .61 | CT112 | n8n | Workflows |
| .70-.99 | Future expansion | - | - |

## 🔌 Power Configuration

### Power Consumption

| Component | Idle (W) | Load (W) | Monthly Cost (AUD) | Notes |
|-----------|----------|----------|-------------------|-------|
| pve1 | 25 | 45 | $5.40 | TDP 35W CPU |
| pve2 | 25 | 45 | $5.40 | TDP 35W CPU |
| pve3 | 25 | 45 | $5.40 | TDP 35W CPU |
| OPNsense | 15 | 20 | $3.60 | Protectli FW4C |
| Switch | 10 | 15 | $2.16 | UniFi 16 PoE |
| Mac Pro | 45 | 80 | $9.72 | With Pegasus array |
| **Total** | **145W** | **250W** | **$31.68** | At $0.30/kWh |

### UPS Requirements (Planned)

| Requirement | Specification | Notes |
|-------------|--------------|-------|
| Runtime | 30 minutes minimum | For graceful shutdown |
| Capacity | 600VA minimum | Based on 145W idle |
| Outlets | 6+ required | All critical infrastructure |
| Network | USB or network card | For monitoring |

## 📡 Remote Access

### Tailscale Configuration
| Device | Tailscale IP | Hostname | Routes | Status |
|--------|--------------|----------|---------|--------|
| Gateway | 100.89.200.114 | tailscale | 192.168.0.0/16, 10.1.1.0/24 | ✅ Active |
| Laptop | 100.102.3.77 | xavier-laptop | - | ✅ Active |
| Phone | 100.103.101.25 | samsung | - | ✅ Active |

### External Access Points
- **Tailscale Admin:** https://login.tailscale.com
- **GitHub Repo:** https://github.com/[username]/homelab-proxmox-darwin
- **No port forwarding** - All access via Tailscale VPN

## 🔧 Physical Layout

### Rack Organization (Future)
```
[Not yet rack-mounted - desktop deployment]

Planned 6U configuration:
U6: [ Patch Panel ]
U5: [ UniFi Switch ]
U4: [ OPNsense Router ]
U3: [ HP Elite Mini Shelf - 3 nodes ]
U2: [ UPS Unit ]
U1: [ Mac Pro NAS ]
```

### Cable Management
- **Color Coding:**
  - Blue: Management VLAN
  - Green: Storage VLAN
  - Yellow: Services VLAN
  - Red: Uplinks/Trunks
  - Black: Default VLAN

## 📋 Maintenance Records

### Hardware Warranties
| Device | Purchase Date | Warranty Expires | Notes |
|--------|--------------|------------------|-------|
| HP Elite Mini ×3 | Oct 2025 | Oct 2028 | 3-year warranty |
| Protectli FW4C | Nov 2025 | Nov 2026 | 1-year warranty |
| UniFi Switch | Oct 2025 | Oct 2026 | 1-year warranty |

### Firmware Versions
| Device | Current Version | Last Updated | Notes |
|--------|----------------|--------------|-------|
| OPNsense | 25.1 | Nov 2025 | Latest stable |
| UniFi Switch | 7.0.100 | Nov 2025 | Latest stable |
| Proxmox VE | 8.2 | Oct 2025 | Latest stable |

---

*For service-specific details, see [services.md](./services.md)*  
*For network design philosophy, see [architecture/network-design.md](../architecture/network-design.md)*