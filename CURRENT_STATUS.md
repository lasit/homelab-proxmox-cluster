# 📊 Current Homelab Status

**Last Updated:** October 25, 2025  
**Current Phase:** Phase 5 Complete - Awaiting Router Hardware  
**Cluster Health:** ✅ OPERATIONAL (but not accessible)

## 🔥 Quick Status Dashboard

```
Cluster:     ✅ 3 nodes, quorum established
Networking:  ⚠️  Awaiting Protectli VP2420 router
Storage:     ✅ Ceph HEALTH_OK, 515GB raw, 172GB usable
Services:    ⏳ Ready to deploy after router installation
Remote:      ⏳ Tailscale pending
```

## 🚨 Current Situation

**Router Status:** Original OPNsense router removed due to single NIC limitation. Protectli VP2420 ordered (4x 2.5GbE Intel NICs) - expected delivery within 1-2 weeks.

**Temporary Network:** ISP router connected directly to UniFi switch. Ubuntu laptop and iMac have internet via 10.1.1.x network. Proxmox nodes not accessible until router installed.

## 🖥️ Infrastructure Status

### Proxmox Cluster (Temporarily Inaccessible)
| Node | Status | Management IP | Corosync | Storage | Notes |
|------|--------|---------------|----------|---------|-------|
| pve1 | ✅ Running | 192.168.10.11 | 192.168.20.11 | 192.168.30.11 | Not accessible without router |
| pve2 | ✅ Running | 192.168.10.12 | 192.168.20.12 | 192.168.30.12 | Not accessible without router |
| pve3 | ✅ Running | 192.168.10.13 | 192.168.20.13 | 192.168.30.13 | Not accessible without router |

### Network Infrastructure
| Device | Status | Current Config | Notes |
|--------|--------|----------------|-------|
| Protectli VP2420 | 📦 Ordered | N/A | 4-port router, arriving soon |
| UniFi Switch | ✅ Online | Connected to ISP | Providing temporary connectivity |
| ISP Router | ✅ Online | 10.1.1.1 | Direct connection to switch port 16 |

### Current Device Connectivity
| Device | Port | IP Address | Status |
|--------|------|------------|--------|
| Ubuntu Laptop | 9 | 10.1.1.45 | ✅ Internet working |
| iMac | 11 | 10.1.1.x | ✅ Internet working |
| Home Assistant | 3 | 10.1.1.x | ✅ Accessible |
| Proxmox Nodes | 2,4,6 | 192.168.10.x | ⚠️ No routing available |

## 💾 Storage Status

### Ceph Cluster Health
```
Health:        HEALTH_OK (verified Oct 25)
Monitors:      3 (pve1, pve2, pve3) - all in quorum
OSDs:          3 up, 3 in (35+ hours stable)
Pools:         2 (vm-storage, .mgr)
Raw Capacity:  515 GiB
Usable:        ~172 GiB (with 3x replication)
Usage:         116 MiB used (basically empty)
```

## 🚀 Services Ready to Deploy (Phase 6)

### Deployment Plan (After Router Installation)
| Priority | Service | Resources | IP Allocation | Status |
|----------|---------|-----------|---------------|--------|
| 1 | Tailscale | On nodes | N/A | Pending router |
| 2 | Pi-hole | 1GB RAM, 8GB disk | 192.168.40.21 | Pending |
| 3 | Nginx Proxy Manager | 1GB RAM, 10GB disk | 192.168.40.22 | Pending |
| 4 | Uptime Kuma | 512MB RAM, 5GB disk | 192.168.40.23 | Pending |
| 5 | Proxmox Backup Server | 4GB RAM, 100GB disk | 192.168.10.21 | Pending |

## 📋 Completed Phases

### ✅ Phase 1: OPNsense Router (Oct 22, 2025)
- Initially installed on HP Elite Mini
- Configured with VLANs
- **Issue discovered:** Single NIC insufficient

### ✅ Phase 2: Network Configuration (Oct 22, 2025)
- UniFi switch VLAN configuration complete
- Trunk ports configured
- Currently in temporary mode

### ✅ Phase 3: Proxmox Installation (Oct 23, 2025)
- All three nodes installed
- VLAN-aware bridges configured
- Network verified when router was present

### ✅ Phase 4: Cluster Creation (Oct 23, 2025)
- Cluster "homelab" created
- All nodes joined successfully
- Quorum established
- Corosync on VLAN 20

### ✅ Phase 5: Ceph Storage (Oct 23, 2025)
- Ceph installed and configured
- 3 monitors, 3 OSDs
- Storage pool healthy
- 515 GiB raw storage available

## 🎯 Next Actions

### Immediate (When Router Arrives)
1. Install OPNsense on Protectli VP2420
2. Configure WAN on Port 1 (to ISP router)
3. Configure LAN with VLANs on Port 2 (to switch)
4. Restore switch port configurations
5. Verify cluster accessibility

### Phase 6 Deployment (After Router Setup)
- Week 1: Tailscale, Pi-hole, Nginx Proxy Manager
- Week 2: Backup infrastructure
- Week 3: Home Assistant migration
- Month 2: Additional services

## 🔧 Recent Changes

### October 25, 2025
- Verified cluster health (all nodes operational)
- Identified router hardware issue (single NIC)
- Ordered Protectli VP2420 router
- Set up temporary network connectivity
- Created GitHub repository for documentation
- Updated all documentation with current status

### October 23, 2025
- Completed Phase 5: Ceph storage
- Cluster fully operational

## ⚠️ Known Issues

| Issue | Severity | Impact | Resolution |
|-------|----------|--------|------------|
| No router | High | Cannot access cluster | Protectli VP2420 arriving soon |
| VLANs not routed | Medium | Networks isolated | Will be fixed with router |
| No remote access | Low | Local access only | Tailscale pending router |

## 📈 Resource Planning

### Power Consumption
- **Current (without router):** ~75W
- **With Protectli router:** ~85W total
- **Monthly cost:** ~$19 AUD (@$0.30/kWh)
- **Annual cost:** ~$224 AUD

### Available Resources (When Accessible)
- **CPU:** 24 cores (3x 8-core nodes)
- **RAM:** 96GB total
- **Storage:** 172GB Ceph (replicated)
- **Local Storage:** 600GB (200GB per node)

## 🛍️ Hardware Orders

| Item | Model | Price | Status | Expected |
|------|-------|-------|--------|----------|
| Router | Protectli VP2420 | $844 AUD | Ordered Oct 25 | 1-2 weeks |

## 📞 Quick Reference

### When Router Installed
```bash
# Access nodes
ssh root@192.168.10.11  # pve1
ssh root@192.168.10.12  # pve2
ssh root@192.168.10.13  # pve3

# Web interfaces
https://192.168.10.1    # OPNsense
https://192.168.10.11:8006  # Proxmox
```

### Current Temporary Access
```bash
# UniFi Controller
https://10.1.1.45:8443  # From Ubuntu laptop

# Home Assistant
http://pifrontdoor.local:8123
```

---

**Note:** Cluster is healthy but inaccessible until router installation. No action needed on Proxmox nodes - they're running fine and waiting for network routing to be restored.
