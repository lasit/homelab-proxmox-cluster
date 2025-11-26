# 🔌 Power Management Guide

**Last Updated:** 2025-11-24  
**Purpose:** Safe procedures for cluster shutdown, startup, and power management  
**Critical:** Follow sequences exactly to prevent data loss

## 📚 Table of Contents

1. [Quick Reference](#quick-reference)
2. [Pre-Shutdown Checklist](#pre-shutdown-checklist)
3. [Complete Shutdown Procedure](#complete-shutdown-procedure)
4. [Complete Startup Procedure](#complete-startup-procedure)
5. [Emergency Procedures](#emergency-procedures)
6. [UPS Management](#ups-management)
7. [Power Consumption](#power-consumption)
8. [Maintenance Windows](#maintenance-windows)

---

## ⚡ Quick Reference

### Shutdown Sequence (8-14 minutes)
```bash
Containers → Ceph Flags → Proxmox Nodes → Mac Pro NAS → Physical Power
```

### Startup Sequence (20 minutes)
```bash
Mac Pro NAS → Proxmox Nodes → Clear Ceph Flags → Verify Services
```

### Critical Commands
```bash
# Before shutdown - Set Ceph maintenance
ceph osd set noout && ceph osd set nobackfill && ceph osd set norebalance

# After startup - Clear Ceph maintenance
ceph osd unset noout && ceph osd unset nobackfill && ceph osd unset norebalance
```

### What Stays Running
- ✅ OPNsense router (always on for network)
- ✅ UniFi switch (always on for connectivity)
- ✅ ISP router (internet gateway)

### Service Impact During Shutdown
- ❌ All containerized services unavailable
- ❌ DNS ad-blocking (Pi-hole) offline
- ❌ Remote access (Tailscale) offline
- ❌ Web services inaccessible
- ✅ Internet still works (via OPNsense)
- ✅ Smart home devices continue (10.1.1.x network)

---

## 📋 Pre-Shutdown Checklist

### 1. Verify System Health
```bash
# Check cluster status
ssh root@192.168.10.11 "pvecm status"

# Check Ceph health
ssh root@192.168.10.11 "ceph -s"

# List running containers
ssh root@192.168.10.11 "pct list | grep running"
```

**Expected:**
- Cluster: 3 nodes online with quorum
- Ceph: HEALTH_OK or HEALTH_WARN
- Containers: 7 running (CT 100-105, 112)

### 2. Notify Users (If Applicable)
- Inform about maintenance window
- Expected downtime duration
- Services that will be unavailable

### 3. Configure DNS Fallback
```bash
# Ensure laptop has dual DNS configured
nmcli connection show "Wired connection 1" | grep ipv4.dns
# Should show: 192.168.40.53,192.168.10.1

# If not configured:
sudo nmcli connection modify "Wired connection 1" ipv4.dns "192.168.40.53 192.168.10.1"
sudo nmcli connection down "Wired connection 1" && sudo nmcli connection up "Wired connection 1"
```

### 4. Document Reason
```bash
echo "$(date): Shutdown for [REASON]" >> ~/homelab-maintenance.log
```

---

## 🛑 Complete Shutdown Procedure

### Phase 1: Stop All Containers (2 minutes)

**Stop in reverse dependency order:**

```bash
# Stop n8n automation
ssh root@192.168.10.11 "pct stop 112"
sleep 10

# Stop Nextcloud (depends on MariaDB)
ssh root@192.168.10.11 "pct stop 104"
sleep 10

# Stop MariaDB database
ssh root@192.168.10.11 "pct stop 105"
sleep 10

# Stop monitoring and proxy
ssh root@192.168.10.11 "pct stop 103"  # Uptime Kuma
sleep 10
ssh root@192.168.10.11 "pct stop 102"  # Nginx Proxy Manager
sleep 10

# Stop core services last
ssh root@192.168.10.11 "pct stop 101"  # Pi-hole
sleep 10
ssh root@192.168.10.11 "pct stop 100"  # Tailscale

# Verify all stopped
ssh root@192.168.10.11 "pct list"
```

### Phase 2: Set Ceph Maintenance Flags (30 seconds)

**Prevent Ceph from rebalancing during shutdown:**

```bash
ssh root@192.168.10.11 << 'EOF'
# Set maintenance flags
ceph osd set noout
ceph osd set nobackfill
ceph osd set norebalance

# Verify flags are set
ceph osd dump | grep flags
exit
EOF
```

**Expected output:** `flags noout,nobackfill,norebalance`

### Phase 3: Shutdown Proxmox Nodes (5 minutes)

**Order: pve3 → pve2 → pve1** (maintain quorum longest)

```bash
# Shutdown pve3
ssh root@192.168.10.13 "shutdown -h now"
echo "pve3 shutting down..."
sleep 30

# Shutdown pve2
ssh root@192.168.10.12 "shutdown -h now"
echo "pve2 shutting down..."
sleep 30

# Shutdown pve1
ssh root@192.168.10.11 "shutdown -h now"
echo "pve1 shutting down..."
sleep 120

# Verify nodes are down
for node in 11 12 13; do
  ping -c 2 -W 1 192.168.10.$node > /dev/null 2>&1 && echo "pve$node still up!" || echo "pve$node down ✓"
done
```

### Phase 4: Shutdown Mac Pro NAS (1 minute)

```bash
# Add route if needed
sudo ip route add 192.168.30.0/24 via 192.168.10.1 2>/dev/null

# SSH and shutdown
ssh xavier@192.168.30.20 << 'EOF'
sudo umount /storage
sudo shutdown -h now
EOF

# Wait for shutdown
sleep 60

# Verify
ping -c 2 -W 1 192.168.30.20 > /dev/null 2>&1 && echo "Mac Pro still up!" || echo "Mac Pro down ✓"
```

### Phase 5: Physical Power Off (Optional)

**Wait 5 minutes after shutdown commands, then:**

1. **HP Elite Mini nodes:**
   - Unplug power cables
   - Verify all LEDs off

2. **Mac Pro:**
   - Unplug power cable
   - Power LED should be off

3. **Pegasus Array:**
   - Unplug AFTER Mac Pro is off
   - Thunderbolt LED should be off

**Never disconnect:**
- OPNsense router
- UniFi switch
- ISP router

---

## 🔄 Complete Startup Procedure

### Phase 1: Power On Mac Pro NAS (4 minutes)

1. **Connect Pegasus array power**
   - Wait for Thunderbolt LED
   - Wait 30 seconds for initialization

2. **Power on Mac Pro**
   - Press power button
   - Wait 3 minutes for boot

3. **Verify:**
```bash
# Add route if needed
sudo ip route add 192.168.30.0/24 via 192.168.10.1 2>/dev/null

# Test connectivity
ping -c 2 192.168.30.20

# Verify storage mounted
ssh xavier@192.168.30.20 "df -h | grep storage"
```

### Phase 2: Power On Proxmox Nodes (8 minutes)

**Order: pve1 → pve2 → pve3** (with 2-minute intervals)

1. **Power on pve1**
   - Press power button or use IPMI
   - Wait 2 minutes for boot

2. **Power on pve2**
   - Press power button or use IPMI
   - Wait 2 minutes for boot

3. **Power on pve3**
   - Press power button or use IPMI
   - Wait 2 minutes for boot

4. **Verify nodes:**
```bash
# Check each node
for node in 11 12 13; do
  ping -c 2 192.168.10.$node > /dev/null 2>&1 && echo "pve$node up ✓" || echo "pve$node still down!"
done
```

### Phase 3: Verify Cluster Formation (1 minute)

```bash
# Wait 5 minutes after last node boots
sleep 300

# Check cluster status
ssh root@192.168.10.11 "pvecm status"
```

**Expected output:**
- Quorum: Yes
- Nodes: 3
- Total votes: 3

**If no quorum:**
```bash
# Restart cluster services on each node
for node in 11 12 13; do
  ssh root@192.168.10.$node "systemctl restart pve-cluster"
done
```

### Phase 4: Clear Ceph Maintenance (30 seconds)

```bash
ssh root@192.168.10.11 << 'EOF'
# Remove maintenance flags
ceph osd unset noout
ceph osd unset nobackfill
ceph osd unset norebalance

# Check Ceph health
ceph -s
EOF
```

**Expected:** 
- Initially: HEALTH_WARN (recovery in progress)
- After 5-10 minutes: HEALTH_OK

### Phase 5: Verify Container Auto-Start (2 minutes)

**All containers have onboot=1 and should start automatically:**

```bash
# Check container status
ssh root@192.168.10.11 "pct list"
```

**Expected:** All containers showing "running"

**If any stopped, start manually:**
```bash
ssh root@192.168.10.11 "pct start <CTID>"
```

### Phase 6: Verify Services (2 minutes)

```bash
# Test DNS
nslookup google.com 192.168.40.53

# Test web services
for svc in pihole nginx status cloud automation; do
  echo -n "$svc: "
  curl -sI http://$svc.homelab.local 2>/dev/null | head -1 || echo "Failed"
done

# Test remote access
ssh root@192.168.10.11 "pct exec 100 -- tailscale status"
```

### Phase 7: Verify Backup Mounts (1 minute)

```bash
# Check SSHFS mounts on all nodes
for node in 11 12 13; do
  echo "=== pve$node ==="
  ssh root@192.168.10.$node "df -h | grep macpro || echo 'Mount missing!'"
done

# If mount missing, restart:
ssh root@192.168.10.<node> "systemctl restart mnt-macpro.mount"
```

### Phase 8: Final Verification

```bash
# Run health check
ssh root@192.168.10.11 << 'EOF'
echo "=== Cluster Health ==="
pvecm status | grep -E "Quorum|Total"
echo ""
echo "=== Ceph Status ==="
ceph -s | head -5
echo ""
echo "=== Container Status ==="
pct list | grep -c running && echo "containers running"
echo ""
echo "=== Backup Mount ==="
df -h /mnt/macpro | tail -1
EOF
```

---

## 🚨 Emergency Procedures

### Emergency Shutdown (Power Loss Imminent)

**Fastest possible shutdown (3 minutes):**

```bash
# Quick container stop (no wait)
for ct in 112 104 105 103 102 101 100; do
  ssh root@192.168.10.11 "pct stop $ct &"
done

# Set Ceph flags
ssh root@192.168.10.11 "ceph osd set noout nobackfill norebalance"

# Shutdown all nodes simultaneously
for node in 11 12 13; do
  ssh root@192.168.10.$node "shutdown -h now" &
done

# Shutdown Mac Pro
ssh xavier@192.168.30.20 "sudo shutdown -h now" &
```

### Single Node Emergency Restart

```bash
# If one node needs emergency restart
NODE_IP=192.168.10.12  # Change as needed

# Migrate critical containers first (if possible)
ssh root@$NODE_IP "pct migrate <CTID> <target-node>"

# Then restart
ssh root@$NODE_IP "shutdown -r now"
```

### Power Failure Recovery

After unexpected power loss:

1. **Wait 10 minutes** after power restoration
2. **Follow normal startup procedure** from Phase 1
3. **Check for filesystem issues:**
```bash
# On each node
pct fsck <CTID>
```
4. **Check Ceph for inconsistencies:**
```bash
ceph pg repair <pg-id>  # If needed
```

---

## 🔋 UPS Management

### Current Status
- **UPS Installed:** ❌ Not yet
- **Planned:** Dual UPS strategy (N+1 redundancy)
- **Target:** 3200VA total capacity

### Future UPS Configuration

**UPS 1 (1600VA):**
- pve1, pve2
- OPNsense router
- UniFi switch

**UPS 2 (1600VA):**
- pve3
- Mac Pro + Pegasus
- Monitor/keyboard

### Automated Shutdown (When UPS Installed)

```bash
# Install NUT (Network UPS Tools)
apt install nut nut-client nut-server

# Configure for automated shutdown at 20% battery
# /etc/nut/upsmon.conf
SHUTDOWNCMD "/usr/local/bin/cluster-shutdown.sh"
```

---

## ⚡ Power Consumption

### Current Draw

| Component | Idle | Load | Daily kWh |
|-----------|------|------|-----------|
| 3× HP Elite Mini | 45W | 75W | 1.8 |
| OPNsense Router | 12W | 20W | 0.48 |
| UniFi Switch | 10W | 15W | 0.36 |
| Mac Pro + Pegasus | 75W | 150W | 3.0 |
| **Total** | **142W** | **260W** | **5.64** |

### Cost Analysis (Darwin rates: $0.30/kWh)

- **Daily:** $1.69 AUD
- **Monthly:** $51 AUD
- **Annual:** $620 AUD

### Power Optimization Tips

1. **Enable CPU power scaling:**
```bash
# On each Proxmox node
echo "powersave" > /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor
```

2. **Spin down Mac Pro drives:**
```bash
# On Mac Pro
sudo hdparm -S 240 /dev/sda  # Standby after 20 min
```

3. **Schedule non-critical services:**
```bash
# Stop development containers at night
0 22 * * * pct stop 112  # n8n
0 6 * * * pct start 112
```

---

## 🗓️ Maintenance Windows

### Recommended Schedule

**Monthly Maintenance (First Sunday, 2 AM):**
- Verify backups
- Update containers
- Clean up logs
- Test UPS (when installed)

**Quarterly Maintenance:**
- Firmware updates
- Deep cleaning (dust filters)
- Cable management
- Thermal paste check

### Maintenance Window Procedure

1. **Week Before:**
   - Schedule notification
   - Prepare updates
   - Test backup restore

2. **Day Before:**
   - Final reminder
   - Verify backup completeness
   - Stage any hardware

3. **Maintenance Day:**
   - Follow shutdown procedure
   - Perform maintenance
   - Follow startup procedure
   - Verify all services
   - Document changes

4. **Day After:**
   - Monitor for issues
   - Update documentation
   - Close maintenance ticket

---

## 📝 Shutdown/Startup Log Template

```markdown
## Maintenance Log Entry

**Date:** YYYY-MM-DD
**Reason:** [Power maintenance|Updates|Hardware change|Other]
**Duration:** HH:MM

### Shutdown
- [ ] Pre-checks completed
- [ ] DNS fallback configured
- [ ] Containers stopped (Time: __)
- [ ] Ceph flags set
- [ ] Nodes shut down (Time: __)
- [ ] Mac Pro shut down (Time: __)
- [ ] Total shutdown time: __

### Maintenance Performed
- List of changes/updates

### Startup  
- [ ] Mac Pro started (Time: __)
- [ ] Nodes started (Time: __)
- [ ] Cluster formed
- [ ] Ceph flags cleared
- [ ] Containers running
- [ ] Services verified
- [ ] Mounts verified
- [ ] Total startup time: __

### Issues Encountered
- None / List any problems

### Post-Maintenance Status
- All systems operational: [Yes/No]
- Follow-up required: [Yes/No]
```

---

## 🔧 Troubleshooting

### Common Issues

**Cluster won't form quorum:**
```bash
pvecm expected 1  # Temporary
systemctl restart pve-cluster
pvecm expected 3  # After all nodes up
```

**Containers won't auto-start:**
```bash
# Check onboot setting
pct config <CTID> | grep onboot
# Enable if missing
pct set <CTID> -onboot 1
```

**Mac Pro mount not working:**
```bash
# Re-add SSH keys if needed
ssh-keygen -R 192.168.30.20
ssh-copy-id xavier@192.168.30.20
systemctl restart mnt-macpro.mount
```

**DNS not working after startup:**
```bash
# Start Pi-hole manually if needed
ssh root@192.168.10.11 "pct start 101"
# Wait 30 seconds
nslookup google.com 192.168.40.53
```

---

## ⏱️ Time Estimates

| Procedure | Minimum | Typical | Maximum |
|-----------|---------|---------|---------|
| Pre-shutdown checks | 2 min | 5 min | 10 min |
| Complete shutdown | 8 min | 10 min | 14 min |
| Complete startup | 15 min | 20 min | 25 min |
| Service verification | 2 min | 5 min | 10 min |
| **Total Downtime** | **25 min** | **35 min** | **49 min** |

---

*Always follow the sequence*  
*Never skip Ceph maintenance flags*  
*Document every maintenance event*