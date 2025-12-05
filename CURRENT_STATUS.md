# 📊 Current Homelab Status

**Last Updated:** 2025-12-05  
**Overall Health:** 🟢 Operational  
**Uptime:** Stable  
**Last Change:** Backup storage migrated from Mac Pro to G-Drive

## 🚦 Quick Status

| Component | Status | Details |
|-----------|--------|---------|
| **Proxmox Cluster** | ✅ Healthy | 3 nodes, quorum established |
| **Ceph Storage** | ✅ HEALTH_OK | 508GB available, 3x replication |
| **Network** | ✅ Operational | All VLANs active, routing working |
| **Containers** | ✅ 9/9 Running | All containers up (Redis service inactive) |
| **Backups** | ✅ Automated | Daily 02:00, G-Drive on pve1 |
| **Remote Access** | ✅ Active | Tailscale operational with DNS |
| **DNS** | ✅ Working | Pi-hole operational, Tailscale DNS configured |
| **UniFi WiFi** | ✅ Operational | 3 APs, 3 SSIDs, controller on CT107 |
| **UPS** | ✅ Protected | CyberPower 1600VA, ~17% load |

## 📋 UPS Status

| Metric | Value |
|--------|-------|
| **Model** | CyberPower CP1600EPFCLCD-AU |
| **Status** | OL (Online - Mains Power) |
| **Load** | ~17% (~142W) |
| **Battery** | 100% |
| **Est. Runtime** | ~34-45 minutes |
| **NUT Master** | pve1 (USB connected) |
| **NUT Slaves** | pve2, pve3 |

### Protected Equipment
- ✅ pve1, pve2, pve3 (NUT monitored)
- ✅ OPNsense router
- ✅ UniFi Switch
- ✅ G-Drive backup storage (connected to pve1)

### Quick UPS Check
```bash
ssh root@192.168.10.11 "upsc cyberpower@localhost | grep -E '^(ups.status|ups.load|battery.charge|battery.runtime):'"
```

## 💾 Backup Storage

| Property | Value |
|----------|-------|
| **Device** | G-Drive USB-C (10TB) |
| **Model** | HGST HDH5C1010ALE604 |
| **Connected to** | pve1 via USB-C |
| **Mount Point** | /mnt/backup-storage |
| **Proxmox Storage** | backup-gdrive |
| **Capacity** | 9.1TB (8.6TB usable) |
| **Current Usage** | ~230MB (test backup) |

### Quick Backup Check
```bash
ssh root@192.168.10.11 "df -h /mnt/backup-storage && ls -lht /mnt/backup-storage/proxmox-backups/dump/ | head -5"
```

## 🔴 Active Issues

### 1. ProtonVPN Blocks Tailscale DNS
- **Impact:** Low - only affects remote access with ProtonVPN active
- **Cause:** ProtonVPN's DNS leak protection intercepts all DNS queries
- **Workaround:** Disconnect ProtonVPN when accessing homelab remotely
- **Status:** Known limitation, documented in troubleshooting guide

## 🟢 Recently Resolved

### Backup Storage Migration (COMPLETED 2025-12-05)
- **Change:** Migrated backup storage from Mac Pro + Pegasus to G-Drive USB-C
- **Why:** Mac Pro was overkill for backup needs (~340W vs ~5W), complex Thunderbolt/stex driver issues
- **Actions Taken:**
  1. Unmounted SSHFS on all 3 nodes
  2. Shutdown Mac Pro and Pegasus array
  3. Connected G-Drive to pve1
  4. Formatted as ext4 with label `backup-storage`
  5. Created systemd mount at `/mnt/backup-storage`
  6. Added to Proxmox as `backup-gdrive` storage
  7. Updated backup job to use new storage
  8. Added CT107 (UniFi) to backup job
  9. Removed old `macpro-backups` storage
  10. Removed SSHFS mount units from all nodes
- **Status:** ✅ Fully operational, test backup successful

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
| 2025-12-05 | Migrated backup storage to G-Drive on pve1 | Simpler, lower power backup system |
| 2025-12-05 | Retired Mac Pro + Pegasus array | Reduced power consumption ~335W |
| 2025-12-05 | Added CT107 (UniFi) to backup job | All containers now backed up |
| 2025-12-03 | Fixed HomeNet SSID not broadcasting from AP-Upstairs | HomeNet now visible from all locations |
| 2025-12-03 | Added OPNsense static route for Tailscale (100.64.0.0/10) | Enables return traffic for Tailscale clients |
| 2025-12-03 | Configured Tailscale DNS (Pi-hole + homelab.local) | .homelab.local domains resolve remotely |
| 2025-12-02 | Rack migration completed | All hardware in new rack |

## 📝 Next Actions

1. **Monitor:** First automated backup to G-Drive tonight at 02:00
2. **Document:** Update GitHub repository with latest changes
3. **Consider:** Offsite backup solution (now that local backup is simpler)
4. **Consider:** What to do with retired Mac Pro + Pegasus hardware

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
*Last verified: 2025-12-05*