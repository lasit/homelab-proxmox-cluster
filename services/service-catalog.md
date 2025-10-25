# 🚀 Service Catalog

**Last Updated:** October 25, 2025  
**Purpose:** Available services for deployment on the Proxmox cluster

## Deployment Priority Tiers

### 🥇 Tier 1: Essential Infrastructure
*Deploy these first - they support everything else*

#### Pi-hole
**Purpose:** Network-wide ad blocking and DNS management  
**Resources:** 1 CPU, 1GB RAM, 8GB disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.21  
**Container:** LXC recommended  
**Benefits:**
- Blocks ads on all devices
- Faster browsing
- Reduced bandwidth usage
- Custom DNS entries for local services

#### Nginx Proxy Manager
**Purpose:** Reverse proxy with automatic SSL certificates  
**Resources:** 1 CPU, 1GB RAM, 10GB disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.22  
**Container:** LXC or Docker  
**Benefits:**
- Access services via domain names
- Automatic HTTPS with Let's Encrypt
- Single entry point for services
- WebSocket support

#### Uptime Kuma
**Purpose:** Service monitoring and alerting  
**Resources:** 1 CPU, 512MB RAM, 5GB disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.23  
**Container:** Docker recommended  
**Benefits:**
- Monitor all services
- Email/push notifications
- Status page for family
- Historical uptime data

### 🥈 Tier 2: Backup & Security
*Deploy second - protect your work*

#### Proxmox Backup Server
**Purpose:** Automated VM and container backups  
**Resources:** 2 CPU, 4GB RAM, 100GB+ disk  
**VLAN:** 10 (Management)  
**Suggested IP:** 192.168.10.21  
**Type:** VM required  
**Benefits:**
- Incremental backups
- Deduplication
- Encryption
- Easy restoration

#### Vaultwarden
**Purpose:** Self-hosted password manager (Bitwarden compatible)  
**Resources:** 1 CPU, 512MB RAM, 5GB disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.24  
**Container:** Docker recommended  
**Benefits:**
- Bitwarden apps compatible
- Family password sharing
- 2FA support
- Offline access

#### Tailscale
**Purpose:** Secure remote access VPN  
**Resources:** Minimal (runs on nodes)  
**VLAN:** All (subnet router)  
**Installation:** On Proxmox nodes directly  
**Benefits:**
- Zero-config VPN
- Works through CGNAT
- Access all services remotely
- No port forwarding needed

### 🥉 Tier 3: Productivity & Integration
*Quality of life improvements*

#### Home Assistant
**Purpose:** Smart home automation hub  
**Resources:** 2 CPU, 4GB RAM, 32GB disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.30  
**Type:** VM recommended (or migrate existing)  
**Special Requirements:**
- Bridge to 10.1.1.x network for IoT devices
- USB passthrough for Zigbee/Z-Wave (if needed)
**Benefits:**
- Unified smart home control
- Automations
- Energy monitoring
- Local control

#### Nextcloud
**Purpose:** Self-hosted cloud storage and collaboration  
**Resources:** 2 CPU, 4GB RAM, 50GB+ disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.31  
**Type:** VM or Container  
**Benefits:**
- File sync across devices
- Calendar/contacts
- Document collaboration
- Photo backup

#### Paperless-ngx
**Purpose:** Document management system  
**Resources:** 2 CPU, 2GB RAM, 50GB+ disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.32  
**Container:** Docker recommended  
**Benefits:**
- OCR scanning
- Tag-based organization
- Full-text search
- Mobile apps

### 🎯 Tier 4: Media & Entertainment
*Optional - if you have media to serve*

#### Jellyfin
**Purpose:** Media server (movies, TV, music)  
**Resources:** 2-4 CPU, 4GB RAM, storage varies  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.40  
**Type:** VM or Container  
**Benefits:**
- No license fees
- Hardware transcoding
- Mobile apps
- Live TV support

#### Immich
**Purpose:** Self-hosted Google Photos alternative  
**Resources:** 2 CPU, 4GB RAM, 100GB+ disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.41  
**Container:** Docker recommended  
**Benefits:**
- AI face recognition
- Mobile auto-backup
- Shared albums
- Map view

#### Plex
**Purpose:** Premium media server  
**Resources:** 2-4 CPU, 4GB RAM, storage varies  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.42  
**Type:** VM or Container  
**Note:** Requires Plex Pass for some features  
**Benefits:**
- Polished interface
- Wide device support
- Remote access built-in
- Live TV/DVR

### 🔧 Tier 5: Development & Tools
*For power users*

#### GitLab CE
**Purpose:** Self-hosted Git repository and CI/CD  
**Resources:** 4 CPU, 8GB RAM, 50GB+ disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.50  
**Type:** VM recommended  
**Benefits:**
- Private repositories
- CI/CD pipelines
- Issue tracking
- Wiki documentation

#### Portainer
**Purpose:** Docker management interface  
**Resources:** 1 CPU, 512MB RAM, 10GB disk  
**VLAN:** 10 (Management)  
**Suggested IP:** 192.168.10.25  
**Container:** Docker  
**Benefits:**
- Manage all Docker hosts
- Easy container deployment
- Stack templates
- Multi-node support

#### Code-Server
**Purpose:** VS Code in the browser  
**Resources:** 2 CPU, 2GB RAM, 20GB disk  
**VLAN:** 40 (Services)  
**Suggested IP:** 192.168.40.51  
**Container:** Docker  
**Benefits:**
- Code from anywhere
- Consistent environment
- Extensions support
- Terminal access

### 📊 Tier 6: Monitoring & Analytics
*Know what's happening*

#### Prometheus + Grafana
**Purpose:** Metrics collection and visualization  
**Resources:** 2 CPU, 2GB RAM, 50GB disk  
**VLAN:** 10 (Management)  
**Suggested IP:** 192.168.10.26-27  
**Container:** Docker stack  
**Benefits:**
- Beautiful dashboards
- Alert rules
- Long-term metrics
- Proxmox integration

#### Graylog
**Purpose:** Centralized log management  
**Resources:** 4 CPU, 8GB RAM, 100GB+ disk  
**VLAN:** 10 (Management)  
**Suggested IP:** 192.168.10.28  
**Type:** VM recommended  
**Benefits:**
- Search all logs
- Alert on patterns
- Compliance reporting
- Dashboard views

## 📦 Container Templates

### Available LXC Templates
- **Debian 12** - Lightweight and stable
- **Ubuntu 22.04 LTS** - Well-supported
- **Alpine Linux** - Minimal footprint
- **Turnkey Linux** - Pre-configured apps

### Docker Hosting Options

#### Option 1: Docker in LXC
```bash
# Create privileged LXC container
# Enable nesting and keyctl features
# Install Docker inside
```

#### Option 2: Docker in VM
```bash
# Create lightweight Debian VM
# Install Docker and Docker Compose
# More isolated but uses more resources
```

## 🔄 Service Dependencies

### Dependency Chart
```
Tailscale (Remote Access)
    ↓
Pi-hole (DNS)
    ↓
Nginx Proxy Manager (Routing)
    ↓
All Other Services
```

### Recommended Deployment Order

#### Weekend 1 (Foundation)
1. Tailscale on nodes
2. Pi-hole for DNS
3. Nginx Proxy Manager
4. Uptime Kuma

#### Weekend 2 (Protection)
5. Proxmox Backup Server
6. Configure automated backups
7. Vaultwarden
8. Test restore procedures

#### Weekend 3 (Migration)
9. Home Assistant
10. Ensure IoT bridge working
11. Migrate automations
12. Decommission old instance

#### Month 2 (Enhancement)
13. Nextcloud or Immich
14. Paperless-ngx
15. Jellyfin (if needed)
16. Monitoring stack

## 💾 Storage Planning

### Storage Requirements by Service Type

#### Low Storage (<10GB)
- Pi-hole
- Nginx Proxy Manager
- Uptime Kuma
- Vaultwarden
- Portainer

#### Medium Storage (10-50GB)
- Home Assistant
- Code-Server
- Grafana/Prometheus

#### High Storage (50GB+)
- Proxmox Backup Server
- Nextcloud
- Paperless-ngx
- Immich
- Jellyfin/Plex
- GitLab

### Recommended Storage Strategy
```
Ceph Pool (vm-storage): 172GB available
├── Critical Services: 50GB
├── Backups: 50GB
├── Media/Files: 50GB
└── Reserve: 22GB
```

## 🌐 Network Planning

### Service Grouping by VLAN

#### VLAN 10 (Management)
- Proxmox Backup Server
- Monitoring tools
- Portainer

#### VLAN 40 (Services)
- All user-facing services
- Home Assistant
- Media servers
- Productivity apps

### DNS Entries (Pi-hole)
```
# Local DNS Records
proxmox.homelab.local → 192.168.10.11
pihole.homelab.local → 192.168.40.21
nginx.homelab.local → 192.168.40.22
home.homelab.local → 192.168.40.30
vault.homelab.local → 192.168.40.24
```

## 🔐 Security Considerations

### For Each Service
1. **Change default passwords**
2. **Enable 2FA where available**
3. **Regular updates**
4. **Backup before updates**
5. **Use HTTPS via Nginx**
6. **Firewall rules in OPNsense**

### Service Isolation
- Management tools: VLAN 10 only
- User services: VLAN 40 with rules
- No direct internet exposure
- All access through Nginx proxy

## 📊 Resource Planning

### Current Cluster Capacity
- **CPU:** 24 cores available
- **RAM:** 96GB available
- **Storage:** 172GB Ceph + 600GB local

### Typical Usage (All Tier 1-3 services)
- **CPU:** ~8-10 cores used
- **RAM:** ~20-25GB used
- **Storage:** ~100GB used
- **Headroom:** Plenty for growth

## 🚨 Service-Specific Notes

### Home Assistant Migration
1. Backup current instance
2. Create new VM on VLAN 40
3. Configure bridge to 10.1.1.x
4. Restore backup
5. Test all automations
6. Update device IPs if needed
7. Decommission old instance

### Proxmox Backup Server
1. Use dedicated VM (not container)
2. Create separate storage for backups
3. Configure prune schedules
4. Test restore regularly
5. Consider off-site sync

### Media Server Considerations
- Hardware transcoding needs GPU passthrough
- Large storage requirements
- Consider separate NAS later
- Network bandwidth for streaming

---

**Next Step:** Start with [Tier 1 services](../services/deployment-priority.md) for immediate value!

**Questions?** Check service-specific guides in `/services/configs/`
