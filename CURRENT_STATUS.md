# 📊 Current Homelab Status

**Last Updated:** October 25, 2025  
**Current Phase:** Phase 5 Complete - Ready for Phase 6 (Services)  
**Cluster Health:** ✅ OPERATIONAL

## 🔥 Quick Status Dashboard

```
Cluster:     ✅ 3 nodes, quorum established
Networking:  ✅ All VLANs operational
Storage:     ✅ Ceph HEALTH_OK, 172GB usable
Services:    ⏳ Planning deployment
Remote:      ⏳ Tailscale not yet configured
```

## 🖥️ Infrastructure Status

### Proxmox Cluster
| Node | Status | Management IP | Web UI | CPU Load | RAM Used | Storage |
|------|--------|---------------|--------|----------|----------|---------|
| pve1 | ✅ Online | 192.168.10.11 | [Access](https://192.168.10.11:8006) | Low | ~4GB/32GB | 104GB used |
| pve2 | ✅ Online | 192.168.10.12 | [Access](https://192.168.10.12:8006) | Low | ~4GB/32GB | 104GB used |
| pve3 | ✅ Online | 192.168.10.13 | [Access](https://192.168.10.13:8006) | Low | ~4GB/32GB | 104GB used |

### Network Infrastructure
| Device | Status | IP Address | Role | Notes |
|--------|--------|------------|------|-------|
| OPNsense | ✅ Online | 192.168.10.1 | Router/Firewall | WAN: 10.1.1.91 |
| UniFi Switch | ✅ Online | Managed | Core Switch | 4 trunk ports configured |
| ISP Router | ✅ Online | 10.1.1.1 | Internet Gateway | NBN connection |

### VLAN Status
| VLAN | Network | Purpose | Status | Gateway |
|------|---------|---------|--------|---------|
| 10 | 192.168.10.0/24 | Management | ✅ Operational | OPNsense (.1) |
| 20 | 192.168.20.0/24 | Corosync | ✅ Operational | None (isolated) |
| 30 | 192.168.30.0/24 | Storage/Ceph | ✅ Operational | None (isolated) |
| 40 | 192.168.40.0/24 | VM/Services | ✅ Operational | OPNsense (.1) |

## 💾 Storage Status

### Ceph Cluster Health
```
Health:        HEALTH_OK
Monitors:      3 (pve1, pve2, pve3) - all in quorum
OSDs:          3 up, 3 in
Pools:         2 (vm-storage, .mgr)
Usage:         0/172GB used (0%)
Replication:   3x (data on all nodes)
```

### Storage Pools
| Pool | Size | Available | Used | Purpose |
|------|------|-----------|------|---------|
| local-lvm (pve1) | 200GB | 200GB | 0% | Local VMs |
| local-lvm (pve2) | 200GB | 200GB | 0% | Local VMs |
| local-lvm (pve3) | 200GB | 200GB | 0% | Local VMs |
| ceph-vm | 172GB | 172GB | 0% | Shared storage |

## 🚀 Running Services

### Virtual Machines
| VM | Node | Status | IP | Purpose |
|----|------|--------|----|---------| 
| - | - | - | - | None deployed yet |

### Containers
| CT | Node | Status | IP | Purpose |
|----|------|--------|----|---------|
| - | - | - | - | None deployed yet |

## 📋 Completed Phases

### ✅ Phase 1: OPNsense Router (Oct 22, 2025)
- Installed OPNsense on dedicated hardware
- Configured WAN from ISP DHCP
- Set up 4 VLANs with proper isolation
- Firewall rules established

### ✅ Phase 2: Network Configuration (Oct 22, 2025)
- UniFi switch VLAN configuration
- Trunk ports for all nodes and router
- Management access port configured
- VLAN tagging verified

### ✅ Phase 3: Proxmox Installation (Oct 23, 2025)
- All three nodes installed with PVE
- VLAN-aware bridge configured
- Network connectivity verified
- Web UI access confirmed

### ✅ Phase 4: Cluster Creation (Oct 23, 2025)
- Cluster "homelab" created
- All nodes joined successfully
- Quorum established (3/3 votes)
- Corosync on dedicated VLAN

### ✅ Phase 5: Ceph Storage (Oct 23, 2025)
- Ceph installed on all nodes
- 3 monitors, 3 OSDs configured
- Storage pool created (vm-storage)
- Health status: HEALTH_OK

## 🎯 Next Actions (Phase 6)

### Immediate (This Weekend)
- [ ] Install Tailscale on laptop and phone
- [ ] Configure Tailscale on pve1 with subnet routing
- [ ] Deploy Pi-hole for ad blocking
- [ ] Deploy Nginx Proxy Manager

### Next Week
- [ ] Set up Proxmox Backup Server
- [ ] Migrate Home Assistant to cluster
- [ ] Configure automated backups
- [ ] Deploy Uptime Kuma for monitoring

### This Month
- [ ] Deploy Vaultwarden password manager
- [ ] Set up Nextcloud for file sync
- [ ] Configure alerting and monitoring
- [ ] Document all service configurations

## 🔧 Recent Changes

### October 25, 2025
- Started Phase 6 planning
- Documentation reorganization initiated
- GitHub repository structure created

### October 23, 2025
- Completed Phase 5: Ceph storage configured
- All storage pools created and verified
- Cluster fully operational

## ⚠️ Known Issues

| Issue | Severity | Impact | Workaround |
|-------|----------|--------|------------|
| None currently | - | - | - |

## 📈 Resource Usage

### Power Consumption (Estimated)
- **Current Draw:** ~100W (all nodes + router + switch)
- **Monthly Cost:** ~$22 AUD (@$0.30/kWh)
- **Annual Cost:** ~$262 AUD

### Network Utilization
- **WAN Usage:** Minimal (updates only)
- **Cluster Traffic:** <1MB/s (idle)
- **Storage Replication:** No active data

## 🔐 Security Status

- [x] OPNsense firewall configured
- [x] VLANs properly isolated
- [x] SSH key authentication (recommended)
- [ ] Tailscale VPN (pending)
- [ ] Automated security updates (pending)
- [ ] Backup encryption (pending)

## 📞 Quick Connect Commands

```bash
# SSH to nodes
ssh root@192.168.10.11  # pve1
ssh root@192.168.10.12  # pve2
ssh root@192.168.10.13  # pve3

# Access OPNsense
ssh root@192.168.10.1   # OPNsense

# Check cluster status
ssh root@192.168.10.11 'pvecm status'

# Check Ceph health
ssh root@192.168.10.11 'ceph -s'
```

## 🔗 Management URLs

| Service | URL | Default Login |
|---------|-----|---------------|
| Proxmox Cluster | https://192.168.10.11:8006 | root / [password] |
| OPNsense | https://192.168.10.1 | root / opnsense |
| UniFi Controller | Not deployed yet | - |

---

**Auto-refresh:** This document should be updated after any infrastructure changes  
**Next Review:** After first service deployment
