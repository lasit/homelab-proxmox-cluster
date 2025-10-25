# Home Network Device Inventory

> **Location:** Darwin, Northern Territory, Australia  
> **Network:** 10.1.1.0/24 (ISP Router Network)  
> **Date:** October 25, 2025  
> **Status:** Pre-OPNsense Installation

## Network Overview

Currently sharing internet with neighbor through ISP router. Awaiting Protectli FW4C delivery for network isolation via OPNsense.

```
        INTERNET (NBN)
             |
      ISP Router (10.1.1.1)
             |
    UniFi Switch (10.1.1.202)
             |
    +--------+--------+
    |                 |
Your Devices    Neighbor Devices
```

## Device Inventory

### Network Infrastructure

| IP | Device | Location/Port | Purpose | Owner |
|----|--------|---------------|---------|-------|
| 10.1.1.1 | ISP Router | N/A | Internet Gateway | ISP |
| 10.1.1.202 | UniFi Switch Lite 16 PoE | Port 4 uplink | Core Network Switch | Mine |
| 10.1.1.107 | Netgear Router (OpenWrt) | Port 4 | Neighbor's WiFi AP | Neighbor |

### Raspberry Pi Devices

| IP | Hostname | Location/Port | Purpose | Services |
|----|----------|---------------|---------|----------|
| 10.1.1.63 | pi-front-door | WiFi 5GHz | Home Assistant Server | Home Assistant Core |
| 10.1.1.67 | mqtt-broker | Switch Port 13 | Security System Hub | Mosquitto MQTT Broker |

### IoT and Automation Devices

| IP | Device | Type | Purpose | MQTT |
|----|--------|------|---------|------|
| 10.1.1.12 | esp-relay-01 | ESP8266 | Shed Alert - Light/Sound | ✓ |
| 10.1.1.114 | esp-relay-02 | ESP8266 | Shed Alert - Light/Sound | ✓ |
| 10.1.1.231 | esp-relay-03 | ESP8266 | Home Automation Relay | ? |
| 10.1.1.101 | ESP-0C13B3 | ESP8266 | Home Automation | ? |
| 10.1.1.60 | lumi-gateway-v3 | Xiaomi Gateway | Smart Home Hub | - |

### Climate Control

| IP | Device | Location | Integration |
|----|--------|----------|-------------|
| 10.1.1.20 | Daikin AC | Living Room | WiFi 2.4GHz |
| 10.1.1.211 | Daikin AC | Bedroom | WiFi 2.4GHz |

### Energy Management

| IP | Device | Type | Access |
|----|--------|------|--------|
| 10.1.1.174 | Fronius Solar Inverter | Solar Monitoring | Web Interface |

### Security Devices

| IP | Device | Location/Port | Purpose |
|----|--------|---------------|---------|
| 10.1.1.46 | Reolink Cameras | Ethernet Port 4 | Security Cameras |
| 10.1.1.15 | Roller Door Controller | Switch Port 1 | Garage Door |

### Computing Devices

| IP | Device | Type | Location | Future VLAN |
|----|--------|------|----------|-------------|
| 10.1.1.45 | HP ProBook | Ubuntu Laptop | Ethernet | Management |
| 10.1.1.247 | Windows PC (3ATSA43196) | VMware Host | Ethernet | Services |
| 10.1.1.181 | HP Printer | Network Printer | WiFi | Services |
| 10.1.1.62 | Entertainment Room | Media Device | WiFi 2.4GHz | Services |

### Neighbor's Devices

| IP | Device | Notes |
|----|--------|-------|
| 10.1.1.107 | Netgear Router | Access Point for neighbor |
| 10.1.1.19/251 | Unknown Neighbor Device | Via Netgear (MAC: 8c:3b:ad) |
| Various | MacBook, TV, Phone, etc | Connected through Netgear |

### Devices Requiring Investigation

| IP | Issue | Priority |
|----|-------|----------|
| 10.1.1.171 | Excessive ARP responses (90+ duplicates) | HIGH - Possible network loop |

## Security System Architecture

### Shed Intrusion Detection
```
[Shed Sensor] → [Pi @10.1.1.67] → MQTT Broker (port 1883)
                                          ↓
                        [ESP @10.1.1.12] + [ESP @10.1.1.114]
                                          ↓
                              [Lights + Sound Alerts]
```

**Components:**
- Motion/door sensor in shed connected to GPIO on Pi
- Mosquitto MQTT broker on 10.1.1.67
- ESP8266 devices subscribe to intrusion topic
- Real-time alerts via lights and sound

## Current Security Issues

1. **No Network Isolation** - Neighbor has full access to all devices
2. **Default Passwords** - Many devices likely using defaults
3. **Unencrypted Services** - MQTT on port 1883 (no TLS)
4. **Unknown Device** - 10.1.1.171 causing network issues
5. **Shared IP** - Neighbor's activity appears as your IP

## OPNsense Migration Plan

### Planned VLAN Structure
- **VLAN 10:** Management (192.168.10.0/24) - Proxmox, admin access
- **VLAN 20:** Corosync (192.168.20.0/24) - Cluster heartbeat
- **VLAN 30:** Storage (192.168.30.0/24) - Ceph network
- **VLAN 40:** Services (192.168.40.0/24) - VMs, workstations
- **VLAN 50:** Neighbor (192.168.50.0/24) - **ISOLATED**, internet only
- **Native:** IoT devices remain on 10.1.1.x

### Day 1 Priorities When OPNsense Arrives
1. Install OPNsense on Protectli FW4C
2. **CRITICAL:** Move neighbor to isolated VLAN 50
3. Verify security system still functions
4. Test MQTT communication between devices
5. Implement firewall rules

### Firewall Rules for Security System
```
# Allow MQTT communication
pass tcp from 10.1.1.0/24 to 10.1.1.67 port 1883
pass tcp from 10.1.1.67 to 10.1.1.0/24

# Block neighbor from accessing local networks
block all from 192.168.50.0/24 to 10.1.1.0/24
block all from 192.168.50.0/24 to 192.168.0.0/16
```

## Quick Reference Commands

```bash
# Scan for all devices
sudo arp-scan -l | grep 10.1.1

# Check security system
mosquitto_sub -h 10.1.1.67 -t '#' -v

# Test ESP connectivity
for esp in 12 114; do ping -c 1 10.1.1.$esp; done

# Monitor problem device
sudo tcpdump -i any host 10.1.1.171
```

## Action Items

### Immediate
- [ ] Change passwords on: ISP router, UniFi switch, cameras, Home Assistant
- [ ] Investigate 10.1.1.171 ARP flooding issue
- [ ] Document MQTT topics used by security system
- [ ] Test complete security system chain

### Before OPNsense Installation
- [ ] Backup all device configurations
- [ ] Document any static IP requirements
- [ ] Plan DHCP reservations
- [ ] Inform neighbor about upcoming network changes

### Post-OPNsense Installation
- [ ] Isolate neighbor to VLAN 50
- [ ] Configure inter-VLAN routing rules
- [ ] Enable MQTT over TLS (port 8883)
- [ ] Set up monitoring and alerts

## Notes

- **Power:** Darwin electricity ~$0.30/kWh - efficiency matters
- **Climate:** Tropical - ensure adequate cooling
- **Security System:** Created 2023, fully operational
- **Network Sharing:** Temporary arrangement with neighbor
- **Proxmox Cluster:** 3 nodes ready, awaiting router for access

---
*Generated from network discovery performed October 25, 2025*