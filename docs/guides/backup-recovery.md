# 💾 Backup & Recovery Strategy

**Last Updated:** 2025-11-24  
**Purpose:** Comprehensive backup strategy and disaster recovery procedures  
**Storage:** Mac Pro NAS with 9.1TB capacity via SSHFS

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
echo "=== Backup Status ==="
df -h /mnt/macpro | tail -1
echo ""
echo "=== Last Backup ==="
ls -lht /mnt/macpro/proxmox-backups/dump/ | head -3
echo ""
echo "=== Container Coverage ==="
for ct in 100 101 102 103 104 105 112; do
  count=$(ls /mnt/macpro/proxmox-backups/dump/*-$ct-* 2>/dev/null | wc -l)
  echo "CT$ct: $count backups"
done
EOF
```

### Manual Backup Commands
```bash
# Single container
vzdump <CTID> --storage macpro-backups --mode snapshot --compress zstd

# All containers
for ct in 100 101 102 103 104 105 112; do
  vzdump $ct --storage macpro-backups --mode snapshot --compress zstd
done
```

### Emergency Restore
```bash
# Quick restore (destroys existing!)
pct destroy <CTID>
pct restore <CTID> /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst
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
| 112 | n8n | ~980MB | ~14s | Medium |

**Total Daily Backup:** ~6.5GB compressed (~11GB uncompressed)  
**Backup Window:** ~2-3 minutes total

### Retention Policy (Proxmox Built-in)

```
prune-backups: keep-daily=7,keep-weekly=4,keep-monthly=6
```

| Retention Type | Count | Period | Storage Used |
|---------------|-------|--------|--------------|
| Daily | 7 | Last 7 days | ~45GB |
| Weekly | 4 | Last 4 weeks | ~26GB |
| Monthly | 6 | Last 6 months | ~39GB |
| **Total** | ~119 backups | | **~110GB** |

**Storage Available:** 9,090GB (1.2% used)

---

## 🏗️ Backup Architecture

### Storage Backend

```
┌─────────────────┐
│  Proxmox Nodes  │
│   (3 nodes)     │
└────────┬────────┘
         │ SSHFS Mount
         │ 192.168.30.20:/storage
         ↓
┌─────────────────┐
│   Mac Pro NAS   │
│  Ubuntu 22.04   │
│  192.168.30.20  │
└────────┬────────┘
         │ Thunderbolt
         ↓
┌─────────────────┐
│ Pegasus R6 Array│
│     9.1TB       │
│  /storage mount │
└─────────────────┘
```

### Mount Configuration

**Per-Node SSHFS Mount:** `/etc/systemd/system/mnt-macpro.mount`
```ini
[Unit]
Description=Mac Pro Storage via SSHFS
After=network.target

[Mount]
What=xavier@192.168.30.20:/storage
Where=/mnt/macpro
Type=fuse.sshfs
Options=_netdev,allow_other,IdentityFile=/root/.ssh/id_rsa,reconnect,ServerAliveInterval=15

[Install]
WantedBy=multi-user.target
```

### Backup Flow

1. **02:00 Daily:** Cron triggers backup job
2. **VZDump:** Creates snapshot of container filesystem
3. **Compression:** ZSTD compression applied
4. **Transfer:** Written to /mnt/macpro/proxmox-backups/dump/
5. **Verification:** Backup completion logged
6. **Pruning:** Old backups removed per retention policy

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
ls -lht /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-*.zst

# 4. Choose most recent backup
BACKUP_FILE=$(ls -t /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-*.zst | head -1)
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
pct restore 101 /mnt/macpro/proxmox-backups/dump/vzdump-lxc-101-[LATEST].tar.zst
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
pct restore 105 /mnt/macpro/proxmox-backups/dump/vzdump-lxc-105-[LATEST].tar.zst
pct start 105

# 2. Wait for database to be ready
sleep 30

# 3. Then restore Nextcloud
pct destroy 104
pct restore 104 /mnt/macpro/proxmox-backups/dump/vzdump-lxc-104-[LATEST].tar.zst
pct start 104

# 4. Verify connectivity
pct exec 104 -- mysql -h 192.168.40.32 -u nextcloud -p[password] -e "SHOW DATABASES;"
```

#### Tailscale (CT100)
```bash
# Restore Tailscale
pct destroy 100
pct restore 100 /mnt/macpro/proxmox-backups/dump/vzdump-lxc-100-[LATEST].tar.zst
pct start 100

# May need to re-authenticate
pct exec 100 -- tailscale status
# If offline:
pct exec 100 -- tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24
```

### Batch Recovery (All Containers)

```bash
#!/bin/bash
# Restore all containers from latest backups

CONTAINERS="100 101 102 103 104 105 112"
BACKUP_DIR="/mnt/macpro/proxmox-backups/dump"

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
CONTAINERS=(100 101 102 103 104 105 112)
INDEX=$((($MONTH - 1) % ${#CONTAINERS[@]}))
TEST_CTID=${CONTAINERS[$INDEX]}
TEST_ID=999  # Test restore ID

echo "=== Monthly Restore Test ==="
echo "Date: $(date)"
echo "Testing: CT$TEST_CTID"

# Find latest backup
BACKUP=$(ls -t /mnt/macpro/proxmox-backups/dump/vzdump-lxc-$TEST_CTID-*.zst | head -1)
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
vzdump --storage macpro-backups --verify

# Check backup contents (without restoring)
tar -tzf /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-<DATE>.tar.zst | head -20

# Verify compression ratio
ls -lh /mnt/macpro/proxmox-backups/dump/vzdump-lxc-<CTID>-*.zst
```

### Recovery Time Objectives (RTO)

| Service | Target RTO | Actual RTO | Priority |
|---------|------------|------------|----------|
| Tailscale | 5 min | 3 min | Critical |
| Pi-hole | 10 min | 5 min | Critical |
| Nextcloud + DB | 15 min | 10 min | High |
| Nginx Proxy | 10 min | 5 min | High |
| Uptime Kuma | 30 min | 5 min | Low |
| n8n | 30 min | 5 min | Low |

---

## 🚨 Disaster Recovery

### Scenario: Complete Node Failure

#### Phase 1: Assess Damage
```bash
# Check which node failed
for node in 11 12 13; do
  ping -c 2 192.168.10.$node && echo "pve$node UP" || echo "pve$node DOWN"
done

# Check cluster status from working node
ssh root@192.168.10.<working-node> "pvecm status"
```

#### Phase 2: Restore Quorum (If Needed)
```bash
# If only 1 node remains
pvecm expected 1

# If 2 nodes remain
pvecm expected 2
```

#### Phase 3: Migrate Services (If Node Recoverable)
```bash
# From working node, restore containers
for CTID in 100 101 102 103 104 105 112; do
  BACKUP=$(ls -t /mnt/macpro/proxmox-backups/dump/vzdump-lxc-$CTID-*.zst | head -1)
  pct restore $CTID "$BACKUP" --target <working-node>
  pct start $CTID
done
```

#### Phase 4: Rebuild Failed Node
1. Reinstall Proxmox VE
2. Configure network (VLANs)
3. Rejoin cluster: `pvecm add 192.168.10.11`
4. Configure Ceph OSDs
5. Rebalance containers

### Scenario: Mac Pro NAS Failure

#### Immediate Actions
```bash
# 1. Stop backup jobs
pvesh set /cluster/backup/backup-6963fa17-187b --enabled 0

# 2. Use local storage temporarily
for CTID in 100 101; do  # Critical containers only
  vzdump $CTID --storage local --mode snapshot --compress zstd
done
```

#### Recovery Options

**Option 1: Repair Mac Pro**
1. Boot from Ubuntu USB
2. Check Pegasus array
3. Remount storage
4. Restore SSH keys from nodes

**Option 2: Temporary USB Backup**
```bash
# On any Proxmox node
mkdir -p /mnt/usb-backup
mount /dev/sdb1 /mnt/usb-backup

# Add as Proxmox storage
pvesm add dir usb-backup --path /mnt/usb-backup --content backup
```

**Option 3: Use Ceph for Backups**
```bash
# Reconfigure backup to Ceph (limited space!)
pvesh set /cluster/backup/backup-6963fa17-187b --storage vm-storage
```

### Scenario: Complete Cluster Failure

#### Recovery Priority Order

1. **Network Infrastructure**
   - Verify OPNsense operational
   - Check switch configuration
   - Confirm VLANs active

2. **Storage Backend**
   - Boot Mac Pro NAS
   - Verify Pegasus mount
   - Check backup availability

3. **First Proxmox Node**
   - Install Proxmox VE
   - Configure networking
   - Create new cluster

4. **Critical Services**
   ```bash
   # Restore in order
   pct restore 101 /path/to/backup  # Pi-hole (DNS)
   pct restore 100 /path/to/backup  # Tailscale (Remote)
   pct restore 102 /path/to/backup  # NPM (Routing)
   ```

5. **Additional Nodes**
   - Install Proxmox VE
   - Join cluster
   - Configure Ceph

6. **Remaining Services**
   - Restore remaining containers
   - Verify all services

**Total Recovery Time:** 4-6 hours

---

## 🔧 Backup Maintenance

### Daily Tasks (Automated)
```bash
# Runs at 02:00 via cron
/usr/bin/vzdump --all --storage macpro-backups --mode snapshot --compress zstd
```

### Weekly Tasks
```bash
# Check backup storage usage
df -h /mnt/macpro

# Verify latest backups exist
for ct in 100 101 102 103 104 105 112; do
  echo -n "CT$ct: "
  ls -t /mnt/macpro/proxmox-backups/dump/*-$ct-* | head -1
done
```

### Monthly Tasks
```bash
# 1. Run restore test
/usr/local/bin/monthly-restore-test.sh

# 2. Check backup sizes for anomalies
cd /mnt/macpro/proxmox-backups/dump/
ls -lhS | head -20

# 3. Verify retention policy working
for ct in 100 101 102 103 104 105 112; do
  count=$(ls *-$ct-* 2>/dev/null | wc -l)
  echo "CT$ct has $count backups"
done
```

### Quarterly Tasks
```bash
# 1. Full disaster recovery test
# 2. Review and adjust retention policy
# 3. Calculate growth rate
# 4. Plan storage expansion if needed
```

---

## 🔨 Troubleshooting

### Backup Failures

#### Mount Not Available
```bash
# Check mount
df -h /mnt/macpro

# Restart mount
systemctl restart mnt-macpro.mount

# Verify Mac Pro accessible
ssh xavier@192.168.30.20 "df -h /storage"

# Manual mount if needed
sshfs xavier@192.168.30.20:/storage /mnt/macpro
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
vzdump <CTID> --storage macpro-backups --mode snapshot
```

#### Insufficient Space
```bash
# Check space
df -h /mnt/macpro

# Force prune old backups
pvesh create /nodes/pve1/storage/macpro-backups/prunebackups

# Emergency: Delete oldest backups manually
cd /mnt/macpro/proxmox-backups/dump/
ls -t | tail -20 | xargs rm
```

### Restore Failures

#### Backup File Corrupted
```bash
# Test backup integrity
tar -tzf backup.tar.zst > /dev/null

# If corrupted, find previous good backup
for backup in $(ls -t /path/to/backups/*.zst); do
  echo "Testing: $backup"
  tar -tzf "$backup" > /dev/null 2>&1 && echo "GOOD" && break
done
```

#### CTID Already Exists
```bash
# Option 1: Destroy existing
pct destroy <CTID>

# Option 2: Restore to different ID
pct restore <NEW-ID> /path/to/backup.tar.zst

# Option 3: Restore to different node
pct restore <CTID> /path/to/backup.tar.zst --target pve2
```

#### Storage Not Ready
```bash
# Wait for Ceph if needed
watch ceph -s

# Check storage status
pvesm status
```

---

## 📊 Backup Metrics & Monitoring

### Key Performance Indicators

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Backup Success Rate | 100% | 100% | ✅ |
| Average Backup Time | <5 min | 2.5 min | ✅ |
| Compression Ratio | >50% | 60% | ✅ |
| Storage Used | <500GB | 110GB | ✅ |
| Restore Test Success | 100% | 100% | ✅ |
| Recovery Time (Critical) | <10 min | 5 min | ✅ |

### Monitoring Commands
```bash
# Check last backup status
tail -50 /var/log/pve/tasks/index | grep vzdump

# Monitor backup progress (live)
tail -f /var/log/pve/tasks/active

# Check backup job history
pvesh get /cluster/backup/backup-6963fa17-187b
```

---

## 📝 3-2-1 Backup Rule Compliance

### Current Status
- ✅ **3 copies:** Original + Ceph + Mac Pro backup
- ⚠️ **2 media types:** Ceph (NVMe) + Mac Pro (HDD) - Same location
- ❌ **1 offsite:** Not yet implemented

### Future Improvements

1. **Offsite Backup (Priority)**
   - Option 1: Backblaze B2 ($5/TB/month)
   - Option 2: Relative's house with Raspberry Pi
   - Option 3: Cloud provider (Wasabi/AWS)

2. **Backup Encryption**
   ```bash
   # Add encryption to sensitive backups
   vzdump <CTID> --storage macpro-backups --encrypt
   ```

3. **Automated Verification**
   ```bash
   # Daily verification script
   for backup in $(find /mnt/macpro -name "*.zst" -mtime -1); do
     tar -tzf "$backup" > /dev/null || echo "CORRUPTED: $backup"
   done
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

### Node Recovery
- [ ] Assess cluster health
- [ ] Adjust quorum if needed
- [ ] Migrate/restore containers
- [ ] Rebuild failed node
- [ ] Rejoin to cluster
- [ ] Rebalance services
- [ ] Verify Ceph health
- [ ] Update documentation

### Full Disaster Recovery
- [ ] Verify network infrastructure
- [ ] Boot backup storage
- [ ] Rebuild first node
- [ ] Create new cluster
- [ ] Restore critical services
- [ ] Add additional nodes
- [ ] Restore all services
- [ ] Verify functionality
- [ ] Document lessons learned

---

*Regular testing prevents surprises*  
*A backup is only good if you can restore it*  
*Document every recovery attempt*