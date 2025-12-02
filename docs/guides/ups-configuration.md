# 🔋 UPS Configuration Guide

**Last Updated:** 2025-12-02  
**UPS Model:** CyberPower CP1600EPFCLCD-AU  
**Monitoring Software:** NUT (Network UPS Tools) 2.8.1  
**Status:** ✅ Fully Operational

## 📋 Table of Contents

1. [Overview](#overview)
2. [Hardware Setup](#hardware-setup)
3. [Architecture](#architecture)
4. [NUT Configuration](#nut-configuration)
5. [Cluster-Aware Shutdown](#cluster-aware-shutdown)
6. [Monitoring Commands](#monitoring-commands)
7. [Testing Procedures](#testing-procedures)
8. [Troubleshooting](#troubleshooting)
9. [Maintenance](#maintenance)
10. [Uptime Kuma Integration](#uptime-kuma-integration)

---

## Overview

### UPS Specifications

| Specification | Value |
|---------------|-------|
| Model | CyberPower CP1600EPFCLCD-AU |
| Capacity | 1600VA / 1000W |
| Battery Type | Lead Acid (PbAcid) |
| Battery Voltage | 24V nominal |
| Output Voltage | 230V |
| Battery Backed Outlets | 6 |
| USB Interface | Yes (HID-compliant) |
| USB Vendor:Product | 0764:0601 |

### Protected Equipment

| Device | Power Draw (Idle) | Notes |
|--------|-------------------|-------|
| pve1 (HP Elite Mini) | ~15W | NUT Master, USB connected |
| pve2 (HP Elite Mini) | ~15W | NUT Slave |
| pve3 (HP Elite Mini) | ~15W | NUT Slave |
| OPNsense (Protectli FW4C) | ~12W | Router |
| UniFi Switch Lite 16 PoE | ~10W | Network switch |
| Mac Pro (Late 2013) | ~45W | NAS server |
| Promise Pegasus R6 | ~30W | Storage array |
| **Total** | **~142W** | **17% UPS load** |

### Estimated Runtime

| Load | Runtime |
|------|---------|
| Current (17%) | ~34-45 minutes |
| 50% | ~15 minutes |
| 100% | ~5 minutes |

---

## Hardware Setup

### Physical Connections

```
CyberPower CP1600EPFCLCD
├── USB Cable ──────────► pve1 (192.168.10.11)
│
├── Battery Outlet 1 ───► Power Strip
│                         ├── pve1
│                         ├── pve2
│                         └── pve3
│
├── Battery Outlet 2 ───► OPNsense Router
├── Battery Outlet 3 ───► UniFi Switch
├── Battery Outlet 4 ───► Mac Pro
├── Battery Outlet 5 ───► Pegasus Array
└── Battery Outlet 6 ───► (Spare)
```

### USB Detection

Verify UPS is detected on pve1:

```bash
lsusb | grep -i cyber
# Expected: Bus 001 Device 002: ID 0764:0601 Cyber Power System, Inc. PR1500LCDRT2U UPS
```

---

## Architecture

### NUT Network Topology

```
                    ┌─────────────────────┐
                    │   CyberPower UPS    │
                    │  CP1600EPFCLCD-AU   │
                    └──────────┬──────────┘
                               │ USB
                               ▼
                    ┌─────────────────────┐
                    │       pve1          │
                    │   NUT Master        │
                    │   (netserver)       │
                    │                     │
                    │ LISTEN:             │
                    │  - 127.0.0.1:3493   │
                    │  - 192.168.10.11    │
                    │  - 192.168.30.11    │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
┌─────────────────┐ ┌─────────────────┐ ┌─────────────────┐
│      pve2       │ │      pve3       │ │    Mac Pro      │
│   NUT Slave     │ │   NUT Slave     │ │   NUT Slave     │
│  (netclient)    │ │  (netclient)    │ │  (netclient)    │
│                 │ │                 │ │                 │
│ Monitor:        │ │ Monitor:        │ │ Monitor:        │
│ 192.168.10.11   │ │ 192.168.10.11   │ │ 192.168.30.11   │
└─────────────────┘ └─────────────────┘ └─────────────────┘
   Management          Management           Storage
     VLAN                VLAN                VLAN
```

### Shutdown Sequence on Power Failure

```
Power Fails
    │
    ▼
UPS switches to battery (OL → OB)
    │
    ▼
All NUT clients notified
    │
    ▼
Battery reaches 10% (battery.charge.low)
    │
    ▼
NUT triggers FSD (Forced Shutdown)
    │
    ├──► pve1: Runs /usr/local/bin/cluster-shutdown.sh
    │         1. Set Ceph maintenance flags
    │         2. Stop containers gracefully
    │         3. Unmount SSHFS
    │         4. Shutdown
    │
    ├──► pve2: Runs /sbin/shutdown -h +0
    │
    ├──► pve3: Runs /sbin/shutdown -h +0
    │
    └──► Mac Pro: Runs /sbin/shutdown -h +0
```

---

## NUT Configuration

### pve1 (NUT Master)

#### /etc/nut/nut.conf
```ini
MODE=netserver
```

#### /etc/nut/ups.conf
```ini
maxretry = 3

[cyberpower]
    driver = usbhid-ups
    port = auto
    desc = "CyberPower CP1600EPFCLCD - Rack UPS"
    pollinterval = 15
```

#### /etc/nut/upsd.conf
```ini
# Listen on localhost
LISTEN 127.0.0.1 3493

# Listen on Management VLAN for pve2/pve3
LISTEN 192.168.10.11 3493

# Listen on Storage VLAN for Mac Pro
LISTEN 192.168.30.11 3493

MAXAGE 15
```

#### /etc/nut/upsd.users
```ini
[admin]
    password = <random-generated>
    actions = SET
    instcmds = ALL

[upsmon]
    password = Jva55rd@@1
    upsmon master
```

#### /etc/nut/upsmon.conf
```ini
# Monitor the local UPS as master
MONITOR cyberpower@localhost 1 upsmon Jva55rd@@1 master

# Commands
SHUTDOWNCMD "/usr/local/bin/cluster-shutdown.sh"
POWERDOWNFLAG /etc/killpower

# Timers
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
FINALDELAY 5

# Notifications
NOTIFYCMD /usr/sbin/upssched
NOTIFYFLAG ONLINE     SYSLOG+WALL
NOTIFYFLAG ONBATT     SYSLOG+WALL
NOTIFYFLAG LOWBATT    SYSLOG+WALL
NOTIFYFLAG FSD        SYSLOG+WALL
NOTIFYFLAG SHUTDOWN   SYSLOG+WALL

# Run as nut user
RUN_AS_USER nut
```

### pve2 and pve3 (NUT Slaves)

#### /etc/nut/nut.conf
```ini
MODE=netclient
```

#### /etc/nut/upsmon.conf
```ini
# Monitor UPS on pve1 as secondary
MONITOR cyberpower@192.168.10.11 1 upsmon Jva55rd@@1 slave

# Commands
SHUTDOWNCMD "/sbin/shutdown -h +0"
POWERDOWNFLAG /etc/killpower

# Timers
POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
FINALDELAY 5

# Notifications
NOTIFYFLAG ONLINE     SYSLOG+WALL
NOTIFYFLAG ONBATT     SYSLOG+WALL
NOTIFYFLAG LOWBATT    SYSLOG+WALL
NOTIFYFLAG FSD        SYSLOG+WALL
NOTIFYFLAG SHUTDOWN   SYSLOG+WALL

RUN_AS_USER nut
```

### Mac Pro (NUT Slave via Storage VLAN)

#### /etc/nut/nut.conf
```ini
MODE=netclient
```

#### /etc/nut/upsmon.conf
```ini
# Monitor UPS on pve1 via Storage VLAN
MONITOR cyberpower@192.168.30.11 1 upsmon Jva55rd@@1 slave

SHUTDOWNCMD "/sbin/shutdown -h +0"
POWERDOWNFLAG /etc/killpower

POLLFREQ 5
POLLFREQALERT 5
HOSTSYNC 15
DEADTIME 15
FINALDELAY 5

NOTIFYFLAG ONLINE     SYSLOG+WALL
NOTIFYFLAG ONBATT     SYSLOG+WALL
NOTIFYFLAG LOWBATT    SYSLOG+WALL
NOTIFYFLAG FSD        SYSLOG+WALL
NOTIFYFLAG SHUTDOWN   SYSLOG+WALL

RUN_AS_USER nut
```

**Note:** Mac Pro uses Ubuntu 22.04 with nut-client 2.7.4 (older version due to libc compatibility).

---

## Cluster-Aware Shutdown

### Script: /usr/local/bin/cluster-shutdown.sh (pve1 only)

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
echo "$(date): Ceph flags set"

# Step 2: Stop containers gracefully (reverse dependency order)
echo "$(date): Stopping containers..."
for ct in 112 107 106 104 105 103 102 101 100; do
    if pct status $ct 2>/dev/null | grep -q running; then
        echo "$(date): Stopping CT$ct..."
        pct shutdown $ct --timeout 30 2>/dev/null || pct stop $ct 2>/dev/null
    fi
done
echo "$(date): Containers stopped"

# Step 3: Unmount SSHFS backup storage
echo "$(date): Unmounting backup storage..."
umount /mnt/macpro 2>/dev/null
echo "$(date): Storage unmounted"

# Step 4: Proceed with shutdown
echo "$(date): Initiating system shutdown"
/sbin/shutdown -h +0
```

### Why Cluster-Aware?

1. **Ceph Flags** - Prevents Ceph from marking OSDs as "out" and starting unnecessary rebalancing
2. **Container Order** - Stops containers in reverse dependency order for clean shutdown
3. **SSHFS Unmount** - Prevents mount errors on next boot
4. **Logging** - Creates audit trail in /var/log/ups-shutdown.log

---

## Monitoring Commands

### Quick Status Check

```bash
# On pve1 (local)
upsc cyberpower@localhost | grep -E "^(ups.status|ups.load|battery.charge|battery.runtime):"

# From any node (via network)
upsc cyberpower@192.168.10.11 | grep -E "^(ups.status|ups.load|battery.charge|battery.runtime):"
```

### Full UPS Information

```bash
upsc cyberpower@localhost
```

### Key Variables

| Variable | Description | Normal Value |
|----------|-------------|--------------|
| ups.status | UPS status | OL (Online), OB (On Battery) |
| ups.load | Current load percentage | <80% |
| battery.charge | Battery charge percentage | 100% when charged |
| battery.runtime | Estimated runtime (seconds) | Varies with load |
| battery.charge.low | Shutdown threshold | 10% |
| input.voltage | Input AC voltage | ~230V |

### Service Status

```bash
# On pve1 (master)
systemctl status nut-server
systemctl status nut-monitor
systemctl status nut-driver.target

# On pve2/pve3/Mac Pro (slaves)
systemctl status nut-monitor
```

### View Logs

```bash
# NUT logs
journalctl -u nut-server -f
journalctl -u nut-monitor -f

# Shutdown script log (pve1 only)
tail -f /var/log/ups-shutdown.log
```

---

## Testing Procedures

### Test 1: Verify All Nodes Can Monitor UPS

```bash
# From your laptop
for node in 11 12 13; do
  echo "=== pve${node} ==="
  ssh root@192.168.10.$node "upsc cyberpower@192.168.10.11 ups.status battery.charge 2>/dev/null | head -3"
done

# Mac Pro
ssh xavier@192.168.30.20 "upsc cyberpower@192.168.30.11 ups.status battery.charge 2>/dev/null | head -3"
```

### Test 2: Verify NUT Services Running

```bash
for node in 11 12 13; do
  echo "=== pve${node} ==="
  ssh root@192.168.10.$node "systemctl is-active nut-monitor"
done
```

### Test 3: Simulate Power Failure (CAUTION!)

**WARNING:** This will trigger actual shutdown of all systems!

```bash
# Only run if you want to test full shutdown
# upsmon -c fsd
```

### Test 4: Test Shutdown Script Logic (Safe)

```bash
# Dry run - check what containers would be stopped
for ct in 112 107 106 104 105 103 102 101 100; do
    pct status $ct 2>/dev/null && echo "Would stop CT$ct"
done
```

---

## Troubleshooting

### UPS Not Detected

```bash
# Check USB connection
lsusb | grep -i cyber

# Check driver status
systemctl status nut-driver@cyberpower

# Restart driver
systemctl restart nut-driver.target
```

### Connection Refused

```bash
# Check upsd is listening
ss -tlnp | grep 3493

# Check upsd.conf LISTEN directives
cat /etc/nut/upsd.conf

# Restart server
systemctl restart nut-server
```

### Authentication Failed

```bash
# Verify password in upsd.users matches upsmon.conf
grep password /etc/nut/upsd.users
grep MONITOR /etc/nut/upsmon.conf
```

### Slave Not Receiving Updates

```bash
# Check firewall on pve1
iptables -L -n | grep 3493

# Test network connectivity
nc -zv 192.168.10.11 3493
```

### SSL Certificate Warning

The "Init SSL without certificate database" message is informational and can be ignored. NUT works fine without SSL for local network monitoring.

---

## Maintenance

### Monthly Tasks

1. **Check battery health:**
   ```bash
   upsc cyberpower@localhost battery.charge
   upsc cyberpower@localhost battery.runtime
   ```

2. **Review UPS logs:**
   ```bash
   journalctl -u nut-monitor --since "1 month ago" | grep -i "battery\|power"
   ```

3. **Test UPS self-test:**
   ```bash
   upscmd -u admin -p <password> cyberpower@localhost test.battery.start.quick
   ```

### Annual Tasks

1. **Battery replacement** (typically every 3-5 years)
2. **Capacity test** - Disconnect mains and time actual runtime
3. **Review shutdown thresholds** - Adjust battery.charge.low if needed

### Configuration Backup

```bash
# Backup NUT configs from pve1
tar -czf /root/nut-config-backup.tar.gz /etc/nut/ /usr/local/bin/cluster-shutdown.sh
```

---

## Uptime Kuma Integration

### Overview

UPS status is monitored via Uptime Kuma using a Push monitor. A script on pve1 runs every minute and pushes UPS health data to Uptime Kuma.

### Architecture

```
pve1 (cron every minute)
    │
    ▼
/usr/local/bin/ups-monitor-push.sh
    │
    ├── Reads UPS data via upsc
    ├── Determines health status
    │
    ▼
HTTP Push to Uptime Kuma
http://192.168.40.23:3001/api/push/ZMQELu5DML
```

### Monitor Configuration

**Uptime Kuma Settings:**
- **Monitor Type:** Push
- **Friendly Name:** UPS - CyberPower
- **Heartbeat Interval:** 60 seconds
- **Retries:** 3

### Push Script

**Location:** `/usr/local/bin/ups-monitor-push.sh` (on pve1)

```bash
#!/bin/bash
# UPS Monitor Push Script for Uptime Kuma
# Pushes UPS health status every minute

PUSH_URL="http://192.168.40.23:3001/api/push/ZMQELu5DML"
UPS_NAME="cyberpower@localhost"

# Get UPS data
UPS_STATUS=$(upsc $UPS_NAME ups.status 2>/dev/null)
BATTERY=$(upsc $UPS_NAME battery.charge 2>/dev/null)
LOAD=$(upsc $UPS_NAME ups.load 2>/dev/null)
RUNTIME=$(upsc $UPS_NAME battery.runtime 2>/dev/null)

# Calculate runtime in minutes
if [ ! -z "$RUNTIME" ]; then
    RUNTIME_MIN=$((RUNTIME / 60))
else
    RUNTIME_MIN="0"
fi

# Determine health status
if [ -z "$UPS_STATUS" ]; then
    STATUS="down"
    MSG="UPS not responding"
elif [[ "$UPS_STATUS" == *"OB"* ]]; then
    STATUS="up"
    MSG="ON_BATTERY-${BATTERY}pct-${RUNTIME_MIN}min-${LOAD}pct_load"
elif [[ "$UPS_STATUS" == "OL"* ]] && [ "$BATTERY" -ge 50 ]; then
    STATUS="up"
    MSG="Online-Batt_${BATTERY}pct-Load_${LOAD}pct-Runtime_${RUNTIME_MIN}min"
elif [[ "$UPS_STATUS" == "OL"* ]] && [ "$BATTERY" -lt 50 ]; then
    STATUS="up"
    MSG="Online-LOW_BATT_${BATTERY}pct-Load_${LOAD}pct"
else
    STATUS="up"
    MSG="Status_${UPS_STATUS}-Batt_${BATTERY}pct-Load_${LOAD}pct"
fi

# Push to Uptime Kuma (URL-encode by using --data-urlencode)
curl -s -G "$PUSH_URL" --data-urlencode "status=$STATUS" --data-urlencode "msg=$MSG" --data-urlencode "ping=$LOAD" > /dev/null 2>&1
```

### Cron Job

**Location:** `/etc/cron.d/ups-monitor` (on pve1)

```bash
* * * * * root /usr/local/bin/ups-monitor-push.sh
```

### What Gets Monitored

| Field | Value | Notes |
|-------|-------|-------|
| Status | up/down | Based on UPS reachability and status |
| Message | Status string | Shows battery %, load %, runtime |
| Ping | Load % | Displayed as "response time" graph |

### Status Messages

| UPS State | Message Format |
|-----------|----------------|
| Online, healthy | `Online-Batt_100pct-Load_17pct-Runtime_40min` |
| Online, low battery | `Online-LOW_BATT_30pct-Load_17pct` |
| On battery | `ON_BATTERY-85pct-30min-17pct_load` |
| Unreachable | `UPS not responding` |

### Troubleshooting Uptime Kuma Integration

**Monitor shows "Pending" or no data:**
```bash
# Test push manually from pve1
curl -v "http://192.168.40.23:3001/api/push/ZMQELu5DML?status=up&msg=test&ping=1"

# Should return: {"ok":true}
```

**Script not running:**
```bash
# Check cron job exists
cat /etc/cron.d/ups-monitor

# Run script manually with debug
bash -x /usr/local/bin/ups-monitor-push.sh
```

**URL encoding issues:**
The script uses `curl -G --data-urlencode` to properly encode special characters in the message. If messages contain spaces or special characters, they must be URL-encoded.

### Recreation Steps

If you need to recreate this setup:

1. **Create Push Monitor in Uptime Kuma:**
   - Add New Monitor → Type: Push
   - Name: "UPS - CyberPower"
   - Heartbeat: 60 seconds
   - Copy the Push URL

2. **Create script on pve1:**
   ```bash
   # Update PUSH_URL with your actual URL
   nano /usr/local/bin/ups-monitor-push.sh
   chmod +x /usr/local/bin/ups-monitor-push.sh
   ```

3. **Test the script:**
   ```bash
   /usr/local/bin/ups-monitor-push.sh
   # Check Uptime Kuma - should show green
   ```

4. **Add cron job:**
   ```bash
   echo "* * * * * root /usr/local/bin/ups-monitor-push.sh" > /etc/cron.d/ups-monitor
   ```

---

## Quick Reference Card

### Key Files

| File | Location | Purpose |
|------|----------|---------|
| nut.conf | /etc/nut/ | Mode setting (netserver/netclient) |
| ups.conf | /etc/nut/ | UPS definition (pve1 only) |
| upsd.conf | /etc/nut/ | Server config (pve1 only) |
| upsd.users | /etc/nut/ | Authentication |
| upsmon.conf | /etc/nut/ | Monitor config |
| cluster-shutdown.sh | /usr/local/bin/ | Graceful shutdown (pve1) |
| ups-monitor-push.sh | /usr/local/bin/ | Uptime Kuma push script (pve1) |
| ups-monitor | /etc/cron.d/ | Cron job for push script (pve1) |

### Key Services

| Service | Runs On | Purpose |
|---------|---------|---------|
| nut-driver.target | pve1 | USB driver |
| nut-server | pve1 | Network server |
| nut-monitor | All | Monitoring daemon |

### Emergency Commands

```bash
# Force immediate shutdown (DANGEROUS)
upsmon -c fsd

# Cancel scheduled shutdown
shutdown -c

# Manual graceful cluster shutdown
/usr/local/bin/cluster-shutdown.sh
```

---

*UPS monitoring protects your infrastructure from power failures*  
*Test your backups, test your UPS, sleep well*