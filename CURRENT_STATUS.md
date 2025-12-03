# 📊 Current Homelab Status

**Last Updated:** 2025-12-03  
**Overall Health:** 🟢 Operational  
**Uptime:** Stable after DNS-over-Tailscale fix  
**Last Incident:** Tailscale DNS resolution fixed

## 🚦 Quick Status

| Component | Status | Details |
|-----------|--------|---------|
| **Proxmox Cluster** | ✅ Healthy | 3 nodes, quorum established |
| **Ceph Storage** | ✅ HEALTH_OK | 508GB available, 3x replication |
| **Network** | ✅ Operational | All VLANs active, routing working |
| **Containers** | ✅ 9/9 Running | All containers up (Redis service inactive) |
| **Backups** | ✅ Automated | Daily 02:00, Mac Pro NAS mounted |
| **Remote Access** | ✅ Active | Tailscale operational with DNS |
| **DNS** | ✅ Working | Pi-hole operational, Tailscale DNS configured |
| **Mac Pro NAS** | ✅ Operational | SSHFS mounted, Pegasus storage online |
| **UniFi WiFi** | ✅ Operational | 3 APs, 3 SSIDs, controller on CT107 |
| **UPS** | ✅ Protected | CyberPower 1600VA, 17% load, all systems monitored |

## 📋 UPS Status

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

### 2. ProtonVPN Blocks Tailscale DNS
- **Impact:** Low - only affects remote access with ProtonVPN active
- **Cause:** ProtonVPN's DNS leak protection intercepts all DNS queries
- **Workaround:** Disconnect ProtonVPN when accessing homelab remotely
- **Status:** Known limitation, documented in troubleshooting guide

## 🟢 Recently Resolved

### DNS over Tailscale (RESOLVED 2025-12-03)
- **Issue:** DNS queries to Pi-hole timed out when accessing homelab via Tailscale
- **Root Cause:** Two issues:
  1. OPNsense had no route for Tailscale return traffic (100.64.0.0/10)
  2. Tailscale DNS settings not configured to use Pi-hole
- **Solution:** 
  1. Added static route in OPNsense: 100.64.0.0/10 → Tailscale_GW (192.168.40.10)
  2. Configured Tailscale admin DNS: Pi-hole as nameserver, homelab.local as search domain
  3. Enabled "Override DNS servers" in Tailscale admin
- **Status:** ✅ Fully working (when ProtonVPN disconnected)

## 🔄 Recent Changes

| Date | Change | Impact |
|------|--------|--------|
| 2025-12-03 | Fixed HomeNet SSID not broadcasting from AP-Upstairs | HomeNet now visible from all locations |
| 2025-12-03 | Added OPNsense static route for Tailscale (100.64.0.0/10) | Enables return traffic for Tailscale clients |
| 2025-12-03 | Configured Tailscale DNS (Pi-hole + homelab.local) | .homelab.local domains resolve remotely |
| 2025-12-02 | Rack migration completed | All hardware in new rack |
| 2025-11-28 | UniFi WiFi deployment | 3 APs, 3 SSIDs operational |

## 📝 Next Actions

1. **Consider:** Static DHCP reservations for APs in OPNsense to prevent IP changes
2. **Consider:** ProtonVPN split tunneling to allow both VPNs simultaneously
3. **Monitor:** Tailscale DNS performance over time
4. **Document:** Update GitHub repository with latest changes

## 🔧 OPNsense Configuration Reference

### Gateways (System → Gateways → Configuration)
| Name | Interface | IP Address | Purpose |
|------|-----------|------------|---------|
| WAN_GW | WAN | 10.1.1.1 | Internet gateway |
| Tailscale_GW | VMsVLAN | 192.168.40.10 | Tailscale subnet router |

### Static Routes (System → Routes → Configuration)
| Destination | Gateway | Description |
|-------------|---------|-------------|
| 100.64.0.0/10 | Tailscale_GW | Tailscale CGNAT return traffic |

## 🌐 Tailscale DNS Configuration

**Admin Panel:** https://login.tailscale.com/admin/dns

| Setting | Value |
|---------|-------|
| Global Nameserver | 192.168.40.53 (Pi-hole) |
| Search Domain | homelab.local |
| Override DNS servers | ✅ Enabled |

## 📊 Service Health

| CT ID | Service | IP | Status | Notes |
|-------|---------|-----|--------|-------|
| 100 | Tailscale | 192.168.40.10 | ✅ Running | Subnet router + DNS |
| 101 | Pi-hole | 192.168.40.53 | ✅ Running | DNS server |
| 102 | Nginx Proxy | 192.168.40.22 | ✅ Running | Reverse proxy |
| 103 | Uptime Kuma | 192.168.40.23 | ✅ Running | Monitoring |
| 104 | Nextcloud | 192.168.40.31 | ✅ Running | Cloud storage |
| 105 | MariaDB | 192.168.40.32 | ✅ Running | Database |
| 106 | Redis | 192.168.40.33 | ⚠️ Container only | Service not configured |
| 107 | UniFi Controller | 192.168.40.40 | ✅ Running | Network management |
| 112 | n8n | 192.168.40.61 | ✅ Running | Automation |

---

*Update this file after any infrastructure changes*  
*Last verified: 2025-12-03*