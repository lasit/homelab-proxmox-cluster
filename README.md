# 🏠 Homelab Proxmox Cluster

**Location:** Darwin, Northern Territory, Australia  
**Project Type:** 3-Node Proxmox VE Cluster with OPNsense Router  
**Timeline:** 10-year operational horizon  
**Philosophy:** Reliability over bleeding edge, learn by doing

## 🚀 Quick Links

- [Current Status](CURRENT_STATUS.md) - Real-time cluster status
- [Network Architecture](architecture/network-design.md) - VLAN design and IP allocation
- [Installation Guide](installation/00-prerequisites.md) - Start here for fresh install
- [Service Catalog](services/service-catalog.md) - Available services to deploy
- [Troubleshooting](operations/troubleshooting.md) - Common issues and fixes

## 🎯 Project Goals

1. **High Availability** - 3-node cluster with automatic failover
2. **Enterprise Learning** - Hands-on experience with production technologies
3. **Smart Home Hub** - Reliable platform for home automation
4. **Data Sovereignty** - Keep data in Australia, under your control
5. **Cost Efficiency** - Optimize for Darwin's high electricity costs (~$0.30/kWh)

## 🖥️ Hardware Overview

### Compute Cluster
- **3x HP Elite Mini 800 G9** (Proxmox nodes)
  - Intel vPro CPU (8 cores each)
  - 32GB RAM per node (96GB total)
  - 500GB NVMe per node

### Network Infrastructure
- **HP Elite Mini 800 G9** - Dedicated OPNsense router
- **UniFi Switch Lite 16 PoE** - Core switch with VLAN support
- **ISP Router** - NBN connection at 10.1.1.1

## 🌐 Network Architecture

```
INTERNET (NBN)
    ↓
ISP Router (10.1.1.1)
    ↓
OPNsense Router (WAN: 10.1.1.91)
    ├── VLAN 10: Management (192.168.10.0/24)
    ├── VLAN 20: Corosync (192.168.20.0/24) [Isolated]
    ├── VLAN 30: Storage (192.168.30.0/24) [Isolated]
    └── VLAN 40: Services (192.168.40.0/24)
```

### Key Network Decisions
- **Smart home devices stay on 10.1.1.x** - Won't migrate existing IoT devices
- **Isolated cluster networks** - Corosync and Ceph traffic separated
- **Service VLAN** - All VMs/containers on dedicated network

## 💾 Storage Architecture

### Ceph Distributed Storage
- **Total Raw:** 515 GiB across 3 nodes
- **Usable:** ~172GB with 3x replication
- **Purpose:** VM disks, container volumes, live migration

### Node Storage Layout
```
Per Node (500GB NVMe):
├── System: ~104GB (Proxmox OS)
├── Local: 200GB (local-lvm)
└── Ceph: ~172GB (distributed storage)
```

## 🔐 Remote Access Strategy

### Tailscale VPN (Planned)
- Install on Proxmox nodes for subnet routing
- Access all VLANs and services remotely
- Bridge to smart home devices on 10.1.1.x
- No port forwarding required (works through CGNAT)

## 📊 Current Deployment Status

| Phase | Status | Completion Date |
|-------|--------|----------------|
| Phase 1: OPNsense Router | ✅ Complete | Oct 22, 2025 |
| Phase 2: Switch VLANs | ✅ Complete | Oct 22, 2025 |
| Phase 3: Proxmox Installation | ✅ Complete | Oct 23, 2025 |
| Phase 4: Cluster Creation | ✅ Complete | Oct 23, 2025 |
| Phase 5: Ceph Storage | ✅ Complete | Oct 23, 2025 |
| Phase 6: Initial Services | 🔄 Planning | In Progress |

## 🚦 Quick Management Access

| Service | URL | Credentials |
|---------|-----|-------------|
| Proxmox Node 1 | https://192.168.10.11:8006 | root / [your-password] |
| Proxmox Node 2 | https://192.168.10.12:8006 | root / [your-password] |
| Proxmox Node 3 | https://192.168.10.13:8006 | root / [your-password] |
| OPNsense | https://192.168.10.1 | root / opnsense |

## 📁 Repository Structure

```
homelab-proxmox-cluster/
├── architecture/       # Network design, hardware specs
├── installation/       # Step-by-step installation guides
├── operations/        # Maintenance, monitoring, backups
├── services/          # Service deployments and configs
├── lessons-learned/   # Knowledge from each phase
└── reference/        # Commands, URLs, local considerations
```

## 🛠️ Useful Commands

### Cluster Health Check
```bash
# Check cluster status
pvecm status

# Check Ceph health
ceph -s

# Check node resources
pvesh get /nodes/pve1/status
```

### Quick Connect via SSH
```bash
# Connect to nodes
ssh root@192.168.10.11  # pve1
ssh root@192.168.10.12  # pve2
ssh root@192.168.10.13  # pve3
```

## 🏗️ Next Steps

1. [ ] Organize and update documentation
2. [ ] Install Tailscale for remote access
3. [ ] Deploy Pi-hole for network-wide ad blocking
4. [ ] Set up Nginx Proxy Manager for service routing
5. [ ] Implement Proxmox Backup Server
6. [ ] Migrate Home Assistant to cluster

## 📚 Learning Resources

- [Proxmox Documentation](https://pve.proxmox.com/wiki/Main_Page)
- [Ceph Best Practices](https://docs.ceph.com/en/latest/rados/operations/best-practices/)
- [OPNsense User Manual](https://docs.opnsense.org/)
- [r/homelab Reddit Community](https://reddit.com/r/homelab)

## ⚡ Darwin Considerations

- **Power Costs:** ~$0.30/kWh - efficiency matters
- **Climate:** Ensure adequate cooling during wet season
- **Internet:** NBN with potential CGNAT issues (Tailscale handles this)
- **Data Sovereignty:** Keep data in Australia

## 📝 License & Sharing

This documentation is shared publicly to help others building similar homelabs. Feel free to use and adapt for your needs.

---

**Project Started:** October 2025  
**Last Updated:** October 25, 2025  
**Maintained by:** [Your Name]
