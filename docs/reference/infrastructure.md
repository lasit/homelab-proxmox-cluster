# 🖥️ Infrastructure Reference

Complete hardware inventory and specifications for the homelab cluster.

Last Updated: 2025-12-05  
Status: ✅ Verified via system audit

## 📊 Hardware Inventory

### Compute Nodes

| Node | Model | CPU | RAM | Storage | IP | MAC | Status |
|------|-------|-----|-----|---------|-----|-----|--------|
| **pve1** | HP Elite Mini 800 G9 | Intel i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.11 | 2c:58:b9:f0:ad:aa | ✅ Active |
| **pve2** | HP Elite Mini 800 G9 | Intel i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.12 | 2c:58:b9:f0:35:4e | ✅ Active |
| **pve3** | HP Elite Mini 800 G9 | Intel i5-12500T (6C/12T) | 32GB DDR5 | 500GB NVMe | 192.168.10.13 | 2c:58:b9:f0:ad:65 | ✅ Active |

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

### WiFi Infrastructure

| Device | Model | Specs | IP | Location | Switch Port | Status |
|--------|-------|-------|-----|----------|-------------|--------|
| **AP-Upstairs** | UniFi U6+ | WiFi 6, 2x2 MIMO | 192.168.1.145 | Office/Upstairs | Port 1 | ✅ Active |
| **AP-Downstairs** | UniFi U6+ | WiFi 6, 2x2 MIMO | 192.168.1.146 | Downstairs | Port 2 | ✅ Active |
| **AP-Neighbor** | UniFi U6+ | WiFi 6, 2x2 MIMO | 192.168.1.147 | Neighbor Garage | Port 4 | ✅ Active |

**WiFi SSIDs:**
| SSID | VLAN | Broadcast APs | Purpose |
|------|------|---------------|---------|
| HomeNet | 40 | AP-Upstairs, AP-Downstairs | Trusted devices |
| IoT | 60 | AP-Upstairs, AP-Downstairs | Smart home devices |
| Neighbor | 50 | AP-Neighbor only | Neighbor internet access |

### Storage Systems

| System | Hardware | Capacity | Interface | Location | Purpose | Status |
|--------|----------|----------|-----------|----------|---------|--------|
| **Ceph Cluster** | 3× 500GB NVMe | 172GB usable | Internal | Distributed | VM/Container storage | ✅ Active |
| **G-Drive** | HGST 10TB USB-C | 9.1TB (8.6TB usable) | USB-C | Connected to pve1 | Backup storage | ✅ Active |

### Retired Hardware

| System | Hardware | Reason | Date Retired |
|--------|----------|--------|--------------|
| **Mac Pro NAS** | Late 2013 + Promise Pegasus R6 (9.1TB) | Overkill for backup needs, high power (~340W), complex Thunderbolt/stex driver issues | 2025-12-05 |

### Power Protection

| Device | Model | Specs | Connected To | Purpose | Status |
|--------|-------|-------|--------------|---------|--------|
| **UPS** | CyberPower CP1600EPFCLCD-AU | 1600VA/1000W | pve1 (USB) | Power protection | ✅ Active |

**UPS Load:** ~142W (~17% capacity)  
**Protected Equipment:** pve1, pve2, pve3, OPNsense, UniFi Switch, G-Drive

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
| **IoT** | 60 | 192.168.60.0/24 | 192.168.60.1 | ✅ .100-.200 | Smart devices | Partial |

### Switch Port Assignments

| Port | Device | VLAN Config | PoE | Cable | Notes | Verified |
|------|--------|-------------|-----|-------|-------|----------|
| 1 | AP-Upstairs | Trunk (All) | ✅ | Cat6 | UniFi U6+ | ✅ |
| 2 | AP-Downstairs | Trunk (All) | ✅ | Cat6 | UniFi U6+ | ✅ |
| 3 | OPNsense | Custom (10,20,30,40,50,60) | ❌ | Cat6 | Router uplink | ✅ |
| 4 | AP-Neighbor | Trunk (All) | ✅ | Cat6 | UniFi U6+ | ✅ |
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
| 15 | Empty | - | ❌ | - | Previously Mac Pro | ✅ |
| 16 | Empty | - | ✅ | - | Available | - |

**PoE Budget:** 45W total, ~35W used (3 APs + Pi), 10W available

**Critical Note:** Port 3 (OPNsense) must use **Custom** tagged VLAN selection, not "Allow All". When creating new VLANs, manually add them to Port 3's tagged list.

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
| .40 | CT107 | UniFi Controller | Network management |
| .41-.49 | Network services | Reserved | - |
| .50-.59 | Development | Reserved for future | - |
| .53 | CT101 | Pi-hole | DNS server |
| .60-.69 | Automation | n8n, Home Assistant | - |
| .61 | CT112 | n8n | Workflows |
| .70-.99 | Future expansion | - | - |

#### IoT VLAN (192.168.60.0/24)
| IP Range | Assignment | Notes |
|----------|------------|-------|
| .1 | OPNsense | Gateway |
| .100-.200 | DHCP pool | IoT devices |

## 🔌 Power Configuration

### Power Consumption

| Component | Idle (W) | Load (W) | Monthly Cost (AUD) | Notes |
|-----------|----------|----------|-------------------|-------|
| pve1 | 25 | 45 | $5.40 | TDP 35W CPU |
| pve2 | 25 | 45 | $5.40 | TDP 35W CPU |
| pve3 | 25 | 45 | $5.40 | TDP 35W CPU |
| OPNsense | 15 | 20 | $3.60 | Protectli FW4C |
| Switch | 10 | 15 | $2.16 | UniFi 16 PoE |
| APs (×3) | 30 | 40 | $6.48 | ~10-13W each |
| G-Drive | 5 | 8 | $1.08 | USB-C external |
| **Total** | **135W** | **218W** | **$29.52** | At $0.30/kWh |

*Power reduced by ~$8.64/month after retiring Mac Pro (~340W → 5W)*

### UPS Configuration

| Requirement | Specification | Actual | Notes |
|-------------|--------------|--------|-------|
| Runtime | 30 minutes minimum | ~40 min | At current load |
| Capacity | 800VA minimum | 1600VA | CyberPower CP1600EPFCLCD |
| Outlets | 6+ required | 6 battery | All critical connected |
| Monitoring | USB | ✅ NUT on pve1 | Cluster-aware shutdown |

## 📡 Remote Access

### Tailscale Configuration
| Device | Tailscale IP | Hostname | Routes | Status |
|--------|--------------|----------|---------|--------|
| Gateway | 100.89.200.114 | tailscale | 192.168.0.0/16, 10.1.1.0/24 | ✅ Active |
| Laptop | 100.102.3.77 | xavier-laptop | - | ✅ Active |
| Phone | 100.103.101.25 | samsung | - | ✅ Active |

### External Access Points
- **Tailscale Admin:** https://login.tailscale.com
- **GitHub Repo:** https://github.com/lasit/homelab-proxmox-cluster
- **No port forwarding** - All access via Tailscale VPN

## 🔧 Physical Layout

### Rack Organization
```
Current 16U Rack Configuration:

U6: [ Patch Panel / Cable Management ]
U5: [ UniFi Switch Lite 16 PoE ]
U4: [ OPNsense Router (Protectli FW4C) ]
U3: [ HP Elite Mini Shelf - pve1, pve2, pve3 ]
U2: [ CyberPower UPS ]
U1: [ G-Drive USB-C (connected to pve1) ]
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
| UniFi U6+ ×3 | Nov 2025 | Nov 2027 | 2-year warranty |
| G-Drive 10TB | Dec 2025 | Dec 2027 | 2-year warranty |

### Firmware Versions
| Device | Current Version | Last Updated | Notes |
|--------|----------------|--------------|-------|
| OPNsense | 25.1 | Nov 2025 | Latest stable |
| UniFi Switch | 7.2.123 | Nov 2025 | Latest stable |
| UniFi U6+ APs | 6.7.31 | Nov 2025 | Latest stable |
| UniFi Controller | 10.0.160 | Nov 2025 | Latest stable |
| Proxmox VE | 8.2 | Oct 2025 | Latest stable |

---

*For service-specific details, see [services.md](./services.md)*  
*For backup procedures, see [backup-recovery.md](./backup-recovery.md)*