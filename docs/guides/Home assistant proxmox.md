# 🏠 Home Assistant on Proxmox Deployment Guide

**Last Updated:** 2025-11-26  
**Status:** Planned  
**Prerequisites:** UPS Installation (Phase 1), NUT Monitoring (Phase 2)  
**Estimated Deployment Time:** 4-6 hours

## 📋 Table of Contents

1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Network Verification](#network-verification)
4. [Container Deployment](#container-deployment)
5. [Initial Configuration](#initial-configuration)
6. [Integration Migration](#integration-migration)
7. [Pi Gate Control Setup](#pi-gate-control-setup)
8. [Smart Shutdown Automation](#smart-shutdown-automation)
9. [Testing Procedures](#testing-procedures)
10. [Cutover Plan](#cutover-plan)
11. [Rollback Procedure](#rollback-procedure)

---

## Overview

### Purpose

Deploy a new Home Assistant instance on the Proxmox cluster to:
- Run on UPS-protected infrastructure
- Integrate with UPS monitoring for smart shutdown
- Access Fronius battery levels for power decisions
- Maintain control of IoT devices on ISP network
- Enable proper backup via Proxmox vzdump

### Current State

| Component | Location | IP | Status |
|-----------|----------|-----|--------|
| Home Assistant (Main) | Raspberry Pi | 10.1.1.63 | Running - to be replaced |
| MQTT Broker | Separate Pi | 10.1.1.67 | Running - stays on ISP network |
| Fronius Inverter | ISP Network | 10.1.1.174 | Running |
| Reolink NVR | ISP Network | 10.1.1.46 | Running |
| Front Gate Relay | Pi GPIO | 10.1.1.63 | Running - Pi becomes gate-only |

### Target State

| Component | Location | IP | Status |
|-----------|----------|-----|--------|
| Home Assistant (Main) | Proxmox CT | 192.168.40.70 | New deployment |
| MQTT Broker | Separate Pi | 10.1.1.67 | Unchanged |
| Fronius Inverter | ISP Network | 10.1.1.174 | Accessed via routing |
| Reolink NVR | ISP Network | 10.1.1.46 | Accessed via routing |
| Front Gate Controller | Pi (simplified) | 10.1.1.63 | Controlled by new HA |

---

## Architecture

### Network Topology

```
┌─────────────────────────────────────────────────────────────────┐
│                 Proxmox Cluster (UPS Protected)                  │
│                 Services VLAN (192.168.40.x)                     │
│                                                                  │
│   ┌────────────────────┐         ┌────────────────────┐         │
│   │   Home Assistant   │         │    Other Services  │         │
│   │      CT113         │         │                    │         │
│   │   192.168.40.70    │         │  Nextcloud, n8n,   │         │
│   │                    │         │  Pi-hole, etc.     │         │
│   │  Integrations:     │         │                    │         │
│   │  • NUT (UPS)       │         └────────────────────┘         │
│   │  • Fronius         │                                        │
│   │  • MQTT            │                                        │
│   │  • Reolink         │                                        │
│   │  • Pi Gate Control │                                        │
│   └─────────┬──────────┘                                        │
│             │                                                    │
└─────────────┼────────────────────────────────────────────────────┘
              │
              │ OPNsense Routing (verified working)
              │
┌─────────────┼────────────────────────────────────────────────────┐
│             ▼          ISP Network (10.1.1.x)                    │
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│   │   Fronius    │  │  Reolink NVR │  │ Raspberry Pi │          │
│   │   Inverter   │  │  + 5 Cameras │  │  (Gate Only) │          │
│   │  10.1.1.174  │  │  10.1.1.46   │  │  10.1.1.63   │          │
│   │              │  │              │  │              │          │
│   │  Battery %   │  │  RTSP Feeds  │  │  GPIO→Relay  │          │
│   │  Solar Data  │  │  Occasional  │  │  →Front Gate │          │
│   └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│   │ MQTT Broker  │  │   Daikin AC  │  │   ESP32s     │          │
│   │  10.1.1.67   │  │ 10.1.1.20    │  │  10.1.1.12   │          │
│   │              │  │ 10.1.1.211   │  │  10.1.1.114  │          │
│   │  Port 1883   │  │              │  │              │          │
│   └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                  │
│   ┌──────────────┐  ┌──────────────┐                            │
│   │   Xiaomi     │  │ Roller Door  │                            │
│   │   Gateway    │  │  10.1.1.15   │                            │
│   │  10.1.1.60   │  │              │                            │
│   └──────────────┘  └──────────────┘                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### Data Flows

```
UPS Monitoring:
pve1 (NUT Server) ──► Home Assistant (NUT Integration)
                      │
                      ▼
                 ups.status sensor
                 battery.charge sensor

Fronius Battery:
Fronius (10.1.1.174) ──► Home Assistant (Fronius Integration)
                         │
                         ▼
                    sensor.battery_level

Smart Shutdown Decision:
IF ups.status = "OB" (On Battery)
AND fronius_battery < 15%
THEN trigger shutdown automation

Gate Control:
Home Assistant ──► Pi (10.1.1.63) ──► GPIO ──► Relay ──► Gate
              REST/MQTT              Physical
```

---

## Network Verification

### Confirmed Working (Tested 2025-11-26)

Routing from Services VLAN to ISP network is operational:

```bash
# From pve1
root@pve1:~# ping -c 2 10.1.1.174  # Fronius ✓
root@pve1:~# ping -c 2 10.1.1.63   # Pi ✓
root@pve1:~# ping -c 2 10.1.1.67   # MQTT ✓

# From container on Services VLAN (192.168.40.x)
root@nextcloud:~# ping -c 2 10.1.1.174  # Fronius ✓
root@nextcloud:~# ping -c 2 10.1.1.63   # Pi ✓
```

### No Additional Network Configuration Required

OPNsense already routes traffic between VLANs. The new Home Assistant container will be able to reach all IoT devices on 10.1.1.x immediately.

---

## Container Deployment

### Container Specifications

| Setting | Value | Rationale |
|---------|-------|-----------|
| CT ID | 113 | Next available in sequence |
| Hostname | homeassistant |  |
| IP Address | 192.168.40.70 | Services VLAN, easy to remember |
| Gateway | 192.168.40.1 |  |
| DNS | 192.168.40.53 | Pi-hole |
| CPU | 2 cores | HA can be resource-hungry |
| RAM | 4096 MB | Comfortable for integrations |
| Swap | 2048 MB |  |
| Disk | 32 GB | Room for database, logs |
| Template | debian-12-standard | Base for Docker install |

### Deployment Steps

#### Step 1: Create Container

```bash
# SSH to pve1
ssh root@192.168.10.11

# Create the container
pct create 113 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname homeassistant \
  --cores 2 \
  --memory 4096 \
  --swap 2048 \
  --storage local-lvm \
  --rootfs local-lvm:32 \
  --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.70/24,gw=192.168.40.1 \
  --nameserver 192.168.40.53 \
  --searchdomain homelab.local \
  --onboot 1 \
  --unprivileged 1 \
  --features nesting=1

# Configure for Docker
cat >> /etc/pve/lxc/113.conf << 'EOF'
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
EOF

# Start container
pct start 113
```

#### Step 2: Install Docker

```bash
# Enter container
pct enter 113

# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y curl ca-certificates gnupg sudo

# Install Docker
curl -fsSL https://get.docker.com | sh

# Enable Docker
systemctl enable docker
systemctl start docker

# Install Docker Compose plugin
apt install -y docker-compose-plugin

# Verify
docker --version
docker compose version
```

#### Step 3: Deploy Home Assistant

```bash
# Create directory structure
mkdir -p /opt/homeassistant
cd /opt/homeassistant

# Create docker-compose.yml
cat > docker-compose.yml << 'EOF'
version: '3.8'

services:
  homeassistant:
    container_name: homeassistant
    image: ghcr.io/home-assistant/home-assistant:stable
    restart: unless-stopped
    privileged: true
    network_mode: host
    environment:
      - TZ=Australia/Darwin
    volumes:
      - ./config:/config
      - /run/dbus:/run/dbus:ro
EOF

# Create config directory
mkdir -p ./config

# Start Home Assistant
docker compose up -d

# Check status
docker compose ps

# View logs (wait for initial setup)
docker compose logs -f
# Press Ctrl+C after you see "Home Assistant initialized"
```

#### Step 4: Verify Container Running

```bash
# Exit container
exit

# Verify from Proxmox
pct status 113

# Test HTTP access
curl -I http://192.168.40.70:8123
```

### DNS and Proxy Configuration

#### Add DNS Entry to Pi-hole

```bash
pct exec 101 -- bash -c "
cat >> /etc/pihole/custom.list << 'EOF'
192.168.40.70 homeassistant.homelab.local
192.168.40.70 ha.homelab.local
EOF
pihole restartdns
"
```

#### Add Proxy Host in NPM (Optional)

If you want access via `ha.homelab.local`:

1. Access NPM: http://nginx.homelab.local
2. Add Proxy Host:
   - Domain: `ha.homelab.local`
   - Scheme: `http`
   - Forward Hostname: `192.168.40.70`
   - Forward Port: `8123`
   - Websockets Support: ✓ (important for HA)

---

## Initial Configuration

### First-Time Setup

1. Access Home Assistant: http://192.168.40.70:8123
2. Create admin account
3. Set location (Darwin, NT)
4. Configure units (metric)
5. Skip integrations for now (we'll add manually)

### Essential Settings

#### configuration.yaml Additions

```bash
# Enter container and edit config
pct exec 113 -- bash -c "cat >> /opt/homeassistant/config/configuration.yaml << 'EOF'

# Allow local network access
http:
  use_x_forwarded_for: true
  trusted_proxies:
    - 192.168.40.22  # Nginx Proxy Manager

# Recorder settings (database)
recorder:
  purge_keep_days: 14
  commit_interval: 30

# Logger settings
logger:
  default: warning
  logs:
    homeassistant.components.fronius: info
    homeassistant.components.nut: info
EOF"

# Restart Home Assistant to apply
pct exec 113 -- bash -c "cd /opt/homeassistant && docker compose restart"
```

---

## Integration Migration

### Migration Order

Migrate integrations one at a time, testing each before proceeding:

1. **NUT (UPS Monitoring)** - New, not on old HA
2. **Fronius (Solar/Battery)** - Critical for shutdown automation
3. **MQTT (IoT Devices)** - Many devices depend on this
4. **Reolink (Cameras)** - Occasional viewing
5. **Daikin (AC)** - Monitoring only
6. **Xiaomi Gateway** - Monitoring only
7. **Pi Gate Control** - After simplifying Pi

### Integration 1: NUT (UPS Monitoring)

**Prerequisite:** NUT server running on pve1 (Phase 2)

#### On pve1: Configure NUT Server

```bash
# Install NUT
apt update && apt install -y nut

# Configure UPS
cat > /etc/nut/ups.conf << 'EOF'
[cyberpower]
    driver = usbhid-ups
    port = auto
    desc = "CyberPower CP1600EPFCLCD"
EOF

# Configure network access
cat > /etc/nut/upsd.conf << 'EOF'
LISTEN 0.0.0.0 3493
EOF

# Configure users
cat > /etc/nut/upsd.users << 'EOF'
[homeassistant]
    password = YOUR_SECURE_PASSWORD_HERE
    upsmon slave

[admin]
    password = YOUR_ADMIN_PASSWORD_HERE
    actions = SET
    instcmds = ALL
EOF

# Set mode
cat > /etc/nut/nut.conf << 'EOF'
MODE=netserver
EOF

# Set permissions
chown root:nut /etc/nut/*.conf
chmod 640 /etc/nut/*.conf

# Start services
systemctl enable nut-server nut-driver
systemctl start nut-driver
systemctl start nut-server

# Verify
upsc cyberpower@localhost
```

#### In Home Assistant: Add NUT Integration

1. Go to Settings → Devices & Services → Add Integration
2. Search for "Network UPS Tools (NUT)"
3. Configure:
   - Host: `192.168.10.11`
   - Port: `3493`
   - Username: `homeassistant`
   - Password: `YOUR_SECURE_PASSWORD_HERE`
   - Alias: `cyberpower`

4. Entities created:
   - `sensor.cyberpower_status`
   - `sensor.cyberpower_battery_charge`
   - `sensor.cyberpower_load`
   - And more...

### Integration 2: Fronius (Solar/Battery)

1. Go to Settings → Devices & Services → Add Integration
2. Search for "Fronius"
3. Configure:
   - Host: `10.1.1.174`

4. Key entities:
   - `sensor.fronius_battery_state_of_charge` (or similar)
   - `sensor.fronius_power_grid`
   - `sensor.fronius_power_photovoltaics`

### Integration 3: MQTT

1. Go to Settings → Devices & Services → Add Integration
2. Search for "MQTT"
3. Configure:
   - Broker: `10.1.1.67`
   - Port: `1883`
   - Username/Password: (if configured on broker)

4. After adding, your ESP devices and other MQTT devices should auto-discover

### Integration 4: Reolink

1. Go to Settings → Devices & Services → Add Integration
2. Search for "Reolink"
3. Configure:
   - Host: `10.1.1.46`
   - Username/Password: (your NVR credentials)

### Integration 5-6: Daikin, Xiaomi

Add these via their respective integrations, pointing to their 10.1.1.x IP addresses.

---

## Pi Gate Control Setup

### Overview

The Raspberry Pi currently running Home Assistant will be simplified to only handle the front gate GPIO control. The new HA on Proxmox will send commands to it.

### Option A: Keep Minimal HA on Pi (Recommended)

**Why:** Easiest migration path, HA-to-HA communication is well supported.

#### On Pi: Simplify to Gate Only

1. Remove all integrations except:
   - GPIO for gate relay
   - Whatever switch/automation controls the gate

2. Enable HA API access for remote control

#### On New HA: Add Remote Home Assistant

1. Go to Settings → Devices & Services → Add Integration
2. Search for "Remote Home Assistant" (HACS required) or use REST commands
3. Configure connection to 10.1.1.63:8123

4. Create a script to trigger gate:
```yaml
# configuration.yaml or scripts.yaml
script:
  open_front_gate:
    alias: "Open Front Gate"
    sequence:
      - service: rest_command.trigger_pi_gate
        
rest_command:
  trigger_pi_gate:
    url: "http://10.1.1.63:8123/api/services/switch/toggle"
    method: POST
    headers:
      Authorization: "Bearer YOUR_LONG_LIVED_ACCESS_TOKEN"
      Content-Type: "application/json"
    payload: '{"entity_id": "switch.front_gate_relay"}'
```

### Option B: ESPHome on Pi (Future)

Convert the Pi to run ESPHome instead of full HA. The gate relay becomes a simple switch entity discovered automatically by HA.

This is cleaner long-term but requires more work. Consider for later optimization.

### Option C: Simple MQTT Script (Alternative)

Replace HA on Pi with a simple Python script that:
- Subscribes to MQTT topic `home/gate/command`
- Triggers GPIO when message received

```python
#!/usr/bin/env python3
# /opt/gate-controller/gate.py
import paho.mqtt.client as mqtt
import RPi.GPIO as GPIO
import time

GATE_PIN = 17  # Adjust to your GPIO pin
MQTT_BROKER = "10.1.1.67"
MQTT_TOPIC = "home/gate/command"

GPIO.setmode(GPIO.BCM)
GPIO.setup(GATE_PIN, GPIO.OUT)

def on_message(client, userdata, message):
    if message.payload.decode() == "OPEN":
        GPIO.output(GATE_PIN, GPIO.HIGH)
        time.sleep(0.5)  # Pulse duration
        GPIO.output(GATE_PIN, GPIO.LOW)

client = mqtt.Client()
client.connect(MQTT_BROKER, 1883)
client.subscribe(MQTT_TOPIC)
client.on_message = on_message
client.loop_forever()
```

From new HA, create a switch:
```yaml
mqtt:
  switch:
    - name: "Front Gate"
      command_topic: "home/gate/command"
      payload_on: "OPEN"
      payload_off: "OPEN"  # Same - it's a momentary trigger
```

---

## Smart Shutdown Automation

### Purpose

Automatically shut down the homelab when:
- UPS is on battery (grid power lost)
- AND home battery is below 15% (solar can't sustain)

Both conditions must be true to avoid unnecessary shutdowns.

### Prerequisites

- NUT integration configured (UPS status)
- Fronius integration configured (battery level)
- Shell command access for shutdown script

### Shutdown Script

Create on pve1:

```bash
# /usr/local/bin/homelab-emergency-shutdown.sh
#!/bin/bash

LOG="/var/log/homelab-shutdown.log"

echo "$(date): Emergency shutdown triggered" >> $LOG
echo "  Reason: Grid down + home battery critical" >> $LOG

# Stop containers in reverse dependency order
for ct in 112 113 104 103 102 101 100; do
    echo "$(date): Stopping CT$ct" >> $LOG
    pct shutdown $ct --timeout 30 2>>$LOG &
done
wait

echo "$(date): All containers stopped" >> $LOG

# Set Ceph maintenance flags
echo "$(date): Setting Ceph maintenance flags" >> $LOG
ceph osd set noout
ceph osd set nobackfill
ceph osd set norebalance

# Shutdown Mac Pro (SSH via Storage VLAN)
echo "$(date): Shutting down Mac Pro" >> $LOG
ssh -o ConnectTimeout=10 xavier@192.168.30.20 "sudo shutdown -h now" 2>>$LOG

# Shutdown cluster nodes
echo "$(date): Shutting down pve3" >> $LOG
ssh root@192.168.10.13 "shutdown -h now" &

sleep 15

echo "$(date): Shutting down pve2" >> $LOG
ssh root@192.168.10.12 "shutdown -h now" &

sleep 15

echo "$(date): Shutting down pve1 (self)" >> $LOG
shutdown -h now
```

Make executable:
```bash
chmod +x /usr/local/bin/homelab-emergency-shutdown.sh
```

### Home Assistant Configuration

#### Shell Command

Add to `configuration.yaml`:

```yaml
shell_command:
  emergency_shutdown: "ssh -o StrictHostKeyChecking=no root@192.168.10.11 '/usr/local/bin/homelab-emergency-shutdown.sh'"
```

**Note:** Requires SSH key from HA container to pve1. Set up with:
```bash
# In HA container
docker exec -it homeassistant bash
ssh-keygen -t ed25519 -f /config/.ssh/id_ed25519 -N ""
ssh-copy-id -i /config/.ssh/id_ed25519 root@192.168.10.11
exit
```

#### Automation

```yaml
automation:
  - id: 'emergency_homelab_shutdown'
    alias: "Emergency Homelab Shutdown"
    description: "Shutdown when grid down AND home battery critical"
    trigger:
      - platform: template
        value_template: >
          {{ states('sensor.cyberpower_status') in ['OB', 'OB DISCHRG', 'LB'] 
             and (states('sensor.fronius_battery_state_of_charge') | float(100)) < 15 }}
        for:
          minutes: 2
    condition:
      - condition: template
        value_template: >
          {{ states('sensor.cyberpower_status') in ['OB', 'OB DISCHRG', 'LB'] }}
      - condition: numeric_state
        entity_id: sensor.fronius_battery_state_of_charge
        below: 15
    action:
      - service: notify.mobile_app_xavier
        data:
          title: "⚠️ HOMELAB EMERGENCY SHUTDOWN"
          message: >
            Grid power DOWN. Home battery at {{ states('sensor.fronius_battery_state_of_charge') }}%.
            Initiating graceful shutdown in 60 seconds.
          data:
            priority: high
            ttl: 0
      - delay:
          seconds: 60
      - service: notify.mobile_app_xavier
        data:
          title: "🔴 Homelab Shutting Down NOW"
          message: "Graceful shutdown in progress..."
      - service: shell_command.emergency_shutdown
```

### Manual Trigger (Testing)

Create a manual trigger button:

```yaml
script:
  test_emergency_shutdown:
    alias: "TEST: Emergency Shutdown"
    sequence:
      - service: notify.mobile_app_xavier
        data:
          title: "⚠️ TEST SHUTDOWN"
          message: "This is a TEST. No actual shutdown will occur."
      # Uncomment below to actually test
      # - service: shell_command.emergency_shutdown
```

---

## Testing Procedures

### Phase 1: Container Deployment

| Test | Command | Expected Result |
|------|---------|-----------------|
| Container running | `pct status 113` | `status: running` |
| Network connectivity | `pct exec 113 -- ping -c 2 10.1.1.174` | 0% packet loss |
| HA web accessible | `curl -I http://192.168.40.70:8123` | HTTP 200 |
| DNS resolution | `nslookup ha.homelab.local 192.168.40.53` | 192.168.40.70 |

### Phase 2: Integration Tests

| Integration | Test | Expected Result |
|-------------|------|-----------------|
| NUT | Check `sensor.cyberpower_status` | Shows `OL` (Online) |
| Fronius | Check `sensor.fronius_battery_*` | Shows battery % |
| MQTT | Check for discovered devices | ESP devices appear |
| Reolink | View camera in HA | Live feed displays |

### Phase 3: Gate Control Test

| Test | Action | Expected Result |
|------|--------|-----------------|
| Command reaches Pi | Trigger gate from new HA | Pi logs show request |
| Gate operates | Trigger gate from new HA | Physical gate opens |
| Round-trip time | Measure delay | < 2 seconds |

### Phase 4: Shutdown Automation Test

**WARNING:** Test during a safe time when shutdown won't cause issues.

| Test | Method | Expected Result |
|------|--------|-----------------|
| Condition detection | Set test values in Developer Tools | Automation triggers |
| Notification sent | Wait for automation | Mobile notification received |
| Dry run | Comment out actual shutdown | Logs show steps |
| Full test | Allow full execution | Clean shutdown |

---

## Cutover Plan

### Pre-Cutover Checklist

- [ ] All integrations migrated and tested
- [ ] Pi gate control working from new HA
- [ ] Automations recreated and tested
- [ ] Dashboards recreated
- [ ] Mobile app connected to new HA
- [ ] Notifications working
- [ ] Family members informed

### Cutover Steps

1. **Announce maintenance window** to family
2. **Run final parallel test** - both HAs running
3. **Stop old HA on Pi:**
   ```bash
   ssh pi@10.1.1.63 "sudo systemctl stop home-assistant"
   ```
4. **Verify new HA is primary:**
   - All devices accessible
   - Automations running
   - Mobile app works
5. **Monitor for 24-48 hours**
6. **Simplify Pi to gate-only** (Phase 4)

### Success Criteria

- [ ] All automations working
- [ ] Mobile app connected
- [ ] Gate control functional
- [ ] Camera feeds accessible
- [ ] No complaints from family for 48 hours

---

## Rollback Procedure

If issues arise after cutover:

### Quick Rollback (< 5 minutes)

```bash
# Start old HA on Pi
ssh pi@10.1.1.63 "sudo systemctl start home-assistant"

# Stop new HA (optional - can run both temporarily)
pct exec 113 -- bash -c "cd /opt/homeassistant && docker compose stop"
```

### Full Rollback

1. Stop new HA container
2. Start old Pi HA
3. Revert mobile app to point to 10.1.1.63
4. Document what failed
5. Plan fixes before retry

---

## Documentation Updates Required

After successful deployment, update these files:

### CURRENT_STATUS.md
- Add CT113 to container list
- Update service status
- Note Pi is now gate-only

### services.md
- Add Home Assistant entry
- Update architecture diagram
- Document integrations

### network-table.md
- Add 192.168.40.70 entry
- Add DNS entries

### backup-recovery.md
- Add CT113 to backup list
- Document HA-specific recovery steps

---

## Resource Requirements Summary

| Resource | Allocation | Rationale |
|----------|------------|-----------|
| CT ID | 113 | Next available |
| IP | 192.168.40.70 | Services VLAN |
| CPU | 2 cores | HA can be demanding |
| RAM | 4 GB | Comfortable headroom |
| Disk | 32 GB | Database, logs, growth |
| Backup | Daily with others | Via vzdump |

### Estimated Resource Usage

| Metric | Expected | Maximum |
|--------|----------|---------|
| CPU | 5-15% | 50% (during updates) |
| RAM | 1-2 GB | 3 GB |
| Disk | 5-10 GB | 20 GB |
| Network | Minimal | Spikes during camera view |

---

## Quick Reference

### Access URLs

| Service | URL |
|---------|-----|
| Home Assistant | http://192.168.40.70:8123 |
| Home Assistant (via proxy) | http://ha.homelab.local |

### Key Commands

```bash
# Container management
pct start 113
pct stop 113
pct enter 113

# Docker management (inside container)
cd /opt/homeassistant
docker compose up -d
docker compose down
docker compose logs -f
docker compose restart

# View HA logs
docker compose logs -f homeassistant

# Restart HA only
docker compose restart homeassistant
```

### Important Files

| File | Location | Purpose |
|------|----------|---------|
| docker-compose.yml | /opt/homeassistant/ | Container definition |
| configuration.yaml | /opt/homeassistant/config/ | HA configuration |
| automations.yaml | /opt/homeassistant/config/ | Automations |
| secrets.yaml | /opt/homeassistant/config/ | Sensitive data |

---

## Appendix: Current Pi HA Integrations to Migrate

Document from your current Pi HA:

| Integration | Config Needed | Priority | Notes |
|-------------|---------------|----------|-------|
| Fronius | IP: 10.1.1.174 | High | Battery level critical |
| MQTT | Broker: 10.1.1.67 | High | Many devices |
| Reolink | IP: 10.1.1.46 | Medium | Occasional use |
| Daikin | IPs: .20, .211 | Low | Monitoring only |
| Xiaomi | IP: 10.1.1.60 | Low | Monitoring only |
| Front Gate | GPIO on Pi | High | Needs special handling |

---

*This document will be updated as the migration progresses.*  
*Last verified: 2025-11-26*