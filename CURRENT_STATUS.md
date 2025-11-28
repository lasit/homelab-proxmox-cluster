# 📊 Current Homelab Status

**Last Updated:** 2025-11-28  
**Overall Health:** 🟢 Operational (2 minor issues)  
**Uptime:** 33+ days  
**Last Incident:** IoT VLAN troubleshooting resolved

## 🚦 Quick Status

| Component | Status | Details |
|-----------|--------|---------|
| **Proxmox Cluster** | ✅ Healthy | 3 nodes, quorum established |
| **Ceph Storage** | ✅ HEALTH_OK | 172GB available, 3x replication |
| **Network** | ✅ Operational | All VLANs active, routing working |
| **Containers** | ✅ 9/9 Running | All containers up (Redis service inactive) |
| **Backups** | ✅ Automated | Daily 02:00 |
| **Remote Access** | ✅ Active | Tailscale operational |
| **DNS** | ✅ Working | Pi-hole operational |
| **Mac Pro NAS** | ⚠️ Partial | SSHFS working, ping failing |
| **UniFi WiFi** | ✅ Operational | 3 APs, 3 SSIDs, controller on CT107 |

## 🔴 Active Issues

### 1. Mac Pro Not Responding to Ping
- **Impact:** None - SSHFS mounts working normally
- **Cause:** Unknown - possibly network configuration
- **Workaround:** Not needed - backups working
- **Investigation:** Check network settings on Mac Pro

### 2. Redis Service Not Running
- **Impact:** None - Nextcloud works without cache
- **Cause:** systemd namespace issues in unprivileged LXC
- **Workaround:** Not needed currently
- **Fix Plan:** Redeploy with Docker when needed

## 📈 Recent Changes

### November 28, 2025
- ✅ Deployed UniFi Controller (CT107) on Proxmox
- ✅ Migrated switch from laptop to container controller
- ✅ Adopted 3 UniFi U6+ access points
- ✅ Configured 3 SSIDs: HomeNet, IoT, Neighbor
- ✅ Created VLAN 60 (IoT) in OPNsense
- ✅ Configured IoT firewall rules (DNS allow, internal block, internet allow)
- ✅ Updated UniFi Controller from 9.5.21 to 10.0.160
- ✅ Disabled old UniFi Controller on laptop
- ✅ Verified WiFi isolation working for IoT and Neighbor networks

### November 25, 2025
- ✅ Fixed Pi-hole DNS configuration (now points to proxy)
- ✅ Removed duplicate hosts arrays in pihole.toml
- ✅ Verified all service DNS entries correct
- ✅ Updated troubleshooting documentation

### November 24, 2025
- ✅ Mac Pro reinstalled with Ubuntu 22.04
- ✅ Fixed boot hang issue (stex driver timing)
- ✅ Documented solution for Thunderbolt storage
- ✅ Verified all services operational

### November 19, 2025
- ✅ Deployed Nextcloud (CT104) - cloud storage operational
- ✅ Deployed MariaDB (CT105) - database backend
- ✅ Deployed n8n (CT112) - workflow automation
- ✅ Configured Obsidian sync via WebDAV
- ✅ Mobile access working via Tailscale

### November 18, 2025
- ✅ Deployed Nginx Proxy Manager (CT102)
- ✅ Deployed Uptime Kuma (CT103)
- ✅ Configured 5 proxy hosts
- ✅ Set up 8 monitoring endpoints
- ✅ Automated backup retention configured

## 🎯 Next Actions

### Immediate (This Week)
- [ ] Add UniFi Controller to Uptime Kuma monitoring
- [ ] Migrate IoT devices to IoT SSID
- [ ] Test neighbor WiFi with actual neighbor device
- [ ] Investigate Mac Pro ping issue

### Short Term (Next 2 Weeks)
- [ ] Deploy Vaultwarden password manager
- [ ] Configure email notifications
- [ ] Set up Nextcloud external storage
- [ ] Plan SSL certificate strategy
- [ ] Migrate Home Assistant to Proxmox

### Medium Term (Next Month)
- [ ] Deploy Immich for photos
- [ ] Deploy Jellyfin for media
- [ ] Install UPS units
- [ ] Deploy monitoring stack
- [ ] Configure separate ISP WiFi for hardcoded IoT devices

## 📊 Resource Utilization

### Cluster Resources
```
CPU:     16/72 cores allocated (22%)
RAM:     14/96 GB allocated (14.6%)
Storage: 94/172 GB Ceph used (55%)
Backup:  17/9100 GB used (0.2%)
Power:   ~185W / $40 AUD per month
```

### Container Health
```
Running:     9/9 containers
Auto-start:  9/9 enabled
Backed up:   8/9 (includes non-operational Redis)
Monitored:   4/9 via Uptime Kuma (add UniFi)
```

## 🖥️ Container Inventory

| CT ID | Service | Node | IP | Status |
|-------|---------|------|-----|--------|
| 100 | Tailscale | pve1 | 192.168.40.10 | ✅ Running |
| 101 | Pi-hole | pve1 | 192.168.40.53 | ✅ Running |
| 102 | Nginx Proxy | pve2 | 192.168.40.22 | ✅ Running |
| 103 | Uptime Kuma | pve2 | 192.168.40.23 | ✅ Running |
| 104 | Nextcloud | pve3 | 192.168.40.31 | ✅ Running |
| 105 | MariaDB | pve3 | 192.168.40.32 | ✅ Running |
| 106 | Redis | pve3 | 192.168.40.33 | ⚠️ Service inactive |
| 107 | UniFi Controller | pve1 | 192.168.40.40 | ✅ Running |
| 112 | n8n | pve1 | 192.168.40.61 | ✅ Running |

## 📡 WiFi Infrastructure

### Access Points
| Name | Port | IP | Status |
|------|------|-----|--------|
| AP-Upstairs | 1 | 192.168.1.145 | ✅ Online |
| AP-Downstairs | 2 | 192.168.1.146 | ✅ Online |
| AP-Neighbor | 4 | 192.168.1.147 | ✅ Online |

### SSIDs
| SSID | VLAN | Purpose | Status |
|------|------|---------|--------|
| HomeNet | 40 | Trusted devices | ✅ Working |
| IoT | 60 | Smart home devices | ✅ Working |
| Neighbor | 50 | Neighbor internet | ✅ Working |

## 🔗 Quick Links

### Documentation
- [Infrastructure Details](docs/reference/infrastructure.md)
- [Service Registry](docs/reference/services.md)
- [Quick Commands](QUICKSTART.md)
- [Network Map](docs/reference/network-table.md)
- [UniFi WiFi Guide](docs/guides/unifi-wifi-deployment.md)

### Access Points
- Proxmox: https://192.168.10.11:8006
- UniFi: https://192.168.40.40:8443
- Services: http://status.homelab.local
- Remote: Via Tailscale VPN

### External
- [Tailscale Admin](https://login.tailscale.com)
- [GitHub Repository](https://github.com/lasit/homelab-proxmox-cluster)

## 📝 Notes for Next Session

When returning to this project:
1. Run `./scripts/daily-health.sh`
2. Check Uptime Kuma for alerts
3. Verify WiFi networks operational
4. Review any backup failures
5. Check UniFi Controller for device status

## 🏆 Achievements

- ✅ 33+ days uptime
- ✅ 100% backup success rate
- ✅ Zero data loss incidents
- ✅ Successful disaster recovery (Mac Pro)
- ✅ 9 services deployed and operational
- ✅ Complete WiFi infrastructure deployed
- ✅ VLAN segmentation with security isolation

---

*Auto-updated by verification scripts*  
*For detailed status, run: `./scripts/verify-state.sh`*