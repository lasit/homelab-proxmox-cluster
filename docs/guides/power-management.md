# 🔌 Power Management Guide

**Last Updated:** 2025-12-02  
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

### UPS Quick Check
```bash
# Check UPS status from pve1
upsc cyberpower@localhost | grep -E "^(ups.status|ups.load|battery.charge|battery.runtime):"
```

### What Stays Running
- ✅ OPNsense router (always on for network)
- ✅ UniFi switch (always on for connectivity)
- ✅ ISP router (internet gateway)
- ✅ UPS (provides backup power)

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

# Check UPS status
ssh root@192.168.10.11 "upsc cyberpower@localhost ups.status battery.charge"
```

**Expected:**
- Cluster: 3 nodes online with quorum
- Ceph: HEALTH_OK or HEALTH_WARN
- Containers: 9 running (CT 100-107, 112)
- UPS: OL (Online), 100% charge

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

# Stop UniFi Controller
ssh root@192.168.10.11 "pct stop 107"
sleep 10

# Stop Redis (if running)
ssh root@192.168.10.11 "pct stop 106"
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

# Verify storage mounted (may need manual mount)
ssh xavier@192.168.30.20 "df -h | grep storage"

# If storage not mounted, run manually:
ssh xavier@192.168.30.20 "sudo /usr/local/bin/mount-pegasus.sh"
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

### Phase 8: Verify UPS Monitoring

```bash
# Check UPS status
ssh root@192.168.10.11 "upsc cyberpower@localhost | grep -E '^(ups.status|ups.load|battery.charge|battery.runtime):'"

# Verify all nodes can see UPS
for node in 11 12 13; do
  echo "=== pve$node ==="
  ssh root@192.168.10.$node "upsc cyberpower@192.168.10.11 ups.status 2>/dev/null | head -1"
done
```

### Phase 9: Final Verification

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
echo ""
echo "=== UPS Status ==="
upsc cyberpower@localhost ups.status ups.load battery.charge 2>/dev/null | head -3
EOF
```

---

## 🚨 Emergency Procedures

### Emergency Shutdown (Power Loss Imminent)

**Fastest possible shutdown (3 minutes):**

```bash
# Quick container stop (no wait)
for ct in 112 107 106 104 105 103 102 101 100; do
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
- **UPS Installed:** ✅ Yes
- **Model:** CyberPower CP1600EPFCLCD-AU
- **Capacity:** 1600VA / 1000W
- **Current Load:** ~17% (~142W)
- **Estimated Runtime:** ~34-45 minutes at current load

### Protected Equipment

| Device | Role | NUT Status |
|--------|------|------------|
| pve1 | NUT Master (USB) | ✅ Connected |
| pve2 | NUT Slave | ✅ Monitoring |
| pve3 | NUT Slave | ✅ Monitoring |
| OPNsense | Protected | (No NUT client) |
| UniFi Switch | Protected | (No NUT client) |
| Mac Pro | NUT Slave (Storage VLAN) | ✅ Monitoring |
| Pegasus | Protected | (Via Mac Pro) |

### NUT Architecture

```
CyberPower UPS ──USB──► pve1 (NUT Master)
                              │
                    ┌─────────┼─────────┐
                    │         │         │
                    ▼         ▼         ▼
                  pve2      pve3    Mac Pro
               (Slave)    (Slave)  (Slave)
              via VLAN10  via VLAN10  via VLAN30
```

### Quick UPS Commands

```bash
# Check full status
upsc cyberpower@localhost

# Key metrics only
upsc cyberpower@localhost | grep -E "^(ups.status|ups.load|battery.charge|battery.runtime):"

# Check from slave nodes
upsc cyberpower@192.168.10.11 ups.status

# View NUT logs
journalctl -u nut-monitor -f
```

### UPS Status Codes

| Code | Meaning | Action |
|------|---------|--------|
| OL | Online (mains power) | Normal operation |
| OB | On Battery | Power failure - monitoring |
| LB | Low Battery | Shutdown imminent |
| FSD | Forced Shutdown | Shutdown in progress |

### Automatic Shutdown Behavior

When power fails:
1. UPS switches to battery (`OL` → `OB`)
2. All NUT clients receive notification
3. Systems continue running on battery
4. At 10% battery (`battery.charge.low`), NUT triggers FSD
5. **pve1** runs `/usr/local/bin/cluster-shutdown.sh`:
   - Sets Ceph maintenance flags
   - Stops containers gracefully
   - Unmounts SSHFS
   - Initiates shutdown
6. **pve2, pve3, Mac Pro** shut down via standard NUT

### Cluster-Aware Shutdown Script (pve1)

Location: `/usr/local/bin/cluster-shutdown.sh`

```bash
#!/bin/bash
# Cluster-aware UPS shutdown script
# Called by NUT when battery is critical

LOG=/var/log/ups-shutdown.log
exec >> $LOG 2>&1

echo "========================================"
echo "$(date): UPS shutdown initiated"

# Step 1: Set Ceph maintenance flags
echo "$(date): Setting Ceph maintenance flags..."
ceph osd set noout
ceph osd set nobackfill
ceph osd set norebalance

# Step 2: Stop containers gracefully
echo "$(date): Stopping containers..."
for ct in 112 107 106 104 105 103 102 101 100; do
    if pct status $ct 2>/dev/null | grep -q running; then
        echo "$(date): Stopping CT$ct..."
        pct shutdown $ct --timeout 30 2>/dev/null || pct stop $ct 2>/dev/null
    fi
done

# Step 3: Unmount SSHFS
echo "$(date): Unmounting backup storage..."
umount /mnt/macpro 2>/dev/null

# Step 4: Shutdown
echo "$(date): Initiating system shutdown"
/sbin/shutdown -h +0
```

### Configuration Files

See [UPS Configuration Guide](docs/guides/ups-configuration.md) for complete NUT configuration details.

### Testing UPS

**Safe tests (won't cause shutdown):**
```bash
# Verify NUT services
systemctl status nut-server nut-monitor

# Check all slaves can connect
for node in 12 13; do
  ssh root@192.168.10.$node "upsc cyberpower@192.168.10.11 ups.status"
done

# Check Mac Pro can connect
ssh xavier@192.168.30.20 "upsc cyberpower@192.168.30.11 ups.status"
```

**Full test (WILL cause shutdown):**
```bash
# DO NOT RUN unless you want to test full shutdown
# upsmon -c fsd
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

### UPS Runtime Estimates

| Load | Percentage | Est. Runtime |
|------|------------|--------------|
| Current (142W) | 17% | ~34-45 min |
| All devices active (260W) | 26% | ~20-25 min |
| 50% load (500W) | 50% | ~15 min |
| Full load (1000W) | 100% | ~5 min |

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
- Check UPS battery health

**Quarterly Maintenance:**
- Firmware updates
- Deep cleaning (dust filters)
- Cable management
- Thermal paste check
- UPS capacity test

### UPS Maintenance

**Monthly:**
```bash
# Check battery health
upsc cyberpower@localhost battery.charge
upsc cyberpower@localhost battery.runtime

# Review logs for power events
journalctl -u nut-monitor --since "1 month ago" | grep -i "battery\|power"
```

**Annually:**
- Consider battery replacement (every 3-5 years)
- Perform full capacity test

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

### Pre-Maintenance
- [ ] UPS status checked (charge: __%, load: __%)
- [ ] Cluster health verified
- [ ] Backups confirmed

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
- [ ] Pegasus mounted
- [ ] Nodes started (Time: __)
- [ ] Cluster formed
- [ ] Ceph flags cleared
- [ ] Containers running
- [ ] Services verified
- [ ] Mounts verified
- [ ] UPS monitoring verified
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

**UPS not detected:**
```bash
# Check USB connection
lsusb | grep -i cyber

# Restart NUT driver
systemctl restart nut-driver.target
systemctl restart nut-server
```

**Slave can't connect to NUT master:**
```bash
# Check upsd is listening
ssh root@192.168.10.11 "ss -tlnp | grep 3493"

# Test connectivity
nc -zv 192.168.10.11 3493
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
*UPS protects hardware, proper shutdown protects data*  
*Document every maintenance event*