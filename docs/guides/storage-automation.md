# 🗄️ Storage & Automation Services Deployment Guide

**Last Updated:** 2025-11-25  
**Services Covered:** Nextcloud, MariaDB, Redis (attempted), n8n  
**Purpose:** Step-by-step deployment procedures for cloud storage and automation services

## 📚 Table of Contents

1. [Overview](#overview)
2. [MariaDB (CT105) - Database Backend](#mariadb-ct105---database-backend)
3. [Nextcloud (CT104) - Cloud Storage](#nextcloud-ct104---cloud-storage)
4. [Redis (CT106) - Cache Layer (Failed)](#redis-ct106---cache-layer-failed)
5. [n8n (CT112) - Workflow Automation](#n8n-ct112---workflow-automation)
6. [WebDAV Configuration for Obsidian](#webdav-configuration-for-obsidian)
7. [Integration & Testing](#integration--testing)
8. [Troubleshooting](#troubleshooting)
9. [Lessons Learned](#lessons-learned)

---

## Overview

These services provide self-hosted cloud storage and automation capabilities:

| Service | Container | IP Address | Purpose | Dependencies |
|---------|-----------|------------|---------|--------------|
| **MariaDB** | CT105 | 192.168.40.32 | Database backend | None |
| **Nextcloud** | CT104 | 192.168.40.31 | Cloud storage & sync | MariaDB |
| **Redis** | CT106 | 192.168.40.33 | Cache (not operational) | None |
| **n8n** | CT112 | 192.168.40.61 | Workflow automation | None |

**Deployment Order:** MariaDB → Nextcloud → Redis (attempted) → n8n

**Total Deployment Time:** ~3 hours (including troubleshooting)

**Critical Decision:** Separated database from application for better management and backup flexibility.

---

## MariaDB (CT105) - Database Backend

### Purpose
Dedicated database server for Nextcloud (and future services), providing better performance and management than SQLite.

### Container Creation

```bash
# On Proxmox host
pct create 105 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname mariadb \
  --cores 2 \
  --memory 2048 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:10 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1

# Set static IP
pct set 105 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.32/24,gw=192.168.40.1

# Set DNS
pct set 105 --nameserver 192.168.40.53 --searchdomain homelab.local

# Start container
pct start 105
```

### MariaDB Installation

```bash
# Enter container
pct enter 105

# Update system
apt update && apt upgrade -y

# Install MariaDB
apt install -y mariadb-server

# Secure installation (optional but recommended)
mysql_secure_installation
# Answer: Y, Y, N, Y, Y
```

### Database Configuration

```bash
# Configure MariaDB to listen on network (not just localhost)
nano /etc/mysql/mariadb.conf.d/50-server.cnf

# Find and change:
# bind-address = 127.0.0.1
# To:
bind-address = 0.0.0.0

# Save and exit
```

### Create Nextcloud Database

```bash
# Connect to MariaDB
mysql -u root -p

# Create database and user
CREATE DATABASE nextcloud CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
CREATE USER 'nextcloud'@'192.168.40.31' IDENTIFIED BY 'your-secure-password-here';
GRANT ALL PRIVILEGES ON nextcloud.* TO 'nextcloud'@'192.168.40.31';
FLUSH PRIVILEGES;
EXIT;

# Restart MariaDB
systemctl restart mariadb
systemctl enable mariadb

# Verify listening on network
ss -tlnp | grep 3306
# Should show 0.0.0.0:3306

# Exit container
exit
```

### Security Note
- User 'nextcloud' can only connect from 192.168.40.31 (Nextcloud container)
- Database isolated to specific IP for security

---

## Nextcloud (CT104) - Cloud Storage

### Purpose
Self-hosted cloud storage platform replacing Google Drive, with file sync, calendar, contacts, and WebDAV support for Obsidian.

### Container Creation

```bash
# On Proxmox host
pct create 104 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname nextcloud \
  --cores 2 \
  --memory 4096 \
  --swap 4096 \
  --storage local-lvm \
  --rootfs local-lvm:20 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1

# Set static IP
pct set 104 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.31/24,gw=192.168.40.1

# Set DNS
pct set 104 --nameserver 192.168.40.53 --searchdomain homelab.local

# Start container
pct start 104
```

### System Preparation

```bash
# Enter container
pct enter 104

# Update system
apt update && apt upgrade -y

# Install Apache and PHP
apt install -y apache2 mariadb-client libapache2-mod-php \
  php-gd php-mysql php-curl php-mbstring php-intl \
  php-gmp php-bcmath php-xml php-imagick php-zip \
  php-bz2 php-apcu unzip wget

# Enable required Apache modules
a2enmod rewrite headers env dir mime ssl

# Set PHP memory limit (optional but recommended)
sed -i 's/memory_limit = .*/memory_limit = 512M/' /etc/php/8.2/apache2/php.ini
```

### Download and Install Nextcloud

```bash
# Download latest Nextcloud
cd /tmp
wget https://download.nextcloud.com/server/releases/latest.tar.bz2

# Extract to web root
tar -xjf latest.tar.bz2 -C /var/www/

# Set permissions
chown -R www-data:www-data /var/www/nextcloud

# Create Apache configuration
cat > /etc/apache2/sites-available/nextcloud.conf << 'EOF'
<VirtualHost *:80>
    ServerName cloud.homelab.local
    DocumentRoot /var/www/nextcloud

    <Directory /var/www/nextcloud/>
        Require all granted
        AllowOverride All
        Options FollowSymLinks MultiViews

        <IfModule mod_dav.c>
            Dav off
        </IfModule>
    </Directory>
</VirtualHost>
EOF

# Enable site and disable default
a2ensite nextcloud.conf
a2dissite 000-default.conf

# Restart Apache
systemctl restart apache2
systemctl enable apache2

# Exit container
exit
```

### Configure DNS and Proxy

```bash
# Add DNS entry in Pi-hole
pct enter 101
nano /etc/pihole/pihole.toml

# Add to hosts array:
"192.168.40.22 cloud.homelab.local",

systemctl restart pihole-FTL
exit
```

**In NPM Web Interface:**
1. Add Proxy Host
2. Domain: `cloud.homelab.local`
3. Forward to: `192.168.40.31` port `80`
4. Enable Cache Assets, Block Exploits, Websockets

### Web-Based Setup

1. Browse to http://cloud.homelab.local
2. Create admin account:
   - Username: `admin` (or your preference)
   - Password: [strong password]

3. Configure database:
   - Database user: `nextcloud`
   - Database password: [password from MariaDB setup]
   - Database name: `nextcloud`
   - Database host: `192.168.40.32:3306`

4. Click Install (takes 1-2 minutes)

### Post-Installation Configuration

```bash
# Enter Nextcloud container
pct enter 104

# Add trusted domains for mobile access
nano /var/www/nextcloud/config/config.php

# Find trusted_domains and add:
'trusted_domains' => 
  array (
    0 => 'cloud.homelab.local',
    1 => '192.168.40.31',  # For Tailscale direct access
  ),

# Optimize PHP for Nextcloud
echo 'apc.enable_cli=1' >> /etc/php/8.2/mods-available/apcu.ini

# Restart Apache
systemctl restart apache2

# Exit
exit
```

### Install Essential Apps

In Nextcloud web interface:
1. Click user icon → Apps
2. Install:
   - Calendar
   - Contacts
   - Notes (optional if using Obsidian)

---

## Redis (CT106) - Cache Layer (Failed)

### Purpose
Intended to provide memory caching for Nextcloud to improve performance.

### Why It Failed
Redis service failed to start in unprivileged LXC container due to systemd namespace restrictions (error code 226/NAMESPACE).

### Container Creation (For Documentation)

```bash
# Container was created
pct create 106 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname redis \
  --cores 1 \
  --memory 512 \
  --swap 512 \
  --storage local-lvm \
  --rootfs local-lvm:5 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1

pct set 106 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.33/24,gw=192.168.40.1
```

### Attempted Solutions

```bash
# Tried adding nesting
pct set 106 --features nesting=1

# Tried systemd overrides
mkdir -p /etc/systemd/system/redis-server.service.d/
cat > /etc/systemd/system/redis-server.service.d/override.conf << EOF
[Service]
PrivateDevices=no
PrivateTmp=no
ProtectSystem=no
ProtectHome=no
NoNewPrivileges=no
RestrictRealtime=no
RestrictSUIDSGID=no
EOF

# Tried Redis configuration changes
echo "daemonize no" >> /etc/redis/redis.conf
echo "bind 0.0.0.0" >> /etc/redis/redis.conf

# None of these worked - service still failed with namespace error
```

### Decision
- Skip Redis for initial deployment
- Nextcloud works fine without Redis (just slightly slower)
- Can revisit later using Docker or privileged container

### Lessons Learned
- Unprivileged LXC containers have limitations with heavily-hardened systemd services
- Don't let optimization block main deployment
- Document failed attempts for future reference

---

## n8n (CT112) - Workflow Automation

### Purpose
Visual workflow automation platform to connect services (Nextcloud, Home Assistant, email, webhooks) - self-hosted alternative to Zapier/IFTTT.

### Container Creation

```bash
# On Proxmox host
pct create 112 local:vztmpl/debian-12-standard_12.12-1_amd64.tar.zst \
  --hostname n8n \
  --cores 2 \
  --memory 2048 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:20 \
  --network name=eth0,bridge=vmbr0,tag=40,type=veth \
  --onboot 1 \
  --unprivileged 1

# Set static IP
pct set 112 --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.61/24,gw=192.168.40.1

# Set DNS
pct set 112 --nameserver 192.168.40.53 --searchdomain homelab.local

# Enable Docker in LXC
cat >> /etc/pve/lxc/112.conf << EOF
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
EOF

# Start container
pct start 112
```

### Docker Installation

```bash
# Enter container
pct enter 112

# Update system
apt update && apt upgrade -y

# Install Docker
apt install -y curl
curl -fsSL https://get.docker.com | sh

# Enable Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
apt install -y docker-compose-plugin
```

### Deploy n8n (Critical Version Note!)

**IMPORTANT:** Use specific version (1.63.4) NOT latest tag!

```bash
# Create directory
mkdir -p /opt/n8n
cd /opt/n8n

# Create docker-compose.yml with SPECIFIC VERSION
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  n8n:
    image: n8nio/n8n:1.63.4  # DO NOT USE :latest - causes permission errors
    container_name: n8n
    restart: unless-stopped
    ports:
      - "5678:5678"
    environment:
      - N8N_HOST=automation.homelab.local
      - N8N_PORT=5678
      - N8N_PROTOCOL=http
      - GENERIC_TIMEZONE=Australia/Darwin
    volumes:
      - ./data:/home/node/.n8n
EOF

# Fix permissions (n8n runs as UID 1000)
mkdir -p ./data
chown -R 1000:1000 ./data

# Start n8n
docker compose up -d

# Verify running
docker compose ps
# Should show container running

# Check logs
docker compose logs --tail 20
# Should show "Editor is now accessible via: http://localhost:5678"

# Exit container
exit
```

### Configure DNS and Proxy

```bash
# Add DNS entry in Pi-hole
pct enter 101
nano /etc/pihole/pihole.toml

# Add to hosts array:
"192.168.40.22 automation.homelab.local",

systemctl restart pihole-FTL
exit
```

**In NPM Web Interface:**
1. Add Proxy Host
2. Domain: `automation.homelab.local`
3. Forward to: `192.168.40.61` port `5678`
4. Enable Cache Assets, Block Exploits, Websockets (IMPORTANT for n8n!)

### Initial Setup

1. Browse to http://automation.homelab.local
2. Create owner account:
   - Email: [your email]
   - First name: [your name]
   - Password: [strong password]
3. Skip optional telemetry/newsletter

### Key Issue Encountered

**Issue:** Container continuously restarts with permission errors when using `:latest` tag  
**Error:** "Error: EACCES: permission denied, open '/home/node/.n8n/config'"  
**Root Cause:** Latest n8n versions have permission issues in unprivileged LXC  
**Solution:** Use stable LTS version (1.63.4) instead of latest

---

## WebDAV Configuration for Obsidian

### Purpose
Enable Obsidian vault synchronization across devices using Nextcloud's WebDAV interface.

### Generate App Password in Nextcloud

1. Log into Nextcloud web interface
2. Click profile icon → Settings
3. Security → Devices & sessions
4. Under "Create new app password":
   - Name: `Obsidian`
   - Click "Create new app password"
5. **COPY THE PASSWORD** (shown only once!)

### Install Remotely Save Plugin in Obsidian

1. Settings → Community plugins → Browse
2. Search "Remotely Save"
3. Install and Enable
4. Accept agreement

### Configure WebDAV Connection

In Remotely Save settings:

1. **Choose A Remote Service:** `webdav`
2. **Server Address:** `http://cloud.homelab.local/remote.php/dav/files/[username]/`
3. **Username:** [your Nextcloud username]
4. **Password:** [app password from above]
5. **Auth Type:** `basic`
6. **Depth Header:** `only supports depth='1'`
7. Click "Check" - should show ✓

### Configure Sync Settings

1. **Change Remote Base Directory:** `Obsidian`
2. **Encryption Password:** Leave empty (local network secure)
3. **Schedule For Auto Run:** `every 10 minutes`
4. **Run Once On Start Up:** `enable`
5. **Sync On Save:** `disable` (scheduled sync more reliable)

### First Sync

1. Click sync icon in Obsidian
2. Wait for initial sync (30 seconds to few minutes)
3. Check Nextcloud Files → Obsidian folder
4. Entire vault should be uploaded!

### Mobile Setup

1. Install Obsidian mobile app
2. Install Remotely Save plugin
3. Use same WebDAV credentials
4. Point to same remote folder
5. First sync downloads entire vault

---

## Integration & Testing

### Complete Service Verification

```bash
# Test all service DNS entries
for service in cloud automation; do
  echo -n "$service.homelab.local: "
  nslookup $service.homelab.local 192.168.40.53 | grep "Address:" | tail -1
done

# Test HTTP access
for service in cloud automation; do
  echo -n "Testing $service.homelab.local: "
  curl -s -o /dev/null -w "%{http_code}\n" "http://$service.homelab.local"
done

# Test database connectivity
pct exec 104 -- mysql -h 192.168.40.32 -u nextcloud -p -e "SELECT 1"
# Enter Nextcloud database password

# Test WebDAV
curl -u username:app-password \
  http://cloud.homelab.local/remote.php/dav/files/username/ \
  -X PROPFIND
```

### Mobile Access via Tailscale

For Nextcloud mobile app:
1. Connect to Tailscale on mobile
2. Server address: `http://192.168.40.31`
3. Username and password (not app password)
4. Files sync automatically

---

## Troubleshooting

### Common Issues and Solutions

#### Nextcloud Database Connection Failed
```bash
# Test connection from Nextcloud container
pct exec 104 -- mysql -h 192.168.40.32 -u nextcloud -p

# Check MariaDB is listening
pct exec 105 -- ss -tlnp | grep 3306

# Check user permissions in MariaDB
pct exec 105 -- mysql -u root -p
SHOW GRANTS FOR 'nextcloud'@'192.168.40.31';
```

#### WebDAV Not Working
```bash
# Check WebDAV is enabled
pct exec 104 -- sudo -u www-data php /var/www/nextcloud/occ app:list | grep dav

# Test WebDAV directly
curl -u username:password http://cloud.homelab.local/remote.php/dav/
```

#### n8n Permission Errors
```bash
# Check data directory ownership
pct exec 112 -- ls -la /opt/n8n/data
# Should be owned by 1000:1000

# Fix if needed
pct exec 112 -- chown -R 1000:1000 /opt/n8n/data

# Restart
pct exec 112 -- bash -c "cd /opt/n8n && docker compose restart"
```

#### Mobile App "Untrusted Domain"
```bash
# Add IP to trusted domains
pct exec 104 -- nano /var/www/nextcloud/config/config.php

# Add to trusted_domains array:
1 => '192.168.40.31',

# Restart Apache
pct exec 104 -- systemctl restart apache2
```

---

## Lessons Learned

### Critical Insights

1. **Database Separation is Worth It**
   - Easier backups (database separate from files)
   - Better resource management
   - Can be shared by multiple services
   - Cleaner disaster recovery

2. **Version Pinning is Critical**
   - n8n :latest tag caused hours of troubleshooting
   - Always use specific versions in production
   - Test updates in development first

3. **Systemd Hardening vs Unprivileged LXC**
   - Modern services with namespace isolation don't work
   - Redis failed completely in unprivileged container
   - Docker often more reliable than native in LXC

4. **WebDAV Works Perfectly for Sync**
   - Obsidian sync via WebDAV is reliable
   - App passwords provide security
   - No need for expensive sync services

5. **Resource Allocation Matters**
   - Nextcloud needs 4GB RAM minimum
   - MariaDB benefits from dedicated resources
   - n8n uses minimal resources when idle

### Architecture Decisions Validated

1. **Multi-Container Approach**
   - Database in CT105
   - Application in CT104
   - Cache in CT106 (even though failed)
   - Clean separation of concerns

2. **Docker for Complex Services**
   - n8n easier to deploy via Docker
   - Version management simpler
   - Isolation from host system

3. **Proxy All Web Services**
   - Consistent URL scheme
   - Central SSL management (future)
   - Single entry point

### What We'd Do Differently

1. **Skip Redis Initially**
   - Not worth the troubleshooting time
   - Nextcloud performs fine without it
   - Add optimization later

2. **Use Docker for Redis**
   - If cache needed, deploy via Docker
   - Avoids systemd namespace issues

3. **Document App Passwords**
   - Critical for service integration
   - Store securely in password manager
   - Different from login passwords

---

## Quick Recovery Procedures

### If Nextcloud Fails
```bash
# Check Apache
pct exec 104 -- systemctl status apache2
pct exec 104 -- systemctl restart apache2

# Check database connection
pct exec 104 -- mysql -h 192.168.40.32 -u nextcloud -p -e "SELECT 1"

# Check logs
pct exec 104 -- tail -f /var/log/apache2/error.log
```

### If MariaDB Fails
```bash
# Restart service
pct exec 105 -- systemctl restart mariadb

# Check status
pct exec 105 -- systemctl status mariadb

# Check if listening
pct exec 105 -- ss -tlnp | grep 3306
```

### If n8n Fails
```bash
# Restart Docker container
pct exec 112 -- bash -c "cd /opt/n8n && docker compose restart"

# Check logs
pct exec 112 -- bash -c "cd /opt/n8n && docker compose logs --tail 50"

# Check permissions
pct exec 112 -- ls -la /opt/n8n/data
```

### Complete Service Recovery Order
1. Start MariaDB (database must be first)
2. Wait 30 seconds
3. Start Nextcloud
4. Start n8n
5. Verify all services via browser

---

## Performance Metrics

### Resource Usage (Actual)

| Service | CPU (idle) | CPU (active) | RAM | Storage |
|---------|------------|--------------|-----|---------|
| MariaDB | <1% | 10% | 150MB | 850MB |
| Nextcloud | <5% | 20% | 300MB | 2.1GB |
| Redis | N/A | N/A | N/A | N/A |
| n8n | <2% | 15% | 150MB | 980MB |

### Sync Performance
- Obsidian initial sync: ~2 minutes for 500MB vault
- Incremental sync: <10 seconds
- WebDAV response: <100ms
- Mobile sync: Works over Tailscale

### Database Performance
- Nextcloud page load: <500ms
- File listing: <200ms
- Calendar sync: <2 seconds
- Database size: ~50MB after initial setup

---

## Summary

These storage and automation services provide:
- **Nextcloud:** Complete Google Drive replacement
- **MariaDB:** Robust database backend
- **n8n:** Visual workflow automation
- **WebDAV:** Perfect Obsidian synchronization

Total resources used:
- CPU: 7 cores allocated
- RAM: 8.5GB allocated  
- Storage: 55GB allocated
- Actual usage: <15% CPU, <2GB RAM combined

All services configured with auto-start, proper database separation, and working mobile access.

### Next Steps
1. Create first n8n workflow
2. Set up Nextcloud external storage (Mac Pro NAS)
3. Install additional Nextcloud apps as needed
4. Consider Redis via Docker for performance

---

**Deployment Guides Complete!** Both core and storage/automation services fully documented.