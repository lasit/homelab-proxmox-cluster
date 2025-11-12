# 📊 Current Homelab Status
**Last Updated:** November 12, 2025  
**Current Phase:** Phase 6 In Progress - Core Services Deployed  
**Cluster Health:** ✅ OPERATIONAL - Full remote access enabled

## 🔥 Quick Status Dashboard
```
Cluster:     ✅ 3 nodes, quorum established, web UI accessible
Networking:  ✅ OPNsense router configured, all VLANs operational
Storage:     ✅ Ceph HEALTH_OK, 515GB raw, 172GB usable  
Services:    ✅ Tailscale & Pi-hole deployed and operational
Remote:      ✅ Full access via Tailscale from anywhere
Ad Blocking: ✅ Pi-hole protecting entire network
```

## ✅ Recent Accomplishments (November 12, 2025)

### Network Infrastructure Completed
- **Router:** Protectli FW4C installed with OPNsense 25.1
- **VLANs:** All 5 VLANs configured and tested
  - VLAN 10: Management (192.168.10.0/24) - DHCP active
  - VLAN 20: Corosync (192.168.20.0/24)
  - VLAN 30: Storage (192.168.30.0/24)
  - VLAN 40: VMs (192.168.40.0/24)
  - VLAN 50: Neighbor (192.168.50.0/24)
- **Switch:** UniFi Switch Lite 16 PoE configured with split-brain management
- **Routing:** Inter-VLAN routing working perfectly

### Proxmox Cluster Restored
- All nodes accessible on Management VLAN
- Cluster quorum maintained throughout network migration
- Ceph storage healthy and operational
- Repository warnings fixed (disabled enterprise repos)

### Phase 6 Services Deployed
- **Tailscale (CT 100):** Remote access gateway at 192.168.40.10
  - Tailscale IP: 100.89.200.114
  - Subnet routing for all VLANs configured
  - Accessible from anywhere with encryption
- **Pi-hole (CT 101):** DNS ad-blocking at 192.168.40.53
  - Blocking ~25% of DNS queries
  - All VLANs using Pi-hole for DNS
  - Web interface operational

## 🎯 Next Steps

### Immediate Services to Deploy
- [ ] Nginx Proxy Manager for reverse proxy
- [ ] Uptime Kuma for monitoring
- [ ] Homepage dashboard
- [ ] Proxmox Backup Server

### Future Considerations
- [ ] Migrate Home Assistant to Proxmox
- [ ] Deploy Grafana + Prometheus for metrics
- [ ] Setup automated backups
- [ ] Configure firewall rules for IoT isolation

## 📝 Configuration Notes

### Access Points (ALL WORKING ✅)
- **OPNsense:** https://192.168.10.1 or https://192.168.1.1
- **Proxmox Nodes:**
  - pve1: https://192.168.10.11:8006 ✅
  - pve2: https://192.168.10.12:8006 ✅
  - pve3: https://192.168.10.13:8006 ✅
- **UniFi Controller:** https://localhost:8443 (on Ubuntu laptop)
- **Tailscale Admin:** https://login.tailscale.com/admin/machines
- **Pi-hole Dashboard:** http://192.168.40.53/admin

### Network Architecture
- **ISP Router:** 10.1.1.1 (providing internet)
- **OPNsense WAN:** 10.1.1.17 (DHCP from ISP)
- **Switch Management:** 192.168.1.104 (split-brain with controller at 192.168.10.101)
- **Ubuntu Laptop:** 192.168.1.105 (Default) + 192.168.10.101 (Management)

### Service Containers
| Service | CT ID | IP Address | VLAN | Purpose |
|---------|-------|------------|------|---------|
| Tailscale | 100 | 192.168.40.10 | 40 | Remote access gateway |
| Pi-hole | 101 | 192.168.40.53 | 40 | DNS ad-blocking |

### Switch Port Assignments
- Port 2: pve1 (Default VLAN, Allow All tagged)
- Port 3: OPNsense trunk
- Port 4: pve2 (Default VLAN, Allow All tagged)
- Port 6: pve3 (Default VLAN, Allow All tagged)
- Port 9: Ubuntu laptop
- Port 13: MQTT Raspberry Pi (needs configuration)

## 📊 Performance Metrics
- **Cluster RAM:** 96GB total, ~70GB available
- **Ceph Storage:** 172GB usable (3x replication)
- **Pi-hole Blocking:** ~25% average
- **Power Usage:** ~150W total (3 nodes + network equipment)

## 🔒 Security Status
- ✅ Remote access secured via Tailscale (encrypted)
- ✅ Ad blocking active on all networks
- ⚠️ IoT isolation firewall rules pending
- ⚠️ Neighbor VLAN isolation pending

## 📚 Documentation
All configurations documented in GitHub repository:
- `/architecture/` - Network designs and hardware inventory
- `/services/` - Service deployment guides
- `/operations/` - Maintenance procedures
