# 📊 Current Homelab Status

**Last Updated:** 2025-12-02  
**Overall Health:** 🟢 Operational  
**Uptime:** Freshly restarted after rack migration  
**Last Incident:** Rack migration completed successfully

## 🚦 Quick Status

| Component | Status | Details |
|-----------|--------|---------|
| **Proxmox Cluster** | ✅ Healthy | 3 nodes, quorum established |
| **Ceph Storage** | ✅ HEALTH_OK | 508GB available, 3x replication |
| **Network** | ✅ Operational | All VLANs active, routing working |
| **Containers** | ✅ 9/9 Running | All containers up (Redis service inactive) |
| **Backups** | ✅ Automated | Daily 02:00, Mac Pro NAS mounted |
| **Remote Access** | ✅ Active | Tailscale operational |
| **DNS** | ✅ Working | Pi-hole operational |
| **Mac Pro NAS** | ✅ Operational | SSHFS mounted, Pegasus storage online |
| **UniFi WiFi** | ✅ Operational | 3 APs, 3 SSIDs, controller on CT107 |
| **UPS** | ✅ Protected | CyberPower 1600VA, 17% load, all systems monitored |

## 🔋 UPS Status

| Metric | Value |
|--------|-------|
| **Model** | CyberPower CP1600EPFCLCD-AU |
| **Status** | OL (Online - Mains Power) |
| **Load** | ~17% (~142W) |
| **Battery** | 100% |
| **Est. Runtime** | ~34-45 minutes |
| **NUT Master** | pve1 (USB connected) |
| **NUT Slaves** | pve2, pve3, Mac Pro |
| **Uptime Kuma** | Push monitor (every 60s) |

### Protected Equipment
- ✅ pve1, pve2, pve3 (NUT monitored)
- ✅ OPNsense router
- ✅ UniFi Switch
- ✅ Mac Pro + Pegasus (NUT monitored)

### Quick UPS Check
```bash
ssh root@192.168.10.11 "upsc cyberpower@localhost | grep -E '^(ups.status|ups.load|battery.charge|battery.runtime):'"
```

## 🔴 Active Issues

### 1. Mac Pro Pegasus Auto-Mount
- **Impact:** Low - requires manual intervention after cold boot
- **Cause:** Boot timing - Thunderbolt device not ready when systemd runs
- **Workaround:** Run `sudo /usr/local/bin/mount-pegasus.sh` after boot
- **Status:** Service is enabled, but timing issue persists

### 2. Redis Service Not Running
- **Impact:** None - Nextcloud works without cache
- **Cause:** systemd namespace issues in unprivileged LXC
- **Workaround:** Not needed currently
- **Fix Plan:** Redeploy with Docker when needed

## 📈 Recent Changes

### December 2, 2025 - UPS Installation
- ✅ **Installed CyberPower CP1600EPFCLCD-AU UPS**
- ✅ Connected all rack equipment to UPS battery backup
- ✅ Configured NUT server on pve1 (netserver mode)
- ✅ Configured NUT clients on pve2, pve3 (netclient mode)
- ✅ Configured NUT client on Mac Pro via Storage VLAN
- ✅ Created cluster-aware shutdown script for Ceph protection
- ✅ Verified all systems can monitor UPS status
- ✅ Added UPS Push monitor to Uptime Kuma
- ✅ Created ups-monitor-push.sh script with cron job
- ✅ Documented complete UPS configuration

### December 2, 2025 - Rack Migration
- ✅ **Completed 16U rack installation**
- ✅ Safely shut down all infrastructure
- ✅ Physically relocated: Mac Pro, Pegasus, 3× HP Elite Mini, OPNsense, UniFi Switch
- ✅ Reconnected all equipment
- ✅ Verified Ceph HEALTH_OK after restart
- ✅ Restored Mac Pro NAS mounts on all nodes
- ⚠️ **Issue Found:** UniFi Switch Port 15 reset to Default VLAN - reconfigured to Storage (VLAN 30)
- ⚠️ **Issue Found:** Mac Pro Pegasus didn't auto-mount - required manual mount script

### November 28, 2025
- ✅ Deployed UniFi Controller (CT107) on Proxmox
- ✅ Migrated switch from laptop to container controller
- ✅ Adopted 3 UniFi U6+ access points
- ✅ Configured 3 SSIDs: HomeNet, IoT, Neighbor
- ✅ Created VLAN 60 (IoT) in OPNsense
- ✅ Configured IoT firewall rules (DNS allow, internal block, internet allow)
- ✅ Updated UniFi Controller from 9.5.21 to 10.0.160

### November 25, 2025
- ✅ Fixed Pi-hole DNS configuration (now points to proxy)
- ✅ Removed duplicate hosts arrays in pihole.toml
- ✅ Verified all service DNS entries correct

### November 24, 2025
- ✅ Mac Pro reinstalled with Ubuntu 22.04
- ✅ Fixed boot hang issue (stex driver timing)
- ✅ Documented solution for Thunderbolt storage

## 🎯 Next Actions

### Immediate (This Week)
- [x] Add UPS monitoring to Uptime Kuma
- [x] Add UPS check to daily-health.sh script
- [ ] Test UPS notifications (simulate power event)
- [ ] Migrate IoT devices to IoT SSID

### Short Term (Next 2 Weeks)
- [ ] Deploy Vaultwarden password manager
- [ ] Configure email notifications for UPS events
- [ ] Set up Nextcloud external storage
- [ ] Plan SSL certificate strategy
- [ ] Migrate Home Assistant to Proxmox (includes NUT integration)

### Medium Term (Next Month)
- [ ] Deploy Immich for photos
- [ ] Deploy Jellyfin for media
- [ ] Consider second UPS for N+1 redundancy
- [ ] Deploy monitoring stack

## 📊 Resource Utilization

### Cluster Resources
```
CPU:     16/72 cores allocated (22%)
RAM:     14/96 GB allocated (14.6%)
Storage: 7.6/515 GB Ceph used (1.5%)
Backup:  31/9100 GB used (0.3%)
Power:   ~142W idle / $51 AUD per month
UPS:     17% load, ~34 min runtime
```

### Container Health
```
Running:     9/9 containers
Auto-start:  9/9 enabled
Backed up:   8/9 (includes non-operational Redis)
Monitored:   5/9 via Uptime Kuma (including UPS)
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
- [UPS Configuration](docs/guides/ups-configuration.md)
- [Power Management](docs/guides/power-management.md)

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
2. Check UPS status: `ssh root@192.168.10.11 "upsc cyberpower@localhost ups.status battery.charge"`
3. Check Uptime Kuma for alerts
4. Verify WiFi networks operational
5. Review any backup failures
6. Check UniFi Controller for device status

## 🏆 Achievements

- ✅ UPS protection fully configured
- ✅ UPS monitoring in Uptime Kuma
- ✅ Successfully completed rack migration
- ✅ 100% backup success rate
- ✅ Zero data loss incidents
- ✅ Successful disaster recovery (Mac Pro)
- ✅ 9 services deployed and operational
- ✅ Complete WiFi infrastructure deployed
- ✅ VLAN segmentation with security isolation
- ✅ 16U rack installation complete
- ✅ Automated UPS shutdown protection

---

*Auto-updated by verification scripts*  
*For detailed status, run: `./scripts/verify-state.sh`*