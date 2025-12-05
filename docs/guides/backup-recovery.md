# 💾 Backup & Recovery Strategy

**Last Updated:** 2025-12-05  
**Purpose:** Comprehensive backup strategy and disaster recovery procedures  
**Storage:** G-Drive USB-C (10TB) connected to pve1

## 📚 Table of Contents

1. [Quick Reference](#quick-reference)
2. [Current Backup Configuration](#current-backup-configuration)
3. [Backup Architecture](#backup-architecture)
4. [Recovery Procedures](#recovery-procedures)
5. [Testing & Verification](#testing--verification)
6. [Disaster Recovery](#disaster-recovery)
7. [Backup Maintenance](#backup-maintenance)
8. [Troubleshooting](#troubleshooting)

---

## ⚡ Quick Reference

### Daily Backup Status Check
```bash
# Quick health check
ssh root@192.168.10.11 << 'EOF'
echo "=== Backup Storage ==="
df -h /mnt/backup-storage | tail -1
echo ""
echo "=== Last Backup ==="
ls -lht /mnt/backup-storage/proxmox-backups/dump/ | head -5
echo ""
echo "=== Container Coverage ==="
for ct in 100 101 102 103 104 105 106 107 112; do
  count=$(ls /mnt/backup-storage/proxmox-backups/dump/*-$ct-* 2>/dev/null | wc -l)
  echo "CT$ct: $count backups"
done
EOF
```

### Manual Backup Commands
```bash
# Single container
vzdump <CTID> --storage backup-gdrive --mode snapshot --compress zstd

# All containers
for ct in 100 101 102 103 104 105 106 107 112; do
  vzdump $ct --storage backup-gdrive --mode snapshot --compress zstd
done
```

### Emergency Restore
```bash
# Quick restore (destroys existing!)
pct destroy <CTID>
pct restore <CTID> /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst
pct start <CTID>
```

---

## 📅 Current Backup Configuration

### Automated Schedule

**Job ID:** backup-6963fa17-187b  
**Schedule:** Daily at 02:00 Darwin time  
**Mode:** Snapshot (zero downtime)  
**Compression:** ZSTD (~60% reduction)  

### Container Coverage

| CT ID | Service | Size (Compressed) | Backup Time | Priority |
|-------|---------|-------------------|-------------|----------|
| 100 | Tailscale | ~226MB | ~10s | Critical |
| 101 | Pi-hole | ~286MB | ~12s | Critical |
| 102 | Nginx Proxy Manager | ~1.2GB | ~17s | High |
| 103 | Uptime Kuma | ~756MB | ~13s | Medium |
| 104 | Nextcloud | ~2.1GB | ~25s | Critical |
| 105 | MariaDB | ~850MB | ~15s | Critical |
| 106 | Redis | ~150MB | ~8s | Low (not operational) |
| 107 | UniFi Controller | ~500MB | ~10s | High |
| 112 | n8n | ~980MB | ~14s | Medium |

**Total Daily Backup:** ~7GB compressed (~12GB uncompressed)  
**Backup Window:** ~2-3 minutes total

### Retention Policy (Proxmox Built-in)

```
prune-backups: keep-daily=7,keep-weekly=4,keep-monthly=6
```

| Retention Type | Count | Period | Storage Used |
|---------------|-------|--------|--------------|
| Daily | 7 | Last 7 days | ~50GB |
| Weekly | 4 | Last 4 weeks | ~28GB |
| Monthly | 6 | Last 6 months | ~42GB |
| **Total** | ~17 copies per CT | | **~120GB** |

**Storage Available:** 8,600GB (1.4% used)

---

## 🏗️ Backup Architecture

### Storage Backend

```
┌─────────────────────┐
│   Proxmox Cluster   │
│   (all CTs on pve1) │
└─────────┬───────────┘
          │ Local write
          │ /mnt/backup-storage
          ↓
┌─────────────────────┐
│   G-Drive USB-C     │
│   10TB (9.1TB raw)  │
│   ext4 filesystem   │
│   Connected to pve1 │
└─────────────────────┘
```

### Mount Configuration

**Systemd Mount Unit:** `/etc/systemd/system/mnt-backup\x2dstorage.mount`
```ini
[Unit]
Description=G-Drive Backup Storage
After=local-fs.target

[Mount]
What=/dev/disk/by-label/backup-storage
Where=/mnt/backup-storage
Type=ext4
Options=defaults,nofail

[Install]
WantedBy=multi-user.target
```

### Storage Details

| Property | Value |
|----------|-------|
| Device | /dev/sda1 |
| Label | backup-storage |
| UUID | 6a9c5424-d6b0-48f7-a4d1-8d64de4e20d3 |
| Filesystem | ext4 |
| Mount Point | /mnt/backup-storage |
| Proxmox Storage ID | backup-gdrive |

### Backup Flow

1. **02:00 Daily:** pvescheduler triggers backup job
2. **VZDump:** Creates snapshot of container filesystem
3. **Compression:** ZSTD compression applied
4. **Write:** Saved to /mnt/backup-storage/proxmox-backups/dump/
5. **Verification:** Backup completion logged
6. **Pruning:** Old backups removed per retention policy

### Why Local USB vs Network Storage?

Previous setup used Mac Pro + Pegasus array via SSHFS. Changed to local USB because:

| Aspect | Mac Pro + Pegasus | G-Drive on pve1 |
|--------|-------------------|-----------------|
| Power | ~340W | ~5W |
| Complexity | High (SSHFS, Thunderbolt, stex driver) | Low (USB mount) |
| Noise | Significant | Silent |
| Failure modes | Network, SSH, driver timing | USB only |
| All CTs on pve1 | Required network transfer | Direct local write |

---

## 🔄 Recovery Procedures

### Single Container Recovery

#### Scenario: Container Corrupted/Failed

```bash
# 1. Identify the issue
pct status <CTID>
pct enter <CTID>  # Check if accessible

# 2. Stop the failed container (if running)
pct stop <CTID> --kill

# 3. List available backups
ls -lht /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-<CTID>-*.zst

# 4. Choose most recent backup
BACKUP_FILE=$(ls -t /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-<CTID>-*.zst | head -1)
echo "Using backup: $BACKUP_FILE"

# 5. Destroy failed container (CAUTION: Data loss!)
pct destroy <CTID>

# 6. Restore from backup
pct restore <CTID> "$BACKUP_FILE"

# 7. Start restored container
pct start <CTID>

# 8. Verify services
pct exec <CTID> -- systemctl status
```

#### Recovery Time: ~5 minutes per container

### Service-Specific Recovery

#### Pi-hole (CT101)
```bash
# Restore Pi-hole
pct destroy 101
pct restore 101 /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-101-[LATEST].tar.zst
pct start 101

# Fix DNS entry (known issue)
pct exec 101 -- sed -i 's/192.168.40.53 pihole.homelab.local/192.168.40.22 pihole.homelab.local/' /etc/pihole/pihole.toml
pct exec 101 -- systemctl restart pihole-FTL

# Verify DNS working
nslookup google.com 192.168.40.53
```

#### Nextcloud (CT104) + MariaDB (CT105)
```bash
# IMPORTANT: Restore database first!
# 1. Restore MariaDB
pct destroy 105
pct restore 105 /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-105-[LATEST].tar.zst
pct start 105

# 2. Wait for database to be ready
sleep 30

# 3. Then restore Nextcloud
pct destroy 104
pct restore 104 /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-104-[LATEST].tar.zst
pct start 104

# 4. Verify connectivity
pct exec 104 -- mysql -h 192.168.40.32 -u nextcloud -p[password] -e "SHOW DATABASES;"
```

#### Tailscale (CT100)
```bash
# Restore Tailscale
pct destroy 100
pct restore 100 /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-100-[LATEST].tar.zst
pct start 100

# May need to re-authenticate
pct exec 100 -- tailscale status
# If offline:
pct exec 100 -- tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24
```

#### UniFi Controller (CT107)
```bash
# Restore UniFi
pct destroy 107
pct restore 107 /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-107-[LATEST].tar.zst
pct start 107

# Wait for service to start
sleep 60

# Verify controller accessible
curl -k https://192.168.40.40:8443
```

### Batch Recovery (All Containers)

```bash
#!/bin/bash
# Restore all containers from latest backups

CONTAINERS="100 101 102 103 104 105 106 107 112"
BACKUP_DIR="/mnt/backup-storage/proxmox-backups/dump"

for CTID in $CONTAINERS; do
    echo "=== Restoring CT$CTID ==="
    
    # Find latest backup
    LATEST=$(ls -t $BACKUP_DIR/vzdump-lxc-$CTID-*.zst 2>/dev/null | head -1)
    
    if [ -z "$LATEST" ]; then
        echo "WARNING: No backup found for CT$CTID"
        continue
    fi
    
    # Stop and destroy existing
    pct stop $CTID --kill 2>/dev/null
    pct destroy $CTID 2>/dev/null
    
    # Restore
    echo "Restoring from: $LATEST"
    pct restore $CTID "$LATEST"
    
    # Start
    pct start $CTID
    echo "CT$CTID restored and started"
    echo ""
done

echo "All containers restored. Verifying..."
pct list
```

---

## ✅ Testing & Verification

### Monthly Restore Test

**Schedule:** First Monday of each month  
**Rotation:** Test different container each month

```bash
#!/bin/bash
# Monthly restore test script

# Determine which container to test (rotate monthly)
MONTH=$(date +%m)
CONTAINERS=(100 101 102 103 104 105 107 112)
INDEX=$((($MONTH - 1) % ${#CONTAINERS[@]}))
TEST_CTID=${CONTAINERS[$INDEX]}
TEST_ID=999  # Test restore ID

echo "=== Monthly Restore Test ==="
echo "Date: $(date)"
echo "Testing: CT$TEST_CTID"

# Find latest backup
BACKUP=$(ls -t /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-$TEST_CTID-*.zst | head -1)
echo "Backup: $BACKUP"

# Test restore to ID 999
pct restore $TEST_ID "$BACKUP"

# Start and verify
pct start $TEST_ID
sleep 10
pct exec $TEST_ID -- systemctl status | head -20

# Cleanup
pct stop $TEST_ID
pct destroy $TEST_ID

echo "Test complete - CT$TEST_CTID restore successful"
```

### Backup Verification Commands

```bash
# Verify backup integrity
tar -tzf /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst > /dev/null && echo "OK"

# Check backup contents (without restoring)
tar -tzf /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst | head -20

# Check storage mount
systemctl status 'mnt-backup\x2dstorage.mount'
```

### Recovery Time Objectives (RTO)

| Service | Target RTO | Actual RTO | Priority |
|---------|------------|------------|----------|
| Tailscale | 5 min | 3 min | Critical |
| Pi-hole | 5 min | 3 min | Critical |
| Nginx Proxy | 10 min | 5 min | High |
| Nextcloud | 15 min | 8 min | Critical |
| UniFi | 10 min | 5 min | High |

---

## 🔥 Disaster Recovery

### Scenario: pve1 Node Failure

Since all containers and backup storage are on pve1, this is the critical failure scenario.

#### Phase 1: Assess Damage
```bash
# From laptop, check if pve1 responds
ping 192.168.10.11

# Check other nodes
ping 192.168.10.12
ping 192.168.10.13

# Check cluster status from working node
ssh root@192.168.10.12 "pvecm status"
```

#### Phase 2: Recovery Options

**Option A: pve1 recoverable (hardware OK, OS issue)**
1. Boot pve1 from Proxmox USB installer in rescue mode
2. Check if /mnt/backup-storage accessible
3. Repair OS or reinstall Proxmox
4. Remount G-Drive
5. Restore containers from backups

**Option B: pve1 hardware failure**
1. Connect G-Drive to pve2 or pve3
2. Mount the drive:
   ```bash
   mkdir -p /mnt/backup-storage
   mount /dev/sda1 /mnt/backup-storage
   ```
3. Add as Proxmox storage:
   ```bash
   pvesm add dir backup-gdrive --path /mnt/backup-storage/proxmox-backups --content backup
   ```
4. Restore containers to working node

#### Phase 3: Restore Critical Services
```bash
# On the working node
for CTID in 101 100 102; do  # Pi-hole, Tailscale, NPM first
  BACKUP=$(ls -t /mnt/backup-storage/proxmox-backups/dump/vzdump-lxc-$CTID-*.zst | head -1)
  pct restore $CTID "$BACKUP"
  pct start $CTID
done
```

### Scenario: G-Drive Failure

The G-Drive is a single point of failure for backups (not for live data - that's on Ceph).

#### Immediate Actions
```bash
# 1. Disable backup job temporarily
pvesh set /cluster/backup/backup-6963fa17-187b --enabled 0

# 2. Use local storage for emergency backups
for CTID in 100 101; do  # Critical containers only
  vzdump $CTID --storage local --mode snapshot --compress zstd
done
```

#### Recovery Options

**Option 1: Replace G-Drive**
1. Connect new USB drive to pve1
2. Format as ext4 with label `backup-storage`
3. Systemd mount should auto-activate
4. Re-enable backup job

**Option 2: Temporary NFS from pve2/pve3**
```bash
# On pve2, share local storage
apt install nfs-kernel-server
echo "/var/lib/vz/dump *(rw,sync,no_subtree_check)" >> /etc/exports
exportctl -ra

# On pve1, mount it
mount -t nfs 192.168.10.12:/var/lib/vz/dump /mnt/temp-backup
pvesm add dir temp-backup --path /mnt/temp-backup --content backup
```

### Scenario: Complete Cluster Failure

#### Recovery Priority Order

1. **Network Infrastructure**
   - Verify OPNsense operational
   - Check switch configuration
   - Confirm VLANs active

2. **First Proxmox Node (pve1 preferred)**
   - Install Proxmox VE
   - Configure networking (VLANs)
   - Connect and mount G-Drive
   - Create new cluster

3. **Critical Services**
   ```bash
   # Restore in order
   pct restore 101 /path/to/backup  # Pi-hole (DNS)
   pct restore 100 /path/to/backup  # Tailscale (Remote)
   pct restore 102 /path/to/backup  # NPM (Routing)
   ```

4. **Additional Nodes**
   - Install Proxmox VE
   - Join cluster
   - Configure Ceph

5. **Remaining Services**
   - Restore remaining containers
   - Verify all services

**Total Recovery Time:** 2-4 hours

---

## 🔧 Backup Maintenance

### Daily Tasks (Automated)
```bash
# Runs at 02:00 via pvescheduler
# Job ID: backup-6963fa17-187b
```

### Weekly Tasks
```bash
# Check backup storage usage
df -h /mnt/backup-storage

# Verify latest backups exist
for ct in 100 101 102 103 104 105 106 107 112; do
  echo -n "CT$ct: "
  ls -t /mnt/backup-storage/proxmox-backups/dump/*-$ct-* 2>/dev/null | head -1
done
```

### Monthly Tasks
```bash
# 1. Run restore test (see Monthly Restore Test section)

# 2. Check backup sizes for anomalies
ls -lhS /mnt/backup-storage/proxmox-backups/dump/ | head -20

# 3. Verify retention policy working
for ct in 100 101 102 103 104 105 106 107 112; do
  count=$(ls /mnt/backup-storage/proxmox-backups/dump/*-$ct-* 2>/dev/null | wc -l)
  echo "CT$ct has $count backups"
done

# 4. Check drive health
smartctl -a /dev/sda
```

---

## 🔨 Troubleshooting

### Backup Failures

#### Mount Not Available
```bash
# Check mount status
systemctl status 'mnt-backup\x2dstorage.mount'

# Check if drive is detected
lsblk | grep sda

# Restart mount
systemctl restart 'mnt-backup\x2dstorage.mount'

# Verify mounted
df -h /mnt/backup-storage
```

#### USB Drive Not Detected
```bash
# Check dmesg for USB issues
dmesg | tail -30 | grep -i usb

# Check if drive is present
lsblk

# Try reconnecting USB cable
# Check for loose connection
```

#### Container Locked During Backup
```bash
# Check if backup running
ps aux | grep vzdump

# Kill stuck backup
kill -9 <vzdump-pid>

# Unlock container
pct unlock <CTID>

# Retry backup
vzdump <CTID> --storage backup-gdrive --mode snapshot
```

#### Insufficient Space
```bash
# Check space
df -h /mnt/backup-storage

# Force prune old backups
pvesh create /nodes/pve1/storage/backup-gdrive/prunebackups

# Emergency: Delete oldest backups manually
cd /mnt/backup-storage/proxmox-backups/dump/
ls -t | tail -20 | xargs rm
```

---

## 📊 Backup Metrics & Monitoring

### Key Performance Indicators

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Backup Success Rate | 100% | 100% | ✅ |
| Average Backup Time | <5 min | 2.5 min | ✅ |
| Compression Ratio | >50% | 60% | ✅ |
| Storage Used | <500GB | <1GB | ✅ |
| Restore Test Success | 100% | TBD | ⏳ |
| Recovery Time (Critical) | <10 min | 5 min | ✅ |

### Monitoring Commands
```bash
# Check last backup status
tail -50 /var/log/pve/tasks/index | grep vzdump

# Monitor backup progress (live)
tail -f /var/log/pve/tasks/active

# Check scheduler status
systemctl status pvescheduler
```

---

## 🔐 3-2-1 Backup Rule Compliance

### Current Status
- ✅ **3 copies:** Original (Ceph) + G-Drive backup
- ⚠️ **2 media types:** NVMe (Ceph) + HDD (G-Drive) - Same location
- ❌ **1 offsite:** Not yet implemented

### Future Improvements

1. **Offsite Backup (Priority)**
   - Option 1: Backblaze B2 ($5/TB/month)
   - Option 2: Relative's house with Raspberry Pi
   - Option 3: Rotate second USB drive offsite monthly

2. **Drive Health Monitoring**
   ```bash
   # Add to cron weekly
   smartctl -H /dev/sda | grep -i health
   ```

---

## 🎯 Recovery Checklist

### Container Recovery
- [ ] Identify failed container
- [ ] Stop container if running
- [ ] Find latest good backup
- [ ] Destroy failed container
- [ ] Restore from backup
- [ ] Start container
- [ ] Verify services running
- [ ] Test functionality
- [ ] Document incident

### Node Recovery (pve1)
- [ ] Assess if hardware or software issue
- [ ] If hardware: move G-Drive to another node
- [ ] Restore critical services first (Pi-hole, Tailscale, NPM)
- [ ] Rebuild pve1 or replace hardware
- [ ] Rejoin to cluster
- [ ] Move containers back if desired
- [ ] Update documentation

---

*Regular testing prevents surprises*  
*A backup is only good if you can restore it*  
*Document every recovery attempt*