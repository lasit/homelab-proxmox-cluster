# OPNsense Router Setup Documentation

## Hardware
- **Router:** Protectli FW4C
- **Ports:** 4x 2.5GbE Intel NICs
- **OS:** OPNsense 25.1
- **Installation Date:** November 12, 2025

## Physical Port Mapping
- **Port 1 (igc0):** WAN - Connected to ISP Router (10.1.1.1)
- **Port 2 (igc1):** LAN - Connected to UniFi Switch Port 3 (Trunk)
- **Port 3 (igc2):** OPT1 - Not used
- **Port 4 (igc3):** OPT2 - Not used

## Network Configuration

### WAN Interface (igc0)
- **IP Address:** 10.1.1.17 (DHCP from ISP router)
- **Gateway:** 10.1.1.1
- **DNS:** ISP provided
- **Block RFC1918:** Disabled (ISP uses private network)

### LAN Interface (igc1)
- **IP Address:** 192.168.1.1/24
- **DHCP Range:** 192.168.1.10 - 192.168.1.245
- **Purpose:** Default network, UniFi switch management

### VLAN Interfaces (All on igc1 parent)

| VLAN ID | Interface Name | Network | DHCP | Purpose |
|---------|---------------|---------|------|---------|
| 10 | ManagementVLAN | 192.168.10.1/24 | 192.168.10.100-200 | Management devices |
| 20 | CorosyncVLAN | 192.168.20.1/24 | Disabled | Cluster heartbeat |
| 30 | StorageVLAN | 192.168.30.1/24 | Disabled | Ceph storage |
| 40 | VMsVLAN | 192.168.40.1/24 | Disabled | VM/Container network |
| 50 | NeighborWiFiVLAN | 192.168.50.1/24 | Disabled | Isolated neighbor network |

## Firewall Rules
- All VLAN interfaces: "Pass any" rules configured
- Inter-VLAN routing: Enabled
- WAN to LAN: Default block with NAT

## Key Configuration Notes
1. RFC1918 blocking disabled on WAN (required for ISP private network)
2. All VLANs configured on igc1 (LAN) parent interface
3. Inter-VLAN routing working between all networks
4. Management VLAN has DHCP for management devices
5. Other VLANs prepared for static IP assignments (Proxmox nodes)

## Access
- Web Interface: https://192.168.1.1 or https://192.168.10.1
- SSH: Enabled on LAN and Management VLAN
- Console: Physical serial or VGA connection

## Verified Working
- Internet connectivity from all VLANs
- Inter-VLAN routing between networks
- DHCP on LAN and Management VLAN
- Firewall rules allowing communication
