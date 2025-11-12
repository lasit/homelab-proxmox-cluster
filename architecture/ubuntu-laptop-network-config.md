# Ubuntu Management Laptop Network Configuration

## Hardware
- **Model:** HP ProBook 440 14-inch G10 Notebook PC
- **Network Interface:** enp4s0
- **OS:** Ubuntu Linux
- **Hostname:** xavier-HP-ProBook-440-14-inch-G10-Notebook-PC

## Network Configuration Method
- **Manager:** NetworkManager
- **Wired Connection:** "Wired connection 1"
- **Method:** DHCP auto

## Current Network Setup (Split Access)

### Primary Connection (Default VLAN)
- **Interface:** enp4s0
- **IP Address:** 192.168.1.105/24
- **Gateway:** 192.168.1.1
- **DHCP:** From OPNsense LAN
- **Switch Port:** Port 9 (Native: Default VLAN)

### Management VLAN Access (Tagged)
- **Interface:** enp4s0.10 (VLAN 10 tagged)
- **IP Address:** 192.168.10.101/24
- **Gateway:** 192.168.10.1
- **DHCP:** From OPNsense Management VLAN
- **Access Method:** 802.1Q VLAN tagging

## Additional Network Interfaces
- **Tailscale:** 100.102.3.77/32 (VPN for remote access)
- **Docker:** 172.17.0.1/16 (Container networking)
- **WiFi:** Available for backup connectivity to ISP network

## Setting Up VLAN Access

### Create VLAN Interface
```bash
# Install VLAN support
sudo apt install vlan

# Load 8021q kernel module
sudo modprobe 8021q

# Create VLAN 10 interface
sudo ip link add link enp4s0 name enp4s0.10 type vlan id 10
sudo ip link set dev enp4s0.10 up

# Get DHCP address
sudo dhcpcd enp4s0.10
```

### Verify Configuration
```bash
# Check IP addresses
ip addr show | grep "inet "

# Check routing
ip route show | grep default

# Test connectivity
ping -c 2 192.168.10.1  # Management VLAN gateway
ping -c 2 192.168.1.104  # Switch management
```

## Services Running

### UniFi Network Controller
- **URL:** https://localhost:8443
- **Purpose:** Manage UniFi switch
- **Inform Port:** 8080
- **Management Interface:** 192.168.10.101

### SSH Access Points
- **OPNsense:** ssh root@192.168.1.1 or ssh root@192.168.10.1
- **Switch:** ssh ubnt@192.168.1.104
- **Proxmox Nodes:** (Once configured)
  - pve1: ssh root@192.168.10.11
  - pve2: ssh root@192.168.10.12
  - pve3: ssh root@192.168.10.13

## Network Routes
```
# Primary route (lower metric = higher priority)
default via 192.168.1.1 dev enp4s0 metric 100

# Secondary route (Management VLAN)
default via 192.168.10.1 dev enp4s0.10 metric 1009
```

## Why This Configuration?

### Split Brain Approach Benefits
1. UniFi switch stays on Default VLAN (compatibility)
2. Laptop accesses both networks simultaneously
3. No disruption when UniFi firmware updates
4. Easy recovery if configuration fails

### NetworkManager Considerations
- NetworkManager handles enp4s0 automatically
- VLAN interface managed separately via dhcpcd
- Stable configuration that survives reboots

## Troubleshooting

### If Management VLAN Access Fails
```bash
# Remove and recreate VLAN interface
sudo ip link delete enp4s0.10
sudo ip link add link enp4s0 name enp4s0.10 type vlan id 10
sudo ip link set dev enp4s0.10 up
sudo dhcpcd enp4s0.10
```

### If Primary Connection Fails
```bash
# Restart NetworkManager
sudo systemctl restart NetworkManager

# Or manually configure
sudo dhclient -r enp4s0
sudo dhclient enp4s0
```

## Making VLAN Persistent (Optional)
Currently the VLAN interface needs to be recreated after reboot.
To make persistent, create systemd service or netplan configuration.
For now, manual creation provides more control during setup phase.
