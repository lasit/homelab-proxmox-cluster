# 🔧 Router Hardware Decision

**Date:** October 25, 2025  
**Status:** Protectli VP2420 Ordered  
**Issue:** Original HP Elite Mini only has single NIC

## Problem Summary

The initial OPNsense installation on HP Elite Mini 800 G9 failed due to hardware limitations:
- Only one built-in Ethernet port (em0)
- USB-to-Ethernet adapter (Comsol USB-C to 2.5G) experienced:
  - Constant disconnections
  - FreeBSD/OPNsense driver incompatibility
  - USB power management issues
  - Not suitable for 24/7 router operation

## Solution Selected

### Protectli Vault Pro VP2420
**Ordered:** October 25, 2025  
**Cost:** $844 AUD (Amazon AU)  
**Expected Delivery:** 1-2 weeks

### Specifications
- **CPU:** Intel Celeron J4125 (Quad-core, AES-NI)
- **RAM:** 8GB DDR4
- **Storage:** 120GB M.2 SSD
- **Network:** 4x 2.5GbE Intel i225-V ports
- **Power:** ~10W consumption (fanless)
- **Warranty:** 2 years

### Why This Model

**Chosen over VP2410 (1GbE):**
- Only $100 more for 2.5GbE ports
- Future-proof for NBN upgrades
- Better long-term value

**Advantages:**
- Purpose-built for pfSense/OPNsense
- Intel NICs with excellent BSD support
- Fanless design perfect for Darwin climate
- 4 ports allow for future DMZ/guest networks
- Low power consumption (~$26/year)

## Alternative Options Considered

| Model | Price | Pros | Cons | Decision |
|-------|-------|------|------|----------|
| Qotom Q330G4 | $350 | Cheaper, 4x 1GbE | No 2.5GbE, longer shipping | Rejected |
| Netgate 6100 | $1100 | Enterprise grade | Too expensive | Rejected |
| Virtualized on Proxmox | $0 | No new hardware | Single point of failure | Rejected |
| USB Adapter workaround | $30 | Cheapest | Unreliable, proven failure | Rejected |

## Timeline

```
Oct 25: Ordered Protectli VP2420
Week 1: Expected delivery
Week 2: Installation and configuration
Week 3: Phase 6 service deployment
```

## Installation Plan

### Hardware Setup
1. Port 1 (WAN) → ISP Router (10.1.1.1)
2. Port 2 (LAN) → UniFi Switch Port 1 (trunk)
3. Port 3 → Reserved for future DMZ
4. Port 4 → Reserved for backup/bypass

### Software Configuration
1. Install OPNsense 24.7 or latest
2. Configure VLANs on LAN port:
   - VLAN 10: Management (192.168.10.0/24)
   - VLAN 20: Corosync (192.168.20.0/24)
   - VLAN 30: Storage (192.168.30.0/24)
   - VLAN 40: Services (192.168.40.0/24)
3. Restore firewall rules
4. Configure DHCP per VLAN
5. Test all routing paths

## Network Topology After Installation

```
INTERNET
    ↓
ISP Router (10.1.1.1)
    ↓
Protectli VP2420 - Port 1 (WAN)
    |
[OPNsense Firewall/Router]
    |
Protectli VP2420 - Port 2 (LAN/Trunk)
    ↓
UniFi Switch Port 1
    ├── Port 2: pve1 (Trunk)
    ├── Port 4: pve2 (Trunk)
    ├── Port 6: pve3 (Trunk)
    ├── Port 9: Ubuntu (VLAN 10)
    └── Port 11: iMac (Default)
```

## Cost Analysis

### One-Time Costs
- Protectli VP2420: $844 AUD
- HP Elite Mini (repurpose): Use for future services

### Annual Operating Costs
- Power (10W @ $0.30/kWh): ~$26/year
- Total cluster with router: ~$224/year

### ROI Justification
- Enterprise-grade routing: Worth $200/year
- Learning platform: Invaluable
- 10-year lifespan: $84/year amortized
- Reliability vs USB adapter: Priceless

## Lessons Learned

1. **Don't compromise on router hardware** - Single NIC solutions are problematic
2. **USB network adapters unsuitable** for BSD-based routers
3. **Intel NICs are mandatory** for FreeBSD/OPNsense
4. **Purpose-built hardware** worth the investment
5. **2.5GbE future-proofing** only $100 premium

## HP Elite Mini Repurposing

The original HP Elite Mini (removed from router duty) can be repurposed:
- Windows/Linux desktop
- Dedicated backup server
- Media server
- Development environment
- Sell to recoup costs (~$200-300)

---

**Next Update:** When Protectli arrives and OPNsense installation begins
