# UniFi WiFi Deployment - Final Configuration

**Date:** 2025-11-28  
**Status:** Complete and Working

## Overview

Deployed UniFi WiFi infrastructure with three SSIDs across three access points, VLAN segmentation for security isolation, and centralized management via containerized UniFi Controller.

## Infrastructure Summary

| Component | Details |
|-----------|---------|
| Controller | CT107 on pve1, IP 192.168.40.40 |
| Controller Version | 10.0.160 |
| Switch | USW-Lite-16-PoE, IP 192.168.1.104 |
| Access Points | 3× UniFi U6+ |

## Network Architecture

| SSID | VLAN | Subnet | Purpose | Broadcast APs |
|------|------|--------|---------|---------------|
| HomeNet | 40 | 192.168.40.0/24 | Trusted devices | AP-Upstairs, AP-Downstairs |
| IoT | 60 | 192.168.60.0/24 | Smart home devices | AP-Upstairs, AP-Downstairs |
| Neighbor | 50 | 192.168.50.0/24 | Neighbor internet only | AP-Neighbor |

## Access Points

| Name | Switch Port | IP | Location |
|------|-------------|-----|----------|
| AP-Upstairs | Port 1 | 192.168.1.145 | Office/Upstairs |
| AP-Downstairs | Port 2 | 192.168.1.146 | Downstairs |
| AP-Neighbor | Port 4 | 192.168.1.147 | Neighbor garage |

---

## UniFi Controller (CT107)

### Container Configuration

```
Hostname: unifi
Node: pve1
CT ID: 107
IP: 192.168.40.40/24
Gateway: 192.168.40.1
DNS: 192.168.40.53
Resources: 2 cores, 2GB RAM, 16GB disk
Template: debian-12-standard
```

### Access

- Web UI: https://192.168.40.40:8443
- Device Inform: http://192.168.40.40:8080/inform

### DNS Entry (Pi-hole)

```
192.168.40.40    unifi.homelab.local
```

---

## UniFi Networks Configuration

### VMs Network (VLAN 40) - HomeNet

```
Name: VMs
Router: Third-party Gateway
VLAN ID: 40
IGMP Snooping: Off
DHCP Guarding: Off
```

### IoT Network (VLAN 60)

```
Name: IoT
Router: Third-party Gateway
VLAN ID: 60
IGMP Snooping: Off
DHCP Guarding: Off
```

### Neighbor WiFi Network (VLAN 50)

```
Name: Neighbor WiFi
Router: Third-party Gateway
VLAN ID: 50
IGMP Snooping: Off
DHCP Guarding: Off
```

---

## UniFi WiFi SSIDs

### HomeNet SSID

```
Name: HomeNet
Network: VMs (40)
Security: WPA2
WiFi Band: 2.4 GHz + 5 GHz
Band Steering: Enabled
Broadcasting APs: AP-Upstairs, AP-Downstairs
```

### IoT SSID

```
Name: IoT
Network: IoT (60)
Security: WPA2
WiFi Band: 2.4 GHz + 5 GHz
Band Steering: Enabled
Broadcasting APs: AP-Upstairs, AP-Downstairs
```

### Neighbor SSID

```
Name: Neighbor
Network: Neighbor WiFi (50)
Security: WPA2
WiFi Band: 2.4 GHz + 5 GHz
Band Steering: Enabled
Broadcasting APs: AP-Neighbor only
```

---

## Switch Port Configuration

### Port 3 - OPNsense Uplink (Critical)

```
Native VLAN: Default (1)
Tagged VLAN Management: Custom
Tagged VLANs: Management(10), Corosync(20), Storage(30), VMs(40), Neighbor WiFi(50), IoT(60)
```

**Important:** Do NOT use "Allow All" - newly created VLANs are not automatically included. Always use Custom and manually select all required VLANs.

### Ports 1, 2, 4 - Access Points

```
Native VLAN: Default (1)
Tagged VLAN Management: Allow All
PoE: Auto (PoE+)
```

---

## OPNsense Configuration

### IoT Interface (VLAN 60)

**Interfaces → Other Types → VLAN:**
```
Device: vlan06
Parent: igc1 (LAN)
VLAN tag: 60
Description: IoT
```

**Interfaces → IoT:**
```
Enable: ✓
Identifier: opt6
Device: vlan06
Description: IoT
IPv4 Configuration: Static IPv4
IPv4 Address: 192.168.60.1/24
```

### IoT DHCP Server

**Services → DHCPv4 → IoT:**
```
Enable: ✓
Range: 192.168.60.100 - 192.168.60.200
DNS Servers: 192.168.40.53
Domain name: homelab.local
```

### IoT Firewall Rules

**Firewall → Rules → IoT** (in this exact order):

| # | Action | Protocol | Source | Destination | Port | Description |
|---|--------|----------|--------|-------------|------|-------------|
| 1 | Pass | TCP/UDP | IoT net | 192.168.40.53/32 | 53 | Allow DNS to Pi-hole |
| 2 | Block | Any | IoT net | 192.168.0.0/16 | * | Block access to internal networks |
| 3 | Pass | Any | IoT net | Any | * | Allow internet access |

**Rule order is critical** - DNS must be allowed before the block rule.

---

## Verification Tests

### HomeNet (VLAN 40)

```cmd
# Should get IP 192.168.40.x
ipconfig

# Should work
ping 8.8.8.8
ping 192.168.40.53
nslookup google.com
```

### IoT (VLAN 60)

```cmd
# Should get IP 192.168.60.x
ipconfig

# Should work
ping 8.8.8.8
nslookup google.com

# Should FAIL (isolation working)
ping 192.168.10.11
ping 192.168.40.31
```

### Neighbor (VLAN 50)

```cmd
# Should get IP 192.168.50.x
ipconfig

# Should work
ping 8.8.8.8

# Should FAIL (isolation working)
ping 192.168.10.11
ping 192.168.40.53
```

---

## Troubleshooting

### AP Not Passing VLAN Traffic

If WiFi connects but no DHCP/connectivity, check for ebtables rules on the AP:

```bash
ssh tao.wuwei@<AP-IP>
ebtables -t broute -L
```

If DROP rules exist, clear them:

```bash
ebtables -t broute -F
```

**Note:** These rules may return after AP restart. This appears to be a UniFi controller bug.

### VLAN Not Working After Creation

When creating a new VLAN:

1. Add network in UniFi Controller (Settings → Networks)
2. **Manually update Port 3** (OPNsense) to include new VLAN in Custom tagged list
3. Restart switch to apply hardware config
4. Verify with: `ssh tao.wuwei@192.168.1.104` then `swctrl vlan show id 3`

### Switch Returns to Old Controller

If switch reconnects to old controller after restart:

```bash
# Stop old controller (on Ubuntu laptop)
sudo systemctl stop unifi
sudo systemctl disable unifi

# SSH to switch and re-adopt
ssh tao.wuwei@192.168.1.104
set-inform http://192.168.40.40:8080/inform
```

### Verify Switch VLAN Hardware Config

```bash
ssh tao.wuwei@192.168.1.104
swctrl vlan show id 1   # Check Port 1 VLANs
swctrl vlan show id 3   # Check Port 3 VLANs (OPNsense)
```

---

## Key Lessons Learned

1. **"Allow All" doesn't include new VLANs** - Always use Custom tagged VLAN selection for the OPNsense uplink port and manually add new VLANs.

2. **DHCP range required** - OPNsense DHCP won't work without explicitly setting the IP range.

3. **Firewall rule order matters** - Allow rules must come before block rules.

4. **Switch config vs hardware** - UniFi Controller UI may show correct config but hardware tables differ. Always verify with `swctrl vlan show id <port>`.

5. **ebtables on APs** - UniFi APs may add DROP rules for VLAN traffic. Clear with `ebtables -t broute -F`.

6. **VPN interference** - VPNs like ProtonVPN force DNS through their servers, bypassing Pi-hole even with "Allow LAN" enabled.

---

## Services Updated

### Uptime Kuma

Add monitoring for:
- UniFi Controller: https://192.168.40.40:8443

### Pi-hole DNS

Entry added:
```
192.168.40.40    unifi.homelab.local
```

---

## Files to Update

After deployment, update these project files:

- `CURRENT_STATUS.md` - Add CT107 to container list, update service count
- `docs/reference/services.md` - Add UniFi Controller service entry
- `docs/reference/infrastructure.md` - Add UniFi APs to hardware list
- `docs/reference/network-table.md` - Add VLAN 60 (IoT) details