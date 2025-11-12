# UniFi Switch Configuration

## Hardware
- **Model:** UniFi Switch Lite 16 PoE
- **Ports:** 16x 1GbE (8x PoE+)
- **Controller:** UniFi Network Application (Self-hosted on Ubuntu laptop)
- **Firmware:** 7.2.123

## Management Configuration
- **IP Address:** 192.168.1.104 (DHCP from OPNsense LAN)
- **Management VLAN:** Default (untagged)
- **Controller URL:** http://192.168.10.101:8080/inform
- **Adoption Method:** Layer 3 (Split Brain)

## Split Brain Architecture
```
Switch Management (192.168.1.104) ←→ OPNsense Routing ←→ Controller (192.168.10.101)
       Default VLAN                    Inter-VLAN              Management VLAN
```

## Port Configuration

| Port | Device | Native VLAN | Tagged VLANs | Notes |
|------|--------|------------|--------------|-------|
| 1 | Unused | Default | None | Available |
| 2 | Unused | Default | None | Available |
| 3 | OPNsense LAN | Default | All | Trunk port to router |
| 4 | Unused | Default | None | Reserved for pve1 |
| 5 | Unused | Default | None | Reserved for pve2 |
| 6 | Unused | Default | None | Reserved for pve3 |
| 7 | Unused | Default | None | Available |
| 8 | Unused | Default | None | Available |
| 9 | Ubuntu Laptop | Default | None | Management workstation |
| 10-16 | Unused | Default | None | Available |

## Network Definitions (UniFi Controller)

| Network Name | VLAN ID | Subnet | Gateway | Purpose |
|--------------|---------|--------|---------|---------|
| Default | 1 (untagged) | 192.168.1.0/24 | 192.168.1.1 | Switch management |
| Management | 10 | 192.168.10.0/24 | 192.168.10.1 | Admin devices |
| Corosync | 20 | 192.168.20.0/24 | 192.168.20.1 | Cluster heartbeat |
| Storage | 30 | 192.168.30.0/24 | 192.168.30.1 | Ceph storage |
| VMs | 40 | 192.168.40.0/24 | 192.168.40.1 | VM/Container network |
| Neighbor WiFi | 50 | 192.168.50.0/24 | 192.168.50.1 | Isolated neighbor |

All networks configured as "Third-party Gateway" in UniFi.

## Key Configuration Details

### SSH Access
- **Username:** ubnt
- **Password:** [Set in controller]
- **Access:** `ssh ubnt@192.168.1.104`

### Important Commands
```bash
# Check inform URL
info | grep inform

# Set inform URL
set-inform http://192.168.10.101:8080/inform

# Check switch status
info
```

## Adoption Process
1. Factory reset switch if needed
2. Switch gets DHCP on Default VLAN (192.168.1.x)
3. Adopt in UniFi Controller
4. Set inform URL to Management VLAN controller IP
5. Switch maintains connectivity via OPNsense routing

## Lessons Learned
- UniFi devices expect Layer 2 adjacency by default
- Split Brain configuration allows VLAN separation
- Must use set-inform for Layer 3 adoption
- Port 3 must remain trunk with native Default VLAN
- Switch management stays on Default VLAN for stability

## Troubleshooting
- If adoption fails: Check inter-VLAN routing in OPNsense
- If switch goes offline: Can still SSH via 192.168.1.104
- Factory reset: Hold reset button 10+ seconds
- Recovery: Connect to any port for Default VLAN access
