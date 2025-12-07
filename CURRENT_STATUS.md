# 📊 Current Homelab Status

**Last Updated:** 2025-12-07  
**Overall Health:** 🟢 Operational  
**Uptime:** Stable  
**Last Change:** IoT WiFi migration completed, Pi moved to wired Ethernet

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
| **UniFi WiFi** | ✅ Operational | 3 APs, 4 SSIDs, controller on CT107 |
| **UPS** | ✅ Protected | CyberPower 1600VA, ~17% load |
| **ISP WiFi** | 🔴 Disabled | All devices migrated to UniFi |

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

### ISP WiFi Migration (COMPLETED 2025-12-07)
- **Change:** Migrated all IoT devices from ISP router WiFi to UniFi WiFi
- **Why:** Consolidate all WiFi under UniFi management, prepare to disable ISP WiFi
- **Actions Taken:**
  1. Created new WiFi SSID "iiNetBC09FB" on VLAN 60 (IoT) matching ISP credentials
  2. Configured WPA2 security with 2.4GHz + 5GHz bands
  3. Broadcast from AP-Upstairs and AP-Downstairs
  4. Disabled ISP WiFi networks
  5. All IoT devices automatically reconnected to new UniFi network
- **Status:** ✅ All devices migrated successfully

### Pi (pifrontdoor) Wired Migration (COMPLETED 2025-12-07)
- **Change:** Moved Home Assistant Pi from WiFi to wired Ethernet
- **Why:** More reliable connection, WiFi no longer needed
- **Previous Config:** WiFi on ISP network (10.1.1.63 static)
- **New Config:** Wired Ethernet on Default VLAN (192.168.1.146 DHCP reserved)
- **Actions Taken:**
  1. Disabled WiFi interface (wlan0) on Home Assistant OS
  2. Enabled Ethernet interface (enu1u1u1) with DHCP
  3. Connected via passive switch on Port 7
  4. Created DHCP reservation in OPNsense (MAC: B8:27:EB:01:E3:C3)
  5. Updated Tailscale advertised routes to include 192.168.1.0/24
  6. Verified remote access via Tailscale
- **Access:** http://192.168.1.146:8123 or http://pifrontdoor.local:8123
- **Status:** ✅ Fully operational, accessible locally and via Tailscale

### Backup Storage Migration (COMPLETED 2025-12-05)
- **Change:** Migrated backup storage from Mac Pro + Pegasus to G-Drive USB-C
- **Why:** Mac Pro was overkill for backup needs (~340W vs ~5W), complex Thunderbolt/stex driver issues
- **Status:** ✅ Fully operational, test backup successful

### DNS over Tailscale (RESOLVED 2025-12-03)
- **Issue:** DNS queries to Pi-hole timed out when accessing homelab via Tailscale
- **Solution:** Added static route in OPNsense + configured Tailscale admin DNS
- **Status:** ✅ Fully working (when ProtonVPN disconnected)

## 🔄 Recent Changes

| Date | Change | Impact |
|------|--------|--------|
| 2025-12-07 | Migrated IoT devices to UniFi WiFi (iiNetBC09FB SSID) | ISP WiFi can now be disabled |
| 2025-12-07 | Moved Pi (pifrontdoor) to wired Ethernet | More reliable Home Assistant connection |
| 2025-12-07 | Added 192.168.1.0/24 to Tailscale routes | Remote access to Default VLAN devices |
| 2025-12-07 | Created DHCP reservation for pifrontdoor | Static IP 192.168.1.146 |
| 2025-12-07 | Disabled ISP WiFi networks | All WiFi now managed by UniFi |
| 2025-12-05 | Migrated backup storage to G-Drive on pve1 | Simpler, lower power backup system |
| 2025-12-05 | Retired Mac Pro + Pegasus array | Reduced power consumption ~335W |
| 2025-12-03 | Fixed HomeNet SSID not broadcasting from AP-Upstairs | HomeNet now visible from all locations |
| 2025-12-03 | Configured Tailscale DNS (Pi-hole + homelab.local) | .homelab.local domains resolve remotely |

## 📝 Next Actions

1. **Optional:** Add Pi-hole DNS entry for pifrontdoor.homelab.local → 192.168.1.146
2. **Monitor:** Verify all IoT devices remain connected to new WiFi
3. **Consider:** Adding Home Assistant to Uptime Kuma monitoring
4. **Future:** Plan Home Assistant migration to Proxmox cluster

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

### DHCP Static Mappings (Services → DHCPv4 → LAN)
| MAC Address | IP Address | Hostname | Description |
|-------------|------------|----------|-------------|
| B8:27:EB:01:E3:C3 | 192.168.1.146 | pifrontdoor | Home Assistant Pi |

## 🌐 Tailscale Configuration

**Admin Panel:** https://login.tailscale.com/admin/dns

### DNS Settings
| Setting | Value |
|---------|-------|
| Global Nameserver | 192.168.40.53 (Pi-hole) |
| Search Domain | homelab.local |
| Override DNS servers | ✅ Enabled |

### Advertised Routes (CT100)
| Network | Purpose |
|---------|---------|
| 192.168.10.0/24 | Management VLAN |
| 192.168.40.0/24 | Services VLAN |
| 192.168.1.0/24 | Default VLAN (includes pifrontdoor) |
| 10.1.1.0/24 | ISP network (legacy IoT) |

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

## 🏠 Home Assistant (pifrontdoor)

| Property | Value |
|----------|-------|
| **Hardware** | Raspberry Pi |
| **OS** | Home Assistant OS 16.3 |
| **HA Core** | 2025.12.1 |
| **Connection** | Wired Ethernet (enu1u1u1) |
| **IP Address** | 192.168.1.146 (DHCP reserved) |
| **MAC Address** | B8:27:EB:01:E3:C3 |
| **Switch Port** | Port 7 (via passive switch) |
| **VLAN** | Default (1) |
| **Access URL** | http://192.168.1.146:8123 |
| **mDNS** | http://pifrontdoor.local:8123 |
| **WiFi** | Disabled |

---

*Update this file after any infrastructure changes*  
*Last verified: 2025-12-07*