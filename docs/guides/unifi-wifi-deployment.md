# 📡 UniFi WiFi Deployment & Network Migration Guide

**Last Updated:** 2025-11-26  
**Status:** Planned  
**Hardware:** 3× UniFi U6+ Access Points  
**Estimated Deployment Time:** 4-6 hours (controller + APs), migration ongoing

## 📋 Table of Contents

1. [Overview](#overview)
2. [Hardware & PoE Budget](#hardware--poe-budget)
3. [Network Architecture](#network-architecture)
4. [UniFi Controller Deployment](#unifi-controller-deployment)
5. [VLAN Configuration](#vlan-configuration)
6. [Access Point Installation](#access-point-installation)
7. [SSID Configuration](#ssid-configuration)
8. [Migration Plan](#migration-plan)
9. [Testing Procedures](#testing-procedures)
10. [Troubleshooting](#troubleshooting)
11. [Future Considerations](#future-considerations)

---

## Overview

### Purpose

Deploy three UniFi U6+ access points to:
- **Isolate neighbor** from internal network (security priority)
- **Improve WiFi coverage** throughout property
- **Enable future IoT segmentation** via VLANs
- **Unify network management** with existing UniFi switch

### Current State

| Network | SSID | Users | Security Concern |
|---------|------|-------|------------------|
| ISP Router WiFi | (ISP default) | Xavier, Partner, Neighbor, IoT devices | Neighbor on same network as everything |
| Wired | N/A | Proxmox, servers | Properly segmented |

### Target State

| SSID | VLAN | Network | Users | Isolation |
|------|------|---------|-------|-----------|
| `HomeNet` | 40 | 192.168.40.x | Xavier, Partner, trusted devices | Full internal access |
| `IoT` | 60 | 192.168.60.x | Smart home devices | Internet + limited internal |
| `Neighbor` | 50 | 192.168.50.x | Neighbor only | Internet only, full isolation |
| ISP WiFi | N/A | 10.1.1.x | Legacy hardcoded IoT | Temporary, phase out |

### Access Point Placement

| AP | Location | Primary Purpose | Coverage |
|----|----------|-----------------|----------|
| AP1 | Upstairs (your room) | Personal devices, IoT | Upstairs bedrooms |
| AP2 | Downstairs | Main living areas | Kitchen, living room |
| AP3 | Neighbor's garage | Neighbor internet access | Garage, neighbor area |

---

## Hardware & PoE Budget

### UniFi U6+ Specifications

| Spec | Value |
|------|-------|
| WiFi Standard | WiFi 6 (802.11ax) |
| Max Power (PoE) | 13.5W |
| Typical Power | 10-12W |
| PoE Standard | 802.3af/at |
| Coverage | ~140 m² (1,500 sq ft) |

### PoE Power Budget Analysis

| Device | Power Draw | Notes |
|--------|-----------|-------|
| **UniFi Switch Lite 16 PoE** | **45W budget** | Total available |
| Raspberry Pi | 0W | ✅ Already USB powered |
| U6+ AP × 3 (typical) | 30-36W | 10-12W each |
| U6+ AP × 3 (peak) | 40.5W | 13.5W each |
| **Remaining** | **4.5-15W** | Acceptable margin |

**Assessment:** Budget is adequate for typical operation. Peak load (40.5W) leaves minimal headroom but should be fine. Monitor switch PoE usage after installation.

### If PoE Budget Issues Occur

Options in order of preference:
1. **Reduce AP power** - Set transmit power to Medium in UniFi controller
2. **PoE injector** - Power garage AP separately (furthest from switch)
3. **Upgrade switch** - UniFi Switch Pro has higher PoE budget (future)

---

## Network Architecture

### Physical Topology

```
                        ┌─────────────────────┐
                        │    ISP Router       │
                        │     10.1.1.1        │
                        │  WiFi: Legacy IoT   │
                        └──────────┬──────────┘
                                   │
                        ┌──────────┴──────────┐
                        │     OPNsense        │
                        │    192.168.10.1     │
                        │   (Router/Firewall) │
                        └──────────┬──────────┘
                                   │
                        ┌──────────┴──────────┐
                        │  UniFi Switch Lite  │
                        │     16 PoE          │
                        │   (VLAN Trunking)   │
                        └──┬───────┬───────┬──┘
                           │       │       │
              ┌────────────┘       │       └────────────┐
              │                    │                    │
      ┌───────┴───────┐    ┌──────┴──────┐    ┌───────┴───────┐
      │   U6+ AP1     │    │   U6+ AP2   │    │   U6+ AP3     │
      │   Upstairs    │    │  Downstairs │    │ Neighbor Garage│
      │   Port 1      │    │   Port 2    │    │    Port 4     │
      │    (PoE)      │    │    (PoE)    │    │    (PoE)      │
      └───────────────┘    └─────────────┘    └───────────────┘
              │                    │                    │
      ┌───────┴───────┐    ┌──────┴──────┐    ┌───────┴───────┐
      │ SSIDs:        │    │ SSIDs:      │    │ SSIDs:        │
      │ • HomeNet     │    │ • HomeNet   │    │ • Neighbor    │
      │ • IoT         │    │ • IoT       │    │   (only)      │
      │ • Neighbor    │    │ • Neighbor  │    │               │
      └───────────────┘    └─────────────┘    └───────────────┘
```

### VLAN Architecture

```
┌────────────────────────────────────────────────────────────────────┐
│                        VLAN STRUCTURE                               │
├────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  VLAN 10 - Management (192.168.10.0/24)                            │
│  ├── Proxmox nodes                                                  │
│  ├── OPNsense                                                       │
│  └── UniFi Controller                                               │
│                                                                     │
│  VLAN 40 - Services (192.168.40.0/24)                              │
│  ├── Containers (Pi-hole, Nextcloud, etc.)                         │
│  ├── HomeNet WiFi clients ← NEW                                     │
│  └── Full internal access + internet                                │
│                                                                     │
│  VLAN 50 - Neighbor (192.168.50.0/24)                              │
│  ├── Neighbor WiFi clients                                          │
│  └── Internet ONLY - no internal access                             │
│                                                                     │
│  VLAN 60 - IoT (192.168.60.0/24) ← NEW                             │
│  ├── Smart home devices                                             │
│  ├── Internet access                                                │
│  └── Limited internal (Home Assistant, MQTT only)                   │
│                                                                     │
│  ISP Network (10.1.1.0/24) - Legacy                                │
│  ├── Hardcoded IoT devices (temporary)                              │
│  ├── Fronius, existing HA, MQTT broker                              │
│  └── Routed via OPNsense                                            │
│                                                                     │
└────────────────────────────────────────────────────────────────────┘
```

---

## UniFi Controller Deployment

### Container Specifications

| Setting | Value | Rationale |
|---------|-------|-----------|
| CT ID | 107 | Next available |
| Hostname | unifi |  |
| IP Address | 192.168.40.40 | Services VLAN, memorable |
| Gateway | 192.168.40.1 |  |
| DNS | 192.168.40.53 | Pi-hole |
| CPU | 2 cores | Controller is lightweight |
| RAM | 2048 MB | Sufficient for small deployment |
| Swap | 1024 MB |  |
| Disk | 16 GB | Logs and backups |
| Template | debian-12-standard |  |

### Deployment Steps

#### Step 1: Create Container

```bash
# SSH to pve1
ssh root@192.168.10.11

# Create the container
pct create 107 local:vztmpl/debian-12-standard_12.7-1_amd64.tar.zst \
  --hostname unifi \
  --cores 2 \
  --memory 2048 \
  --swap 1024 \
  --storage local-lvm \
  --rootfs local-lvm:16 \
  --net0 name=eth0,bridge=vmbr0,tag=40,type=veth,ip=192.168.40.40/24,gw=192.168.40.1 \
  --nameserver 192.168.40.53 \
  --searchdomain homelab.local \
  --onboot 1 \
  --unprivileged 1

# Start container
pct start 107
```

#### Step 2: Install UniFi Controller

```bash
# Enter container
pct enter 107

# Update system
apt update && apt upgrade -y

# Install prerequisites
apt install -y curl ca-certificates gnupg apt-transport-https

# Add MongoDB 4.4 repository (required for UniFi)
curl -fsSL https://www.mongodb.org/static/pgp/server-4.4.asc | gpg --dearmor -o /usr/share/keyrings/mongodb-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/mongodb-archive-keyring.gpg] https://repo.mongodb.org/apt/debian buster/mongodb-org/4.4 main" > /etc/apt/sources.list.d/mongodb-org-4.4.list

# Add UniFi repository
curl -fsSL https://dl.ui.com/unifi/unifi-repo.gpg | gpg --dearmor -o /usr/share/keyrings/unifi-archive-keyring.gpg

echo "deb [signed-by=/usr/share/keyrings/unifi-archive-keyring.gpg] https://www.ui.com/downloads/unifi/debian stable ubiquiti" > /etc/apt/sources.list.d/unifi.list

# Install Java 11 (required)
apt install -y openjdk-11-jre-headless

# Update and install
apt update
apt install -y unifi

# Enable and start service
systemctl enable unifi
systemctl start unifi

# Check status (may take 1-2 minutes to start)
systemctl status unifi

# Exit container
exit
```

#### Step 3: Configure DNS

```bash
# Add DNS entry to Pi-hole
pct exec 101 -- bash -c "
echo '192.168.40.40 unifi.homelab.local' >> /etc/pihole/custom.list
pihole restartdns
"
```

#### Step 4: Initial Controller Setup

1. Access: https://192.168.40.40:8443 (accept certificate warning)
2. Create admin account
3. Set controller name: `Darwin Homelab`
4. Skip cloud account (or link if desired)
5. Don't add devices yet - configure VLANs first

### Add Proxy Host (Optional)

In NPM (http://nginx.homelab.local):
- Domain: `unifi.homelab.local`
- Scheme: `https`
- Forward: `192.168.40.40:8443`
- Enable "Websockets Support"

---

## VLAN Configuration

### OPNsense: Create VLAN 60 (IoT)

#### Step 1: Create VLAN Interface

1. Access OPNsense: https://192.168.10.1
2. Navigate to: **Interfaces → Other Types → VLAN**
3. Click **+** to add:
   - Parent: `vtnet1` (or your LAN interface)
   - VLAN tag: `60`
   - Description: `IoT`
4. Save

#### Step 2: Assign Interface

1. Navigate to: **Interfaces → Assignments**
2. Add new interface (the VLAN 60 you just created)
3. Save
4. Click on the new interface (e.g., OPT4)
5. Configure:
   - Enable: ✓
   - Description: `IOT`
   - IPv4 Configuration Type: `Static IPv4`
   - IPv4 Address: `192.168.60.1/24`
6. Save and Apply

#### Step 3: DHCP for VLAN 60

1. Navigate to: **Services → DHCPv4 → IOT**
2. Enable DHCP
3. Range: `192.168.60.100` to `192.168.60.200`
4. DNS Server: `192.168.40.53` (Pi-hole)
5. Save

#### Step 4: Firewall Rules for VLAN 60

1. Navigate to: **Firewall → Rules → IOT**
2. Create rules:

**Rule 1: Allow DNS to Pi-hole**
- Action: Pass
- Interface: IOT
- Protocol: TCP/UDP
- Source: IOT net
- Destination: 192.168.40.53
- Destination Port: 53
- Description: Allow DNS to Pi-hole

**Rule 2: Allow to Home Assistant (future)**
- Action: Pass
- Interface: IOT
- Protocol: TCP
- Source: IOT net
- Destination: 192.168.40.70
- Destination Port: 8123
- Description: Allow IoT to Home Assistant

**Rule 3: Allow to MQTT broker**
- Action: Pass
- Interface: IOT
- Protocol: TCP
- Source: IOT net
- Destination: 10.1.1.67
- Destination Port: 1883
- Description: Allow MQTT to broker

**Rule 4: Block internal networks**
- Action: Block
- Interface: IOT
- Protocol: Any
- Source: IOT net
- Destination: 192.168.0.0/16
- Description: Block access to internal networks

**Rule 5: Allow internet**
- Action: Pass
- Interface: IOT
- Protocol: Any
- Source: IOT net
- Destination: Any
- Description: Allow internet access

3. Save and Apply

### Verify VLAN 50 (Neighbor) Rules

Ensure VLAN 50 has proper isolation:

1. Navigate to: **Firewall → Rules → NEIGHBOR** (or VLAN50)
2. Verify rules exist:

**Rule 1: Block RFC1918 (internal networks)**
- Action: Block
- Source: NEIGHBOR net
- Destination: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16
- Description: Block all internal access

**Rule 2: Allow internet**
- Action: Pass
- Source: NEIGHBOR net
- Destination: Any
- Description: Allow internet only

### UniFi Switch: VLAN Configuration

The switch should already be configured for VLANs 10, 20, 30, 40, 50 from initial setup. Add VLAN 60:

1. Access UniFi Controller: https://192.168.40.40:8443
2. Go to: **Settings → Networks**
3. Create network:
   - Name: `IoT`
   - VLAN ID: `60`
   - Gateway/Subnet: `192.168.60.1/24` (managed by OPNsense)
   - DHCP: None (OPNsense handles this)

4. Verify existing networks:
   - `Services` - VLAN 40
   - `Neighbor` - VLAN 50

---

## Access Point Installation

### Physical Installation

#### AP1 - Upstairs (Your Room)

1. Mount AP on ceiling or high on wall
2. Run Ethernet to switch port 1
3. Configure port 1 as trunk (all VLANs)

#### AP2 - Downstairs

1. Mount AP in central location
2. Run Ethernet to switch port 2
3. Configure port 2 as trunk (all VLANs)

#### AP3 - Neighbor's Garage

1. Mount AP in garage
2. Run Ethernet to switch port 4
3. Configure port 4 for VLAN 50 only (neighbor isolation at switch level)

### Switch Port Configuration

In UniFi Controller → Devices → Switch → Ports:

| Port | Profile | VLANs | Purpose |
|------|---------|-------|---------|
| 1 | All | 40, 50, 60 | AP1 - Upstairs |
| 2 | All | 40, 50, 60 | AP2 - Downstairs |
| 4 | VLAN 50 Only | 50 | AP3 - Neighbor (restricted) |

**For Port 4 (Neighbor AP):**
1. Edit port profile
2. Set Native VLAN: 50
3. Tagged VLANs: None (or only 50)
4. This ensures even if someone hacks the AP, they only get VLAN 50

### AP Adoption

1. Connect APs to PoE switch ports
2. Wait 2-3 minutes for boot
3. In UniFi Controller → Devices
4. APs should appear as "Pending Adoption"
5. Click "Adopt" for each
6. Wait for provisioning (2-5 minutes each)
7. Update firmware if prompted

### AP Configuration

For each AP, configure in UniFi Controller:

**AP1 & AP2 (Full Access):**
- Name: `AP-Upstairs` / `AP-Downstairs`
- All SSIDs enabled

**AP3 (Neighbor Only):**
- Name: `AP-Neighbor-Garage`
- Only `Neighbor` SSID enabled
- Disable `HomeNet` and `IoT` SSIDs on this AP

---

## SSID Configuration

### Create SSIDs in UniFi Controller

Navigate to: **Settings → WiFi**

#### SSID 1: HomeNet (Trusted Devices)

| Setting | Value |
|---------|-------|
| Name | `HomeNet` |
| Password | [strong password] |
| Network | Services (VLAN 40) |
| Security | WPA2/WPA3 Personal |
| Band | 2.4 GHz and 5 GHz |
| WiFi Band Steering | Prefer 5 GHz |
| Hide SSID | No |
| Client Isolation | No |
| Broadcast APs | AP1, AP2 only |

#### SSID 2: IoT (Smart Devices)

| Setting | Value |
|---------|-------|
| Name | `IoT` |
| Password | [different strong password] |
| Network | IoT (VLAN 60) |
| Security | WPA2 Personal (some IoT don't support WPA3) |
| Band | 2.4 GHz only (better IoT compatibility) |
| Hide SSID | Optional |
| Client Isolation | No (devices may need to discover each other) |
| Broadcast APs | AP1, AP2 only |

#### SSID 3: Neighbor (Isolated Guest)

| Setting | Value |
|---------|-------|
| Name | `Neighbor` (or friendly name) |
| Password | [password to share with neighbor] |
| Network | Neighbor (VLAN 50) |
| Security | WPA2/WPA3 Personal |
| Band | 2.4 GHz and 5 GHz |
| Hide SSID | No |
| Client Isolation | Yes (neighbors can't see each other) |
| Guest Policies | Enable, bandwidth limit optional |
| Broadcast APs | All APs (or AP3 only if preferred) |

### SSID Summary

| SSID | VLAN | Security | APs | Purpose |
|------|------|----------|-----|---------|
| HomeNet | 40 | WPA2/3 | AP1, AP2 | Your trusted devices |
| IoT | 60 | WPA2 | AP1, AP2 | Smart home devices |
| Neighbor | 50 | WPA2/3 | All (or AP3 only) | Neighbor internet |

---

## Migration Plan

### Phase 1: Infrastructure (Day 1)

**Goal:** Deploy controller and APs, verify basic operation

- [ ] Deploy UniFi Controller (CT107)
- [ ] Create VLAN 60 in OPNsense
- [ ] Configure firewall rules for VLAN 60
- [ ] Verify VLAN 50 rules (neighbor isolation)
- [ ] Physically install three APs
- [ ] Adopt APs into controller
- [ ] Update AP firmware
- [ ] Create three SSIDs

**Verification:**
- [ ] Controller accessible at https://192.168.40.40:8443
- [ ] All three APs showing "Connected"
- [ ] SSIDs visible on mobile device

### Phase 2: Neighbor Migration (Day 1-2)

**Goal:** Get neighbor off your network immediately (security priority)

- [ ] Inform neighbor of new WiFi name/password
- [ ] Connect neighbor's devices to `Neighbor` SSID
- [ ] Verify neighbor has internet access
- [ ] Verify neighbor CANNOT access internal resources:
  ```bash
  # From neighbor device (ask them or test yourself)
  ping 192.168.10.1    # Should fail
  ping 192.168.40.53   # Should fail
  ping 8.8.8.8         # Should work
  ```
- [ ] Confirm neighbor is happy

**Rollback:** If issues, neighbor can temporarily use ISP WiFi

### Phase 3: Personal Device Migration (Day 2-3)

**Goal:** Move your phones, laptops, tablets to HomeNet

Devices to migrate:
- [ ] Your phone
- [ ] Partner's phone
- [ ] Your laptop (when on WiFi)
- [ ] Tablets
- [ ] Smart TV (if not IoT category)
- [ ] Gaming consoles

**For each device:**
1. Forget ISP WiFi network
2. Connect to `HomeNet`
3. Verify internet works
4. Verify can access internal services (Nextcloud, etc.)

**Verification:**
- [ ] All personal devices on VLAN 40
- [ ] Can access http://cloud.homelab.local
- [ ] Can access Proxmox UI
- [ ] Speed test satisfactory

### Phase 4: New IoT Devices (Ongoing)

**Goal:** Any NEW smart device goes on IoT SSID

- [ ] Document: "All new IoT devices use `IoT` network"
- [ ] Test with a non-critical device first
- [ ] Verify device works with Home Assistant

### Phase 5: IoT Migration (Weeks/Months)

**Goal:** Gradually move existing IoT from ISP WiFi to IoT SSID

**Priority Order:**
1. **Easy devices** - Can change WiFi in app
2. **Medium devices** - Need reset/reconfigure
3. **Hard/Never** - Hardcoded SSID, critical devices

#### Easy Migration Candidates

| Device | IP | Method | Risk |
|--------|-----|--------|------|
| Smart plugs | Various | App reconfigure | Low |
| Smart bulbs | Various | App reconfigure | Low |
| Tablets/displays | Various | Settings change | Low |

#### Medium Migration Candidates

| Device | IP | Method | Risk |
|--------|-----|--------|------|
| ESP32 devices | 10.1.1.12, .114 | Reflash/reconfigure | Medium |
| Xiaomi Gateway | 10.1.1.60 | App reconfigure | Medium |

#### Keep on ISP Network (For Now)

| Device | IP | Reason |
|--------|-----|--------|
| Fronius Inverter | 10.1.1.174 | Installer access, critical infrastructure |
| Reolink NVR | 10.1.1.46 | Working fine, low priority |
| Daikin ACs | 10.1.1.20, .211 | May have discovery issues |
| Raspberry Pi (HA) | 10.1.1.63 | Physical wiring, becoming gate-only |
| MQTT Broker | 10.1.1.67 | Central to IoT, move last |
| Roller Door | 10.1.1.15 | Critical, don't touch |

**Migration approach for each device:**
1. Document current IP and function
2. Test device on new network (if possible)
3. Update any static IPs or DHCP reservations
4. Update Home Assistant integration if needed
5. Monitor for 24 hours
6. Document completion

### Phase 6: ISP WiFi Deprecation (Future)

**Goal:** Eventually disable ISP WiFi entirely

**Prerequisites:**
- [ ] All personal devices migrated
- [ ] Neighbor fully migrated
- [ ] All moveable IoT migrated
- [ ] Hardcoded devices identified and accepted

**Options for hardcoded devices:**
1. Replace device with configurable alternative
2. Keep ISP WiFi running (hidden SSID) for legacy only
3. Create matching SSID on UniFi (same name/password as ISP)

---

## Testing Procedures

### Phase 1 Tests: Infrastructure

```bash
# Test 1: Controller accessible
curl -k https://192.168.40.40:8443

# Test 2: VLAN 60 routing (from pve1)
ssh root@192.168.10.11
ping -c 2 192.168.60.1  # OPNsense IoT interface

# Test 3: DNS for new networks
nslookup google.com 192.168.40.53
```

### Phase 2 Tests: Neighbor Isolation

```bash
# From a device on Neighbor network (VLAN 50):

# Should FAIL (internal networks blocked)
ping 192.168.10.1     # OPNsense
ping 192.168.10.11    # Proxmox
ping 192.168.40.53    # Pi-hole
ping 192.168.60.1     # IoT gateway
ping 10.1.1.1         # ISP router

# Should SUCCEED (internet only)
ping 8.8.8.8
ping google.com
curl https://google.com
```

### Phase 3 Tests: HomeNet Access

```bash
# From a device on HomeNet (VLAN 40):

# Should SUCCEED (full access)
ping 192.168.10.1     # OPNsense
ping 192.168.40.53    # Pi-hole
curl http://cloud.homelab.local
curl http://192.168.10.11:8006  # Proxmox

# Internet should work
ping 8.8.8.8
curl https://google.com
```

### Phase 5 Tests: IoT Network

```bash
# From a device on IoT network (VLAN 60):

# Should SUCCEED (allowed services)
ping 192.168.40.53    # Pi-hole DNS
ping 192.168.40.70    # Home Assistant (when deployed)
ping 10.1.1.67        # MQTT broker

# Should FAIL (blocked internal)
ping 192.168.10.11    # Proxmox
ping 192.168.40.31    # Nextcloud
curl http://192.168.10.1  # OPNsense

# Should SUCCEED (internet)
ping 8.8.8.8
```

### WiFi Performance Tests

```bash
# Speed test from each SSID
# Use speedtest.net or fast.com app

# Expected results (approximate):
# HomeNet: Full ISP speed (~50/20 Mbps)
# IoT: Full ISP speed
# Neighbor: Full or limited (if bandwidth limit set)
```

---

## Troubleshooting

### AP Not Adopting

```bash
# Check AP is getting IP via DHCP
# From container or node on same VLAN:
nmap -sn 192.168.40.0/24 | grep -i ubiquiti

# Factory reset AP if needed:
# Hold reset button 10+ seconds until light flashes

# Set inform URL manually (if AP on different subnet):
ssh ubnt@<ap-ip>
set-inform http://192.168.40.40:8080/inform
```

### VLAN Not Working

```bash
# Verify VLAN exists on switch
# In UniFi Controller → Devices → Switch → Ports
# Check port VLAN configuration

# Verify OPNsense interface is up
# Interfaces → [VLAN interface] → Status

# Check firewall rules order
# More specific rules should be above generic rules
```

### Device Can't Connect to SSID

1. Check SSID is broadcasting on that AP
2. Verify password is correct
3. Check if device supports WPA3 (try WPA2 only)
4. For IoT: ensure 2.4 GHz is enabled
5. Check client is not blocked in controller

### Neighbor Can Access Internal Network

**CRITICAL:** Fix immediately!

1. Check firewall rules on VLAN 50 in OPNsense
2. Ensure "Block RFC1918" rule exists and is ABOVE allow rules
3. Verify VLAN tag is correct (50)
4. Check switch port is tagged correctly
5. Test again from neighbor device

### IoT Device Can't Reach Home Assistant

1. Verify firewall rule allows VLAN 60 → 192.168.40.70:8123
2. Check rule order (allow before block)
3. Verify Home Assistant is listening on all interfaces
4. Test from IoT device: `curl http://192.168.40.70:8123`

---

## Future Considerations

### Bandwidth Limiting for Neighbor

In UniFi Controller → Settings → WiFi → Neighbor SSID:
- Enable bandwidth limit
- Set download/upload limits (e.g., 20/10 Mbps)

### Guest Portal

For neighbor network, consider:
- Terms of service acceptance
- Usage logging
- Time-based access

### Additional SSIDs

If needed:
- `Guest` - For visitors (separate from neighbor)
- `Work` - If work devices need isolation
- `Kids` - Content filtering, time limits

### Monitoring

Add to Uptime Kuma:
- UniFi Controller: https://192.168.40.40:8443
- Test each SSID periodically (harder to automate)

### AP Firmware Updates

Schedule monthly:
1. Check for updates in UniFi Controller
2. Update one AP at a time
3. Verify operation before next AP

---

## Quick Reference

### Access Points

| AP | Location | IP (DHCP) | Switch Port | SSIDs |
|----|----------|-----------|-------------|-------|
| AP1 | Upstairs | 192.168.40.x | Port 1 | All |
| AP2 | Downstairs | 192.168.40.x | Port 2 | All |
| AP3 | Garage | 192.168.40.x | Port 4 | Neighbor only |

### Networks

| Name | VLAN | Subnet | Gateway | DHCP Range |
|------|------|--------|---------|------------|
| Services/HomeNet | 40 | 192.168.40.0/24 | .1 | (existing) |
| Neighbor | 50 | 192.168.50.0/24 | .1 | .100-.200 |
| IoT | 60 | 192.168.60.0/24 | .1 | .100-.200 |

### Key URLs

| Service | URL |
|---------|-----|
| UniFi Controller | https://192.168.40.40:8443 |
| OPNsense | https://192.168.10.1 |

### WiFi Passwords

Store securely in password manager:
- HomeNet: [your password]
- IoT: [different password]
- Neighbor: [password to share]

---

## Documentation Updates Required

After deployment, update:

### CURRENT_STATUS.md
- Add CT107 (UniFi Controller)
- Add three APs to infrastructure
- Update network status

### network-table.md
- Add VLAN 60 (IoT)
- Add AP IP addresses
- Document SSID-to-VLAN mapping

### infrastructure.md
- Add UniFi APs to hardware inventory
- Update switch port assignments
- Add PoE usage

### services.md
- Add UniFi Controller service entry

---

## Checklist Summary

### Day 1
- [ ] Deploy UniFi Controller (CT107)
- [ ] Create VLAN 60 in OPNsense
- [ ] Configure firewall rules
- [ ] Install APs physically
- [ ] Adopt and configure APs
- [ ] Create SSIDs
- [ ] Migrate neighbor to new WiFi

### Day 2-3
- [ ] Migrate personal devices to HomeNet
- [ ] Verify all access works correctly
- [ ] Monitor for issues

### Ongoing
- [ ] Migrate IoT devices gradually
- [ ] Document each device migration
- [ ] Eventually reduce ISP WiFi usage

---

*This document will be updated as the migration progresses.*  
*Last verified: 2025-11-26*