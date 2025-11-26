# 🔧 Command Reference Guide

**Last Updated:** 2025-11-24  
**Purpose:** Single source for ALL homelab commands  
**No command duplication in other documents - reference this file**

## 📚 Table of Contents

1. [SSH Access](#ssh-access)
2. [Cluster Management](#cluster-management)
3. [Container Operations](#container-operations)
4. [Service Management](#service-management)
5. [Network Diagnostics](#network-diagnostics)
6. [Storage & Ceph](#storage--ceph)
7. [Backup Operations](#backup-operations)
8. [Monitoring & Health](#monitoring--health)
9. [Troubleshooting](#troubleshooting)
10. [Emergency Procedures](#emergency-procedures)

---

## 🔐 SSH Access

### Direct Access to Nodes
```bash
# Proxmox nodes
ssh root@192.168.10.11    # pve1
ssh root@192.168.10.12    # pve2
ssh root@192.168.10.13    # pve3

# Mac Pro NAS (via ProxyJump)
ssh -J root@192.168.10.11 xavier@192.168.30.20

# Or with SSH config
ssh macpro
```

### SSH Config (~/.ssh/config)
```bash
Host pve1
    HostName 192.168.10.11
    User root

Host pve2
    HostName 192.168.10.12
    User root

Host pve3
    HostName 192.168.10.13
    User root
    
Host macpro
    HostName 192.168.30.20
    User xavier
    ProxyJump pve1
```

---

## 🎮 Cluster Management

### Cluster Status
```bash
# Check cluster status
pvecm status

# View cluster nodes
pvecm nodes

# Check quorum
pvecm expected 3

# View cluster resources
pvesh get /cluster/resources

# Check cluster log
journalctl -u pve-cluster -n 50
```

### Ceph Management
```bash
# Ceph status
ceph -s
ceph health detail

# OSD status
ceph osd tree
ceph osd df

# Pool status
ceph df
ceph osd pool ls detail

# Monitor status
ceph mon stat

# Performance stats
ceph osd perf
```

### Maintenance Mode
```bash
# Set Ceph maintenance flags (before shutdown)
ceph osd set noout
ceph osd set nobackfill
ceph osd set norebalance

# Remove flags (after startup)
ceph osd unset noout
ceph osd unset nobackfill
ceph osd unset norebalance
```

---

## 📦 Container Operations

### Basic Container Management
```bash
# List all containers
pct list

# Start/Stop/Restart container
pct start <CTID>
pct stop <CTID>
pct restart <CTID>

# Enter container console
pct enter <CTID>

# Execute command in container
pct exec <CTID> -- <command>

# Check container status
pct status <CTID>

# View container config
pct config <CTID>
```

### Container Configuration
```bash
# Set container resources
pct set <CTID> -cores 2
pct set <CTID> -memory 2048
pct set <CTID> -swap 2048

# Configure network
pct set <CTID> -net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.XX/24,gw=192.168.40.1

# Enable auto-start
pct set <CTID> -onboot 1

# Add mount point
pct set <CTID> -mp0 /host/path,mp=/container/path
```

### Container Creation
```bash
# Create new container
pct create <CTID> local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname <hostname> \
  --cores 2 \
  --memory 2048 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:20 \
  --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.XX/24,gw=192.168.40.1 \
  --nameserver 192.168.40.53 \
  --searchdomain homelab.local \
  --onboot 1 \
  --unprivileged 1
```

### Docker in LXC
```bash
# Configure container for Docker (add to /etc/pve/lxc/<CTID>.conf)
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:

# Inside container - install Docker
curl -fsSL https://get.docker.com | sh
apt install -y docker-compose-plugin
systemctl enable docker
```

---

## 🚀 Service Management

### Service Control by Container

#### CT100 - Tailscale
```bash
# Check status
pct exec 100 -- tailscale status
pct exec 100 -- tailscale netcheck

# Restart service
pct exec 100 -- systemctl restart tailscaled

# View routes
pct exec 100 -- tailscale debug routes
```

#### CT101 - Pi-hole
```bash
# Service control
pct exec 101 -- pihole status
pct exec 101 -- pihole restartdns
pct exec 101 -- systemctl restart pihole-FTL

# Update gravity
pct exec 101 -- pihole -g

# View logs
pct exec 101 -- pihole -t  # tail log

# Query logs
pct exec 101 -- pihole -q <domain>

# Whitelist/Blacklist
pct exec 101 -- pihole -w <domain>  # whitelist
pct exec 101 -- pihole -b <domain>  # blacklist
```

#### CT102 - Nginx Proxy Manager
```bash
# Docker commands
pct exec 102 -- docker ps
pct exec 102 -- docker compose -f /opt/nginx-proxy-manager/docker-compose.yml restart
pct exec 102 -- docker logs nginx-proxy-manager_app_1 --tail 50

# View nginx config
pct exec 102 -- docker exec nginx-proxy-manager_app_1 nginx -T
```

#### CT103 - Uptime Kuma
```bash
# Docker commands
pct exec 103 -- docker ps
pct exec 103 -- docker compose -f /opt/uptime-kuma/docker-compose.yml restart
pct exec 103 -- docker logs uptime-kuma --tail 50

# Restart container
pct exec 103 -- docker restart uptime-kuma
```

#### CT104 - Nextcloud
```bash
# Apache control
pct exec 104 -- systemctl restart apache2
pct exec 104 -- systemctl status apache2

# Nextcloud occ commands
pct exec 104 -- sudo -u www-data php /var/www/nextcloud/occ status
pct exec 104 -- sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --on
pct exec 104 -- sudo -u www-data php /var/www/nextcloud/occ maintenance:mode --off
pct exec 104 -- sudo -u www-data php /var/www/nextcloud/occ files:scan --all
pct exec 104 -- sudo -u www-data php /var/www/nextcloud/occ app:list
```

#### CT105 - MariaDB
```bash
# Service control
pct exec 105 -- systemctl restart mariadb
pct exec 105 -- systemctl status mariadb

# Database access
pct exec 105 -- mysql -u root -p
pct exec 105 -- mysql -u nextcloud -p nextcloud

# Backup database
pct exec 105 -- mysqldump nextcloud > /tmp/nextcloud_backup.sql
```

#### CT106 - Redis (Not operational)
```bash
# Check status (will fail due to systemd issues)
pct exec 106 -- systemctl status redis-server
```

#### CT112 - n8n
```bash
# Docker commands
pct exec 112 -- docker ps
pct exec 112 -- docker compose -f /opt/n8n/docker-compose.yml restart
pct exec 112 -- docker logs n8n --tail 50
pct exec 112 -- docker stats n8n
```

---

## 🌐 Network Diagnostics

### Basic Connectivity
```bash
# Test connectivity
ping -c 2 192.168.10.1     # Management gateway
ping -c 2 192.168.40.1     # Services gateway
ping -c 2 192.168.40.53    # Pi-hole
ping -c 2 8.8.8.8          # Internet

# Traceroute
traceroute 8.8.8.8
traceroute 192.168.40.53
```

### DNS Testing
```bash
# Test DNS resolution
nslookup google.com 192.168.40.53
nslookup pve1.homelab.local 192.168.40.53

# Alternative DNS test
dig @192.168.40.53 google.com
dig @192.168.40.53 pve1.homelab.local

# Check Pi-hole DNS entries
pct exec 101 -- grep homelab.local /etc/pihole/pihole.toml
```

### VLAN Testing
```bash
# View VLAN interfaces (on Proxmox node)
ip addr show | grep vmbr0
ip link show | grep vlan

# Test inter-VLAN routing
ping -c 1 -I vmbr0.10 192.168.40.53
ping -c 1 -I vmbr0.40 192.168.10.1
```

### Port Testing
```bash
# Test service ports
nc -zv 192.168.40.53 80     # Pi-hole web
nc -zv 192.168.40.22 81     # NPM admin
nc -zv 192.168.40.23 3001   # Uptime Kuma
nc -zv 192.168.40.31 80     # Nextcloud
nc -zv 192.168.40.32 3306   # MariaDB
nc -zv 192.168.40.61 5678   # n8n

# Test through proxy
curl -I http://nginx.homelab.local
curl -I http://status.homelab.local
curl -I http://cloud.homelab.local
```

### Network Performance
```bash
# Bandwidth test between nodes
# On target node
iperf3 -s

# On source node
iperf3 -c <target-ip>

# MTU path discovery
ping -M do -s 1472 8.8.8.8
```

---

## 💾 Storage & Ceph

### Storage Status
```bash
# Local storage
df -h
lsblk
pvesm status

# Ceph storage
ceph df
rbd ls vm-storage
pvesm list vm-storage
```

### Mac Pro NAS Management
```bash
# Check mount status (on Proxmox nodes)
df -h /mnt/macpro
mountpoint -q /mnt/macpro && echo "Mounted" || echo "Not mounted"

# Restart mount
systemctl restart mnt-macpro.mount
systemctl status mnt-macpro.mount

# Manual mount
mount /mnt/macpro

# Check Mac Pro storage (via SSH)
ssh macpro "df -h /storage"
ssh macpro "ls -la /storage/"
```

---

## 💼 Backup Operations

### Manual Backup
```bash
# Backup single container
vzdump <CTID> --storage macpro-backups --mode snapshot --compress zstd

# Backup with notes
vzdump <CTID> --storage macpro-backups --mode snapshot --compress zstd \
  --notes "Pre-upgrade backup $(date +%Y%m%d)"

# Backup multiple containers
vzdump 100,101,102 --storage macpro-backups --mode snapshot --compress zstd

# Backup all containers
for ct in $(pct list | awk 'NR>1 {print $1}'); do
  vzdump $ct --storage macpro-backups --mode snapshot --compress zstd
done
```

### Backup Management
```bash
# List all backups
pvesm list macpro-backups

# List backups for specific container
ls -lht /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-*

# Check backup job configuration
pvesh get /cluster/backup/backup-6963fa17-187b

# Manually run scheduled backup
pvesh create /nodes/pve1/vzdump --vmid 100,101,102,103,104,105,106,112 --storage macpro-backups
```

### Restore Operations
```bash
# Restore container (will destroy existing!)
pct restore <CTID> /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst

# Restore to different CTID
pct restore <NEW-CTID> /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<OLD-CTID>-<DATE>.tar.zst

# Restore to different node
pct restore <CTID> /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst --target pve2
```

---

## 📊 Monitoring & Health

### Quick Health Check
```bash
# Run comprehensive health check
./scripts/daily-health.sh

# Manual health checks
pvecm status | grep -E "Quorum|Total"
ceph -s | head -5
pct list | grep running | wc -l
df -h /mnt/macpro
```

### Resource Monitoring
```bash
# CPU and Memory
top
htop
free -h
vmstat 1

# Disk I/O
iostat -x 1
iotop

# Network
iftop
nethogs
ss -tulpn

# Container resources
pct exec <CTID> -- free -h
pct exec <CTID> -- df -h
pct exec <CTID> -- top -bn1 | head -20
```

### Log Viewing
```bash
# System logs
journalctl -xe
journalctl -u pve-cluster -n 50
journalctl -u pveproxy -n 50

# Container logs
pct exec <CTID> -- journalctl -xe -n 50

# Ceph logs
journalctl -u ceph-mon@pve1 -n 50
journalctl -u ceph-osd@0 -n 50

# Service-specific logs
tail -f /var/log/syslog
tail -f /var/log/pve/tasks/index
```

---

## 🔍 Troubleshooting

### Container Issues
```bash
# Container won't start
pct start <CTID> --debug
journalctl -u pve-container@<CTID>

# Check container filesystem
pct fsck <CTID>

# Force stop container
pct stop <CTID> --kill

# Unlock container
pct unlock <CTID>
```

### Network Issues
```bash
# Check network configuration
ip addr show
ip route show
iptables -L -n -v

# Restart networking
systemctl restart networking

# Check OPNsense from node
ping 192.168.10.1
curl -k https://192.168.10.1
```

### DNS Issues
```bash
# Test DNS servers
nslookup google.com 192.168.40.53  # Pi-hole
nslookup google.com 192.168.10.1   # OPNsense
nslookup google.com 8.8.8.8        # Google

# Fix Pi-hole DNS entry
pct exec 101 -- sed -i 's/192.168.40.53 pihole.homelab.local/192.168.40.22 pihole.homelab.local/' /etc/pihole/pihole.toml
pct exec 101 -- systemctl restart pihole-FTL
```

### Service Not Accessible
```bash
# Check if service is running
pct exec <CTID> -- systemctl status <service>

# Check if port is listening
pct exec <CTID> -- ss -tulpn | grep <port>

# Test direct access
curl http://192.168.40.XX:<port>

# Check proxy logs
pct exec 102 -- docker logs nginx-proxy-manager_app_1 --tail 50
```

---

## 🚨 Emergency Procedures

### Emergency Shutdown
```bash
# Quick shutdown all containers
for ct in 112 104 105 103 102 101 100; do pct stop $ct; done

# Set Ceph maintenance
ceph osd set noout && ceph osd set nobackfill && ceph osd set norebalance

# Shutdown nodes
ssh root@192.168.10.13 "shutdown -h now"
sleep 30
ssh root@192.168.10.12 "shutdown -h now"
sleep 30
ssh root@192.168.10.11 "shutdown -h now"
```

### Node Failure Recovery
```bash
# If node fails, adjust quorum temporarily
pvecm expected 2

# Force quorum if needed
pvecm expected 1

# After node recovery, reset
pvecm expected 3
```

### Backup Recovery Test
```bash
# Test restore to temporary CTID
pct restore 999 /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst

# Start and verify
pct start 999
pct exec 999 -- systemctl status

# If successful, destroy test
pct stop 999
pct destroy 999
```

### Network Recovery
```bash
# Restart all network services
systemctl restart networking
systemctl restart pve-cluster
systemctl restart pveproxy

# Reset firewall if locked out
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
```

---

## 📝 Quick Reference Tables

### Container CTIDs
```
100 = Tailscale
101 = Pi-hole
102 = Nginx Proxy Manager
103 = Uptime Kuma
104 = Nextcloud
105 = MariaDB
106 = Redis (not operational)
112 = n8n
```

### Important IPs
```
192.168.10.1  = OPNsense
192.168.10.11 = pve1
192.168.10.12 = pve2
192.168.10.13 = pve3
192.168.30.20 = Mac Pro NAS
192.168.40.53 = Pi-hole
192.168.40.22 = Nginx Proxy Manager
```

### Service Ports
```
22    = SSH
53    = DNS (Pi-hole)
80    = HTTP
81    = NPM Admin
443   = HTTPS
3001  = Uptime Kuma
3306  = MariaDB
5678  = n8n
6379  = Redis
8006  = Proxmox Web UI
```

### Common Paths
```
/etc/pve/                     = Proxmox configs
/etc/pve/lxc/                 = Container configs
/mnt/macpro/                  = Mac Pro mount
/mnt/macpro/proxmox-backups/  = Backup location
/var/log/                     = System logs
```

---

*This is the single command reference - do not duplicate commands elsewhere*  
*For specific procedures, reference this file's relevant section*