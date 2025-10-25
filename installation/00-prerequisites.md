# 📋 Installation Prerequisites

**Time Required:** 1-2 hours preparation  
**Difficulty:** Easy  
**Last Updated:** October 25, 2025

## Before You Begin

This guide ensures you have everything ready for a smooth installation. Complete all items before starting Phase 1.

## ✅ Hardware Checklist

### Required Hardware
- [ ] **4x HP Elite Mini 800 G9** (or equivalent)
  - [ ] 3 for Proxmox nodes
  - [ ] 1 for OPNsense router
  - [ ] All powered on and POST tested
- [ ] **1x Managed Switch** with VLAN support
  - [ ] UniFi Switch Lite 16 PoE (recommended)
  - [ ] Or equivalent with 802.1Q VLAN support
- [ ] **1x ISP Router/Modem**
  - [ ] Ethernet connection available
  - [ ] DHCP enabled
- [ ] **Network Cables**
  - [ ] Minimum 5x Cat6 cables
  - [ ] Various lengths (0.5m to 3m)
- [ ] **Installation Hardware**
  - [ ] Monitor (HDMI or DisplayPort)
  - [ ] USB Keyboard
  - [ ] 2x USB drives (8GB minimum)

### Optional but Recommended
- [ ] **Label maker** or cable labels
- [ ] **Ethernet cable tester**
- [ ] **Spare network cables**
- [ ] **UPS** for power protection

## 💾 Software Downloads

### Installation ISOs
1. **OPNsense** (Latest stable)
   - Download: https://opnsense.org/download/
   - Version: 24.7 or later
   - Architecture: amd64
   - Type: DVD ISO (not nano)
   - Size: ~2GB

2. **Proxmox VE** (Latest stable)
   - Download: https://www.proxmox.com/downloads
   - Version: 8.0 or later
   - Type: ISO Installer
   - Size: ~1GB

### Tools Required

#### Windows Users
- [ ] **Rufus** - https://rufus.ie/
  - For creating bootable USB drives
- [ ] **PuTTY** - https://putty.org/
  - For SSH access
- [ ] **WinSCP** - https://winscp.net/
  - For file transfers (optional)

#### Linux/Mac Users
- [ ] **dd** command (built-in)
- [ ] **ssh** client (built-in)
- [ ] **screen** or **tmux** (optional)

## 📝 Information to Gather

### Network Configuration

Fill in these details before starting:

#### ISP Network
- **ISP Router IP:** `10.1.1.1` (typical)
- **ISP Network Range:** `10.1.1.0/24`
- **Internet Speed:** _______ Mbps
- **Connection Type:** [ ] FTTN [ ] FTTP [ ] HFC [ ] Other

#### Planned IP Addresses
| Device | Management IP | Notes |
|--------|---------------|-------|
| OPNsense | 192.168.10.1 | Router/Firewall |
| pve1 | 192.168.10.11 | Proxmox node 1 |
| pve2 | 192.168.10.12 | Proxmox node 2 |
| pve3 | 192.168.10.13 | Proxmox node 3 |

#### VLAN Planning
| VLAN ID | Network | Purpose |
|---------|---------|---------|
| 10 | 192.168.10.0/24 | Management |
| 20 | 192.168.20.0/24 | Corosync |
| 30 | 192.168.30.0/24 | Storage |
| 40 | 192.168.40.0/24 | Services |

### Credentials Planning

Choose these before installation:

#### Passwords (use strong, unique passwords)
- **Proxmox root password:** _____________
- **OPNsense root password:** _____________ (default: opnsense)
- **UniFi Controller:** _____________

#### Other Information
- **Email for alerts:** _____________
- **Cluster name:** `homelab`
- **Domain name:** `homelab.local`
- **Timezone:** `Australia/Darwin`

## 🛠️ Pre-Installation Setup

### 1. Create Installation Media

#### OPNsense USB (Do this first)
```bash
# Linux/Mac
sudo dd if=OPNsense-24.7-dvd-amd64.iso of=/dev/sdX bs=4M status=progress
sync

# Windows (use Rufus)
1. Open Rufus
2. Select USB drive
3. Select OPNsense ISO
4. Click START
```

#### Proxmox USB
```bash
# Linux/Mac
sudo dd if=proxmox-ve_8.0-1.iso of=/dev/sdY bs=4M status=progress
sync

# Windows (use Rufus)
1. Open Rufus
2. Select second USB drive
3. Select Proxmox ISO
4. Click START
```

### 2. Label Everything

Before connecting cables:
- Label each HP Elite Mini (pve1, pve2, pve3, OPNsense)
- Label network cables with their purpose
- Document MAC addresses if possible

### 3. Initial Hardware Setup

1. **Position Equipment**
   - Place in well-ventilated area
   - Consider Darwin heat (25-32°C average)
   - Leave space between units

2. **Connect Power**
   - Plug all units into power
   - Use surge protector minimum
   - UPS recommended

3. **Do NOT Connect Network Yet**
   - Install operating systems first
   - Connect network after base configuration

## 🔍 Verification Steps

### Hardware Testing

Power on each HP Elite Mini and verify:
- [ ] POST completes successfully
- [ ] Can enter BIOS (F10 key)
- [ ] Boot order can be changed
- [ ] All 32GB RAM detected
- [ ] 500GB NVMe detected

### BIOS Settings to Check

For each HP Elite Mini:
1. **Boot Options**
   - Legacy Support: Disabled
   - Secure Boot: Disabled
   - Fast Boot: Disabled

2. **Power Management**
   - After Power Loss: Power On
   - Wake on LAN: Enabled

3. **Virtualization**
   - Intel VT-x: Enabled
   - Intel VT-d: Enabled

### Network Testing

Before installation:
1. **Test ISP Connection**
   ```bash
   # From laptop connected to ISP router
   ping 10.1.1.1
   ping 8.8.8.8
   ```

2. **Test Cables**
   - Use cable tester if available
   - Or verify each cable works with laptop

## 📚 Documentation to Have Ready

Print or have available on another device:
- This prerequisites guide
- [Installation Guide Phase 1](01-opnsense.md)
- Network diagram with IP addresses
- Password list (keep secure!)

## ⚠️ Common Preparation Mistakes

### Avoid These Issues
1. **Wrong ISO Type**
   - Use DVD ISO for OPNsense, not nano
   - Use standard ISO for Proxmox, not ARM

2. **Insufficient USB Size**
   - Some old 4GB drives won't work
   - Use 8GB or larger

3. **DHCP Conflicts**
   - Ensure ISP router DHCP won't conflict
   - Plan IP ranges carefully

4. **Missing Cables**
   - You need more cables than you think
   - Have spares ready

## 🎯 Ready to Install?

### Final Checklist
- [ ] All hardware present and tested
- [ ] Installation media created and verified
- [ ] Network plan documented
- [ ] Passwords chosen and recorded
- [ ] At least 4 hours available for installation
- [ ] Coffee/tea prepared ☕

## 🚀 Next Steps

Once all prerequisites are complete:

1. **Start with Phase 1:** [OPNsense Installation](01-opnsense.md)
2. **Then Phase 2:** [Switch Configuration](02-switch-config.md)
3. **Then Phase 3:** [Proxmox Installation](03-proxmox-nodes.md)
4. **Then Phase 4:** [Cluster Creation](04-cluster-creation.md)
5. **Then Phase 5:** [Ceph Storage](05-ceph-storage.md)

## 💡 Pro Tips

### For Smooth Installation
- **Document everything** as you go
- **Take screenshots** of configurations
- **Test after each phase** before moving on
- **Don't rush** - careful is faster than fixing mistakes

### Time Expectations
- **Phase 1 (OPNsense):** 2-3 hours
- **Phase 2 (Switch):** 1 hour
- **Phase 3 (Proxmox):** 3-4 hours
- **Phase 4 (Cluster):** 30 minutes
- **Phase 5 (Ceph):** 1 hour
- **Total:** 8-10 hours (can split across days)

---

**Ready?** You're about to build something awesome! 🚀

**Need Help?** Check the [Troubleshooting Guide](../operations/troubleshooting.md) if you encounter issues.
