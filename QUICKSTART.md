# ⚡ Quick Start Guide

Common tasks and commands for daily homelab operations.

## 🔍 Health Checks

### Quick System Status
```bash
# Run comprehensive health check
./scripts/daily-health.sh

# Check cluster status
ssh root@192.168.10.11 "pvecm status"

# Check Ceph health
ssh root@192.168.10.11 "ceph -s"

# Check all containers
ssh root@192.168.10.11 "pct list"
```

### Service Status
```bash
# Test all service URLs
for url in nginx status cloud automation; do
  echo -n "$url.homelab.local: "
  curl -s -o /dev/null -w "%{http_code}\n" http://$url.homelab.local
done

# Check specific container
ssh root@192.168.10.11 "pct status 101"  # Pi-hole
```

## 🔧 Common Operations

### Container Management
```bash
# Start/stop container
ssh root@192.168.10.11 "pct start 100"   # Start
ssh root@192.168.10.11 "pct stop 100"    # Stop
ssh root@192.168.10.11 "pct restart 100" # Restart

# Enter container
ssh root@192.168.10.11 "pct enter 101"   # Enter Pi-hole

# Check container resources
ssh root@192.168.10.11 "pct config 104 | grep -E 'cores|memory'"
```

### Service Access
```bash
# Direct container access (bypass proxy)
http://192.168.40.53/admin    # Pi-hole admin
http://192.168.40.22:81       # NPM admin
http://192.168.40.23:3001     # Uptime Kuma
http://192.168.40.31          # Nextcloud
http://192.168.40.61:5678     # n8n

# Via proxy (normal access)
http://pihole.homelab.local   # Pi-hole (needs DNS fix)
http://nginx.homelab.local    # NPM
http://status.homelab.local   # Uptime Kuma
http://cloud.homelab.local    # Nextcloud
http://automation.homelab.local # n8n
```

### Backup Operations
```bash
# Manual backup of specific container
ssh root@192.168.10.11 "vzdump 104 --storage macpro-backups --mode snapshot --compress zstd"

# Check recent backups
ssh root@192.168.10.11 "ls -lht /mnt/macpro/proxmox-backups/dump/ | head -10"

# Verify Mac Pro mount
ssh root@192.168.10.11 "df -h /mnt/macpro"
```

## 🚨 Troubleshooting

### DNS Issues
```bash
# Test DNS resolution
nslookup google.com 192.168.40.53

# Check Pi-hole status
ssh root@192.168.10.11 "pct exec 101 -- pihole status"

# Restart Pi-hole FTL
ssh root@192.168.10.11 "pct exec 101 -- systemctl restart pihole-FTL"
```

### Service Not Accessible
```bash
# Check if container is running
ssh root@192.168.10.11 "pct status <CTID>"

# Check service port
nc -zv 192.168.40.22 81  # NPM admin port

# Check nginx proxy logs
ssh root@192.168.10.11 "pct exec 102 -- docker logs nginx-proxy-manager_app_1"
```

### Mac Pro NAS Issues
```bash
# Check if Mac Pro responds
ping 192.168.30.20

# Check SSHFS mount
ssh root@192.168.10.11 "systemctl status mnt-macpro.mount"

# Remount if needed
ssh root@192.168.10.11 "systemctl restart mnt-macpro.mount"
```

## 📊 Quick Reference

### Container IDs
```
100 - Tailscale (VPN)
101 - Pi-hole (DNS)
102 - Nginx Proxy Manager
103 - Uptime Kuma (Monitoring)
104 - Nextcloud (Cloud Storage)
105 - MariaDB (Database)
106 - Redis (Cache - not running)
112 - n8n (Automation)
```

### Management IPs
```
192.168.10.1  - OPNsense
192.168.10.11 - pve1
192.168.10.12 - pve2
192.168.10.13 - pve3
192.168.30.20 - Mac Pro NAS
192.168.40.53 - Pi-hole
```

### Important Paths
```
/mnt/macpro/proxmox-backups/dump/  # Backup location
/etc/pve/lxc/                      # Container configs
/var/log/                          # System logs
```

## 🔐 Access Credentials

See password manager or [secure documentation] for:
- Proxmox root passwords
- Service admin accounts  
- Database credentials
- API keys

## 🆘 Emergency Procedures

### Cluster Node Down
```bash
# Check node status
ssh root@192.168.10.12 "pvecm nodes"

# If node needs restart
ssh root@192.168.10.11 "pvecm expected 2"  # Temporary quorum adjustment
```

### Complete Shutdown
See [Power Management Guide](./docs/guides/power-management.md)

### Disaster Recovery
See [Disaster Recovery Guide](./docs/guides/disaster-recovery.md)