# 🌐 Network Architecture Design

**Last Updated:** October 25, 2025  
**Status:** Fully Implemented and Operational

## Overview

The homelab uses a segmented network design with VLANs for security and performance isolation. OPNsense provides routing between VLANs while keeping cluster traffic isolated.

## Network Topology

```
                        INTERNET (NBN)
                             |
                    ISP Router (10.1.1.1)
                             |
                        Port 1 (Untagged)
                             |
                      UniFi Switch Lite
                             |
                    Port 1 (Trunk to OPNsense)
                             |
                    OPNsense Router (10.1.1.91)
                    /        |         \       \
              VLAN 10    VLAN 20    VLAN 30   VLAN 40
            Management  Corosync    Storage   Services
              /  |  \    /  |  \    /  |  \    /  |  \
           pve1 pve2 pve3 pve1 pve2 pve3 pve1 pve2 pve3
```

## VLAN Design

### VLAN 10 - Management Network
- **Network:** 192.168.10.0/24
- **Gateway:** 192.168.10.1 (OPNsense)
- **Purpose:** Management access to all infrastructure
- **Routing:** Full internet access via OPNsense
- **Security:** Firewall protected, SSH access

### VLAN 20 - Corosync Cluster Network
- **Network:** 192.168.20.0/24
- **Gateway:** None (isolated)
- **Purpose:** Proxmox cluster heartbeat and communication
- **Routing:** None - isolated network
- **Security:** No external access, cluster-only traffic

### VLAN 30 - Ceph Storage Network
- **Network:** 192.168.30.0/24
- **Gateway:** None (isolated)
- **Purpose:** Ceph replication and storage traffic
- **Routing:** None - isolated network
- **Security:** No external access, storage-only traffic

### VLAN 40 - VM/Service Network
- **Network:** 192.168.40.0/24
- **Gateway:** 192.168.40.1 (OPNsense)
- **Purpose:** Virtual machines and containers
- **Routing:** Controlled access via OPNsense
- **Security:** Firewall rules per service

### Default VLAN (Untagged) - ISP Network
- **Network:** 10.1.1.0/24
- **Gateway:** 10.1.1.1 (ISP Router)
- **Purpose:** WAN connection, existing IoT devices
- **Note:** Smart home devices remain here

## IP Address Allocation

### Infrastructure Devices

| Device | VLAN 10 (Mgmt) | VLAN 20 (Corosync) | VLAN 30 (Storage) | VLAN 40 (Services) |
|--------|----------------|--------------------|--------------------|---------------------|
| OPNsense | 192.168.10.1 | 192.168.20.1* | 192.168.30.1* | 192.168.40.1 |
| pve1 | 192.168.10.11 | 192.168.20.11 | 192.168.30.11 | 192.168.40.11** |
| pve2 | 192.168.10.12 | 192.168.20.12 | 192.168.30.12 | 192.168.40.12** |
| pve3 | 192.168.10.13 | 192.168.20.13 | 192.168.30.13 | 192.168.40.13** |

*OPNsense has IPs on isolated VLANs but no routing between them  
**Node IPs on VLAN 40 reserved but not actively used (VMs get their own IPs)

### Service IP Ranges

| VLAN | Range | Purpose |
|------|-------|---------|
| VLAN 10 | .1-.10 | Infrastructure devices |
| VLAN 10 | .11-.20 | Proxmox nodes |
| VLAN 10 | .21-.30 | Management VMs |
| VLAN 10 | .31-.254 | Future expansion |
| VLAN 40 | .1-.10 | Gateways and infrastructure |
| VLAN 40 | .11-.20 | Reserved for nodes |
| VLAN 40 | .21-.50 | Critical services (DNS, proxy) |
| VLAN 40 | .51-.100 | Application services |
| VLAN 40 | .101-.200 | User services |
| VLAN 40 | .201-.254 | Testing and development |

## Switch Configuration

### UniFi Switch Lite 16 PoE Port Assignments

| Port | Device | Configuration | VLANs |
|------|--------|---------------|--------|
| 1 | OPNsense | Trunk | Native: Default, Tagged: 10,20,30,40 |
| 2 | pve1 | Trunk | Native: Default, Tagged: 10,20,30,40 |
| 3 | Empty | - | - |
| 4 | pve2 | Trunk | Native: Default, Tagged: 10,20,30,40 |
| 5 | Empty | - | - |
| 6 | pve3 | Trunk | Native: Default, Tagged: 10,20,30,40 |
| 7-8 | Empty | - | - |
| 9 | Laptop | Access | VLAN 10 (Management) |
| 10-16 | Empty | - | Available for expansion |

### VLAN Configuration in UniFi Controller

```
Networks Created:
- Default (LAN) - Untagged
- VLAN 10 - Management
- VLAN 20 - Corosync
- VLAN 30 - Storage
- VLAN 40 - Services

Port Profiles:
- Trunk_All: Native Default, Tagged 10,20,30,40
- Mgmt_Access: VLAN 10 only
```

## Proxmox Network Configuration

### Bridge Configuration (All Nodes)

```
# /etc/network/interfaces

auto lo
iface lo inet loopback

# Physical interface - no IP
iface eno1 inet manual

# Main bridge - VLAN aware
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes

# Management VLAN
auto vmbr0.10
iface vmbr0.10 inet static
    address 192.168.10.11/24  # .12 for pve2, .13 for pve3
    gateway 192.168.10.1

# Corosync VLAN
auto vmbr0.20
iface vmbr0.20 inet static
    address 192.168.20.11/24  # .12 for pve2, .13 for pve3

# Storage VLAN
auto vmbr0.30
iface vmbr0.30 inet static
    address 192.168.30.11/24  # .12 for pve2, .13 for pve3
```

## OPNsense Configuration

### Interface Assignments

| Interface | Physical | VLAN | IP Address | Description |
|-----------|----------|------|------------|-------------|
| WAN | em0 | None | 10.1.1.91 (DHCP) | ISP Connection |
| LAN | em0_vlan10 | 10 | 192.168.10.1/24 | Management |
| OPT1 | em0_vlan20 | 20 | 192.168.20.1/24 | Corosync |
| OPT2 | em0_vlan30 | 30 | 192.168.30.1/24 | Storage |
| OPT3 | em0_vlan40 | 40 | 192.168.40.1/24 | Services |

### Firewall Rules

#### WAN Rules
- Block all inbound (default)
- Allow established connections
- Allow outbound NAT

#### LAN (VLAN 10) Rules
- Allow all to internet
- Allow to VLAN 40 (services)
- Block to VLAN 20,30 (isolated)

#### OPT1 (VLAN 20) Rules
- Block all to/from other networks
- Allow only internal VLAN 20 traffic

#### OPT2 (VLAN 30) Rules
- Block all to/from other networks
- Allow only internal VLAN 30 traffic

#### OPT3 (VLAN 40) Rules
- Allow established from VLAN 10
- Allow specific ports to internet
- Inter-service communication allowed

## Network Services

### DHCP Configuration

| VLAN | DHCP Server | Range | DNS |
|------|-------------|-------|-----|
| VLAN 10 | OPNsense | .100-.199 | 192.168.10.1 |
| VLAN 20 | None | Static only | N/A |
| VLAN 30 | None | Static only | N/A |
| VLAN 40 | OPNsense | .100-.199 | 192.168.40.1 |

### DNS Configuration

- **Primary DNS:** OPNsense (192.168.10.1 on VLAN 10, 192.168.40.1 on VLAN 40)
- **Upstream DNS:** 1.1.1.1, 8.8.8.8
- **Local Domain:** homelab.local

## Security Zones

### Zone 1: Management (High Trust)
- VLAN 10
- Full internet access
- Access to all zones
- SSH/HTTPS management

### Zone 2: Cluster (Isolated)
- VLAN 20 & 30
- No external access
- No inter-VLAN routing
- Critical infrastructure only

### Zone 3: Services (Medium Trust)
- VLAN 40
- Controlled internet access
- Firewall rules per service
- User-facing services

### Zone 4: IoT (Low Trust)
- Default VLAN (10.1.1.0/24)
- Existing smart home devices
- No migration planned
- Limited interaction with cluster

## Traffic Flow Examples

### Management Access
```
Laptop (VLAN 10) → Proxmox Web UI (192.168.10.11:8006)
Laptop (VLAN 10) → OPNsense (192.168.10.1)
```

### Internet Access for VMs
```
VM (VLAN 40) → OPNsense (192.168.40.1) → WAN → Internet
```

### Cluster Communication
```
pve1 (192.168.20.11) ↔ pve2 (192.168.20.12) [Corosync]
pve1 (192.168.30.11) ↔ pve2 (192.168.30.12) [Ceph]
```

### Service Access (Future)
```
Internet → OPNsense NAT → VLAN 40 Service
Tailscale → Subnet Route → VLAN 40 Service
```

## Performance Optimization

### MTU Configuration
- Standard 1500 MTU on all interfaces
- Jumbo frames not required for current scale

### Network Monitoring
- OPNsense traffic graphs
- Proxmox network statistics
- Future: Prometheus/Grafana

## Future Considerations

### Potential Enhancements
1. **Redundant OPNsense** - HA firewall pair
2. **Link Aggregation** - Multiple NICs per node
3. **10Gb Networking** - For storage traffic
4. **Additional VLANs** - DMZ, Guest network

### Scalability
- Current design supports up to 50 VMs/containers
- VLAN structure allows easy expansion
- IP ranges reserved for growth

---

**Note:** This network has been tested and validated. All VLANs are operational with proper isolation confirmed.
