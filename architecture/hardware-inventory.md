# 🖥️ Hardware Inventory

**Last Updated:** October 25, 2025  
**Total Investment:** [To be documented]  
**Power Consumption:** ~100W continuous

## Compute Hardware

### Proxmox Cluster Nodes

| Node | Model | Serial | Purchase Date | Warranty | Location |
|------|-------|--------|---------------|----------|----------|
| pve1 | HP Elite Mini 800 G9 | [TBD] | Oct 2025 | 3 years | Rack Position 1 |
| pve2 | HP Elite Mini 800 G9 | [TBD] | Oct 2025 | 3 years | Rack Position 2 |
| pve3 | HP Elite Mini 800 G9 | [TBD] | Oct 2025 | 3 years | Rack Position 3 |

### OPNsense Router

| Component | Specification | Notes |
|-----------|---------------|-------|
| Model | HP Elite Mini 800 G9 | Dedicated hardware firewall |
| Serial | [TBD] | |
| Purchase Date | Oct 2025 | |
| Warranty | 3 years | |
| Location | Rack Position 4 | |

### Detailed Specifications (Per Node)

#### CPU
- **Model:** Intel Core i5-12500T (12th Gen)
- **Cores:** 6 Performance cores (12 threads)
- **Base Clock:** 2.0 GHz
- **Boost Clock:** Up to 4.4 GHz
- **TDP:** 35W (T-series for efficiency)
- **Features:** vPro, VT-x, VT-d, AES-NI

#### Memory
- **Capacity:** 32GB (2x16GB)
- **Type:** DDR5-4800 SO-DIMM
- **Configuration:** Dual-channel
- **Max Supported:** 64GB
- **Upgrade Path:** Replace with 2x32GB if needed

#### Storage
- **Primary:** 500GB NVMe M.2 SSD
- **Model:** [TBD - likely WD or Samsung OEM]
- **Interface:** PCIe 4.0 x4
- **Partitioning:**
  - Proxmox OS: ~104GB
  - Local-LVM: 200GB
  - Ceph OSD: ~172GB

#### Networking
- **NIC:** Intel I219-LM
- **Speed:** 1 Gigabit Ethernet
- **Interface Name:** eno1 (Proxmox), em0 (OPNsense)
- **Features:** vPro, WoL, PXE boot

#### Expansion
- **M.2 Slots:** 2 (1 used for NVMe)
- **SATA Ports:** 1 (unused)
- **USB Ports:** 
  - Front: 2x USB-A 3.2, 1x USB-C
  - Rear: 4x USB-A 3.2, 1x USB-C
- **Display Outputs:** HDMI 2.1, DisplayPort 1.4

## Network Hardware

### Core Switch

| Component | Specification | Notes |
|-----------|---------------|-------|
| Model | Ubiquiti UniFi Switch Lite 16 PoE | |
| Ports | 16x Gigabit Ethernet | 8x PoE+ capable |
| PoE Budget | 45W total | Not currently utilized |
| Management | UniFi Controller | Web-based |
| Firmware | [Version TBD] | |
| VLANs Configured | 10, 20, 30, 40 | Plus default untagged |

### Port Allocation

| Port | Connected Device | Speed | PoE | VLANs |
|------|-----------------|-------|-----|-------|
| 1 | OPNsense | 1Gb | No | Trunk: All |
| 2 | pve1 | 1Gb | No | Trunk: All |
| 3 | Empty | - | - | - |
| 4 | pve2 | 1Gb | No | Trunk: All |
| 5 | Empty | - | - | - |
| 6 | pve3 | 1Gb | No | Trunk: All |
| 7-8 | Empty | - | Yes | Available |
| 9 | Management Laptop | 1Gb | No | Access: VLAN 10 |
| 10-16 | Empty | - | Yes | Available for expansion |

### ISP Equipment

| Component | Specification | Notes |
|-----------|---------------|-------|
| ISP Router | [Model TBD] | NBN connection |
| IP Address | 10.1.1.1 | Gateway for WAN |
| Connection Type | NBN [Type TBD] | |
| Speed | [TBD] Mbps | |

## Management Hardware

### Installation Laptop

| Component | Specification | Notes |
|-----------|---------------|-------|
| Model | HP ProBook 440 G10 | |
| OS | Ubuntu Linux | Latest LTS |
| Network Interface | enp4s0 | |
| Purpose | Management and installation | |
| IP Address | DHCP from VLAN 10 | |

## Power Infrastructure

### Current Setup

| Component | Power Draw | Annual Cost (@$0.30/kWh) |
|-----------|------------|--------------------------|
| pve1 | ~25W | $65 AUD |
| pve2 | ~25W | $65 AUD |
| pve3 | ~25W | $65 AUD |
| OPNsense | ~20W | $52 AUD |
| UniFi Switch | ~10W | $26 AUD |
| **Total** | **~105W** | **$273 AUD** |

### Power Recommendations

#### Immediate (Optional)
- **Basic UPS:** 600-1000VA
  - Runtime: 15-30 minutes
  - Clean shutdown capability
  - ~$200-300 AUD

#### Future Considerations
- **Larger UPS:** 1500-2000VA
  - Runtime: 30-60 minutes
  - Network management card
  - ~$500-800 AUD

## Environmental Considerations

### Cooling Requirements
- **Ambient Temp:** Darwin average 25-32°C
- **Heat Output:** ~105W (360 BTU/hr)
- **Current Cooling:** Ambient room temperature
- **Recommendation:** Ensure adequate airflow

### Physical Layout
```
Suggested Rack/Shelf Arrangement:
┌─────────────────────┐
│   UniFi Switch      │ <- Top (coolest)
├─────────────────────┤
│   OPNsense Router   │
├─────────────────────┤
│   Proxmox pve1      │
├─────────────────────┤
│   Proxmox pve2      │
├─────────────────────┤
│   Proxmox pve3      │ <- Bottom
└─────────────────────┘
```

## Cables and Accessories

### Network Cables
| Type | Length | Quantity | Purpose |
|------|--------|----------|---------|
| Cat6 | 0.5m | 4 | Node to switch |
| Cat6 | 1m | 1 | OPNsense to switch |
| Cat6 | 2m | 1 | Switch to ISP router |
| Cat6 | 3m | 1 | Laptop management |

### Other Cables
| Type | Quantity | Purpose |
|------|----------|---------|
| HDMI | 1 | Console access |
| USB Keyboard | 1 | Installation |
| Power cables | 5 | All devices |

## Spare Parts Recommendations

### Critical Spares
- [ ] 1x 16GB DDR5 SO-DIMM (memory failure)
- [ ] 2x Cat6 cables (various lengths)
- [ ] 1x USB drive (recovery/installation)

### Nice to Have
- [ ] 1x 500GB NVMe SSD (storage failure)
- [ ] 1x 8-port gigabit switch (backup)
- [ ] Extra power cables

## Future Hardware Upgrades

### Short Term (6 months)
1. **UPS** - Power protection
2. **Rack/Shelf** - Proper organization
3. **Cable management** - Clean setup

### Medium Term (1 year)
1. **10Gb Network Cards** - Storage performance
2. **Additional Storage** - NAS or external drives
3. **Monitoring Display** - Dashboard screen

### Long Term (2+ years)
1. **Fourth Node** - Increased capacity
2. **Redundant OPNsense** - HA firewall
3. **10Gb Switch** - Full 10Gb backbone

## Warranty Information

### HP Elite Mini 800 G9 (All units)
- **Warranty Period:** 3 years
- **Type:** Next business day onsite
- **Support:** HP Enterprise support
- **Registration:** [To be completed]

### UniFi Switch
- **Warranty Period:** 1 year
- **Type:** RMA replacement
- **Support:** Ubiquiti online support

## Asset Tracking

| Asset ID | Device | MAC Address | Serial Number | Location |
|----------|--------|-------------|---------------|----------|
| HW-001 | pve1 | [TBD] | [TBD] | Rack Pos 1 |
| HW-002 | pve2 | [TBD] | [TBD] | Rack Pos 2 |
| HW-003 | pve3 | [TBD] | [TBD] | Rack Pos 3 |
| HW-004 | OPNsense | [TBD] | [TBD] | Rack Pos 4 |
| HW-005 | UniFi Switch | [TBD] | [TBD] | Top of rack |

---

**Note:** Update serial numbers and asset tags once systems are accessible.  
**Power measurements:** Based on typical consumption, verify with actual measurements.
