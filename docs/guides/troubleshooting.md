# 🔧 Troubleshooting Guide

**Last Updated:** 2025-11-24  
**Purpose:** Problem/solution database from actual issues encountered  
**Format:** Symptom → Diagnosis → Solution → Prevention

## 📚 Table of Contents

1. [Critical Issues](#critical-issues)
2. [Network Problems](#network-problems)
3. [Container Issues](#container-issues)
4. [Service Failures](#service-failures)
5. [Storage Problems](#storage-problems)
6. [DNS Issues](#dns-issues)
7. [Performance Problems](#performance-problems)
8. [Boot & Startup Issues](#boot--startup-issues)
9. [Backup & Recovery Issues](#backup--recovery-issues)
10. [Quick Diagnostic Commands](#quick-diagnostic-commands)

---

## 🚨 Critical Issues

### Mac Pro NAS Boot Hang (RESOLVED 2025-11-24)

**Symptom:**
- System hangs during boot at ~58 seconds
- Error: "firmware not operational"
- Device offline: "scsi 1:0:0:0: Device offlined - not ready after error recovery"
- System stuck at grub> prompt after hard resets

**Root Cause:**
- stex (Promise SuperTrak) driver loads too early during boot
- Thunderbolt firmware not ready when driver initializes in initramfs

**Solution:**
```bash
# 1. Blacklist driver from early boot
echo "blacklist stex" > /etc/modprobe.d/blacklist-stex.conf

# 2. Update initramfs
update-initramfs -u -k all

# 3. Create post-boot mount script (see power-management.md)
# 4. Enable systemd service for delayed mounting
```

**Prevention:**
- Always disconnect Thunderbolt storage during OS installation
- Use UUID-based mounting
- Implement post-boot mounting for Thunderbolt devices

---

### Pi-hole DNS Entry Pointing to Wrong IP (RESOLVED 2025-11-25)

**Symptom:**
- Services accessed via pihole.homelab.local fail
- Direct IP access works (192.168.40.53)
- Browser shows connection refused

**Root Cause:**
- DNS entry points to service IP (192.168.40.53) instead of proxy IP (192.168.40.22)
- Bypasses Nginx Proxy Manager

**Solution:**
```bash
# Fix DNS entry
pct exec 101 -- nano /etc/pihole/pihole.toml

# Change:
# "192.168.40.53 pihole.homelab.local"
# To:
# "192.168.40.22 pihole.homelab.local"

# Restart Pi-hole
pct exec 101 -- systemctl restart pihole-FTL

# Verify
nslookup pihole.homelab.local 192.168.40.53
```

**Additional Issue Found:** Duplicate hosts arrays in pihole.toml

**Solution for Duplicates:**
```bash
# Python script to remove duplicate hosts arrays
pct enter 101
systemctl stop pihole-FTL

cat > /tmp/fix_hosts.py << 'EOF'
#!/usr/bin/env python3
with open('/etc/pihole/pihole.toml', 'r') as f:
    lines = f.readlines()
new_lines = []
in_hosts = False
hosts_count = 0
skip_until_bracket = False
for line in lines:
    if line.strip().startswith('hosts = ['):
        hosts_count += 1
        if hosts_count == 1:
            new_lines.append(line)
            in_hosts = True
        else:
            skip_until_bracket = True
    elif skip_until_bracket:
        if line.strip() == ']':
            skip_until_bracket = False
    elif in_hosts and line.strip() == ']':
        new_lines.append(line)
        in_hosts = False
    else:
        new_lines.append(line)
with open('/etc/pihole/pihole.toml', 'w') as f:
    f.writelines(new_lines)
print(f"Fixed! Removed {hosts_count - 1} duplicate hosts arrays")
EOF

python3 /tmp/fix_hosts.py
systemctl start pihole-FTL
exit
```

**Prevention:**
- Always point DNS to proxy IP when using reverse proxy
- Document DNS architecture clearly
- Use verification script after changes
- Check for duplicate arrays after editing pihole.toml

---

### n8n Container Continuous Restart

**Symptom:**
- Container restarts every few seconds
- Logs show: "Error: EACCES: permission denied, open '/home/node/.n8n/config'"
- Docker container won't stay running

**Root Cause:**
- Latest n8n version has permission issues in unprivileged LXC
- UID 1000 ownership problems

**Solution:**
```bash
# Use stable version instead of latest
cd /opt/n8n
docker compose down

# Edit docker-compose.yml
# Change: image: n8nio/n8n:latest
# To:     image: n8nio/n8n:1.63.4

# Fix permissions
rm -rf ./data/*
chown -R 1000:1000 ./data

# Start with stable version
docker compose up -d
```

**Prevention:**
- Always use specific version tags in production
- Never use :latest tag
- Test updates in non-production first

---

## 🌐 Network Problems

### Container Can't Reach Internet

**Symptom:**
- Container can ping gateway but not internet
- apt update fails
- DNS resolution fails

**Diagnosis:**
```bash
# From container
ping 192.168.40.1    # Gateway - should work
ping 8.8.8.8         # Internet - fails
nslookup google.com  # DNS - fails
```

**Solution:**
```bash
# Check container network config
pct config <CTID> | grep net

# Fix DNS
pct set <CTID> --nameserver 192.168.40.53

# Fix gateway
pct set <CTID> --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.XX/24,gw=192.168.40.1

# Restart container
pct restart <CTID>
```

---

### VLAN Interfaces Disappear After Reboot

**Symptom:**
- Ubuntu laptop loses VLAN access after reboot
- Can't reach management network
- VLANs need manual recreation

**Solution:**
```bash
# Make VLANs permanent with NetworkManager
sudo nmcli connection add \
  type vlan \
  con-name "Management-VLAN10" \
  dev enp4s0 \
  id 10 \
  ipv4.method manual \
  ipv4.addresses 192.168.10.101/24 \
  ipv4.dns "192.168.40.53,192.168.10.1" \
  connection.autoconnect yes

# Bring up
sudo nmcli connection up Management-VLAN10
```

**Prevention:**
- Always use NetworkManager for permanent configs
- Set autoconnect=yes
- Document network configurations

---

### Inter-VLAN Routing Not Working

**Symptom:**
- Can't reach other VLANs
- Services VLAN can't reach Management VLAN
- Firewall blocking traffic

**Diagnosis:**
```bash
# From Proxmox node
ip route show
ping -I vmbr0.40 192.168.10.1
```

**Solution:**
```bash
# Check OPNsense firewall rules
# Ensure rules allow inter-VLAN traffic
# Management VLAN should allow all
# Services VLAN should allow to internet
```

---

## 📦 Container Issues

### Container Won't Start

**Symptom:**
- pct start fails
- Container stuck in "starting" state
- No error messages

**Diagnosis:**
```bash
pct start <CTID> --debug
journalctl -u pve-container@<CTID>
```

**Common Solutions:**

**1. Storage not ready:**
```bash
# Check Ceph
ceph -s
# Wait for HEALTH_OK
```

**2. Locked container:**
```bash
pct unlock <CTID>
pct start <CTID>
```

**3. Corrupted filesystem:**
```bash
pct fsck <CTID>
```

---

### Docker Won't Start in LXC

**Symptom:**
- Docker daemon fails to start
- Permission denied errors
- Cannot create containers

**Solution:**
```bash
# Add to /etc/pve/lxc/<CTID>.conf
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:

# Restart container
pct stop <CTID>
pct start <CTID>

# Reinstall Docker
pct exec <CTID> -- curl -fsSL https://get.docker.com | sh
```

---

### Container Can't Mount NFS/SSHFS

**Symptom:**
- Mount fails with permission denied
- FUSE not available
- Network filesystem won't mount

**Solution for SSHFS:**
```bash
# Add to container config
lxc.mount.entry: /dev/fuse dev/fuse none bind,create=file
lxc.apparmor.profile: unconfined

# Install in container
apt install sshfs

# Mount
sshfs user@host:/path /mnt/point
```

---

## 🔧 Service Failures

### Tailscale Won't Connect

**Symptom:**
- Tailscale shows offline
- Can't establish connection
- Routes not advertised

**Solution:**
```bash
# Add TUN device to container config
echo "lxc.cgroup2.devices.allow: c 10:200 rwm" >> /etc/pve/lxc/100.conf
echo "lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file" >> /etc/pve/lxc/100.conf

# Restart container
pct restart 100

# Re-authenticate
pct exec 100 -- tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24 --accept-routes
```

---

### Pi-hole Not Blocking Ads

**Symptom:**
- Ads still showing
- DNS queries not filtered
- Statistics show 0% blocked

**Diagnosis:**
```bash
# Check listening mode
pct exec 101 -- grep listeningMode /etc/pihole/pihole.toml
```

**Solution:**
```bash
# Change from LOCAL to ALL
pct exec 101 -- sed -i 's/listeningMode = "LOCAL"/listeningMode = "ALL"/' /etc/pihole/pihole.toml
pct exec 101 -- systemctl restart pihole-FTL

# Update gravity
pct exec 101 -- pihole -g

# Verify clients using Pi-hole
nslookup doubleclick.net 192.168.40.53
# Should return 0.0.0.0
```

---

### Nginx Proxy Manager 502 Bad Gateway

**Symptom:**
- Services return 502 error
- "Bad Gateway" message
- Direct access works

**Common Causes:**

**1. Wrong backend IP:**
```bash
# Check proxy host configuration
# Ensure forward IP is correct
# Use container IP, not proxy IP
```

**2. Service not listening:**
```bash
# Check if service is running
pct exec <CTID> -- ss -tulpn | grep <port>
```

**3. Firewall blocking:**
```bash
# Ensure no firewall between proxy and service
```

---

### Nextcloud "Access Through Untrusted Domain"

**Symptom:**
- Error when accessing via Tailscale
- Works via normal URL
- Mobile app can't connect

**Solution:**
```bash
# Add IP to trusted domains
pct exec 104 -- nano /var/www/nextcloud/config/config.php

# Add to trusted_domains array:
'trusted_domains' => 
array (
  0 => 'cloud.homelab.local',
  1 => '192.168.40.31',
),

# Save and exit
```

---

## 💾 Storage Problems

### Ceph HEALTH_WARN State

**Symptom:**
- Ceph shows HEALTH_WARN
- Performance degraded
- Warnings in dashboard

**Common Issues:**

**1. Clock skew:**
```bash
# Fix time sync on all nodes
for node in 11 12 13; do
  ssh root@192.168.10.$node "timedatectl set-ntp true"
  ssh root@192.168.10.$node "systemctl restart systemd-timesyncd"
done
```

**2. OSDs down:**
```bash
# Check OSD status
ceph osd tree

# Restart OSDs on affected node
systemctl restart ceph-osd.target
```

**3. Maintenance flags set:**
```bash
# Check flags
ceph osd dump | grep flags

# Remove if not needed
ceph osd unset noout
ceph osd unset nobackfill
ceph osd unset norebalance
```

---

### Mac Pro NAS Mount Lost

**Symptom:**
- /mnt/macpro shows empty
- Backups fail
- df doesn't show mount

**Solution:**
```bash
# Check mount status
systemctl status mnt-macpro.mount

# Restart mount
systemctl restart mnt-macpro.mount

# If still fails, check SSH
ssh xavier@192.168.30.20
# May need to re-add SSH keys

# Manual mount test
sshfs xavier@192.168.30.20:/storage /mnt/macpro
```

---

### Mac Pro Not Responding to Ping (Current Issue)

**Symptom:**
- Ping to 192.168.30.20 times out
- SSHFS mounts still working
- SSH access works

**Possible Causes:**
- Firewall blocking ICMP
- Ubuntu security settings
- Network isolation working as designed

**Investigation:**
```bash
# Check if SSH works
ssh macpro

# Check mount
df -h | grep macpro

# Try arping instead
arping -I vmbr0.30 192.168.30.20
```

---

## 🔍 DNS Issues

### Services Not Resolvable

**Symptom:**
- Can't access services by name
- IP access works
- nslookup fails

**Diagnosis:**
```bash
# Test DNS
nslookup pve1.homelab.local 192.168.40.53
nslookup pve1.homelab.local 192.168.10.1

# Check Pi-hole entries
pct exec 101 -- grep homelab /etc/pihole/pihole.toml
```

**Solution:**
```bash
# Add missing entries to Pi-hole
pct exec 101 -- nano /etc/pihole/pihole.toml

# Add to hosts array:
"192.168.10.11 pve1.homelab.local",
"192.168.40.22 nginx.homelab.local",

# Restart
pct exec 101 -- systemctl restart pihole-FTL
```

---

### Ubuntu Laptop No Internet When Pi-hole Down

**Symptom:**
- Can ping IPs but not domains
- Internet "not working"
- Happens during maintenance

**Solution:**
```bash
# Configure dual DNS
sudo nmcli connection modify "Wired connection 1" \
  ipv4.dns "192.168.40.53 192.168.10.1"

# Apply
sudo nmcli connection down "Wired connection 1"
sudo nmcli connection up "Wired connection 1"
```

---

## 📊 Performance Problems

### High Memory Usage

**Symptom:**
- Node showing high RAM usage
- Swap being used
- System sluggish

**Diagnosis:**
```bash
# Check what's using memory
free -h
ps aux --sort=-%mem | head
htop

# Check container usage
for ct in $(pct list | awk 'NR>1 {print $1}'); do
  echo "CT$ct:"
  pct exec $ct -- free -h
done
```

**Common Culprits:**
- Nextcloud (needs 4GB minimum)
- MariaDB (cache settings)
- Docker containers with memory leaks

---

### Slow Network Performance

**Symptom:**
- File transfers slow
- Web interfaces laggy
- High latency

**Diagnosis:**
```bash
# Test network speed
iperf3 -s  # On target
iperf3 -c <target>  # On source

# Check for errors
ip -s link show
ethtool -S eno1 | grep -i error
```

**Common Fixes:**
- Disable hardware offloading
- Check MTU settings
- Verify switch port configuration

---

## 🔄 Boot & Startup Issues

### Cluster Won't Form Quorum After Reboot

**Symptom:**
- Nodes show no quorum
- Can't access web UI
- Services won't start

**Solution:**
```bash
# On each node
systemctl restart pve-cluster
systemctl restart corosync

# If still broken, reset expected votes
pvecm expected 1  # Temporary
# Fix issue
pvecm expected 3  # Reset
```

---

### Containers Not Auto-Starting

**Symptom:**
- Containers remain stopped after node reboot
- Manual start required
- onboot not working

**Solution:**
```bash
# Check onboot setting
pct config <CTID> | grep onboot

# Enable if missing
pct set <CTID> -onboot 1

# For Docker services inside container
pct exec <CTID> -- systemctl enable docker
```

---

## 💼 Backup & Recovery Issues

### Backup Job Fails

**Symptom:**
- Scheduled backup doesn't run
- Manual backup fails
- Storage not accessible

**Diagnosis:**
```bash
# Check backup storage
pvesm list macpro-backups

# Check mount
df -h /mnt/macpro

# Check job config
pvesh get /cluster/backup/backup-6963fa17-187b
```

**Solution:**
```bash
# Restart storage mount
systemctl restart mnt-macpro.mount

# Test manual backup
vzdump 100 --storage macpro-backups --mode snapshot

# Check logs
journalctl -xe | grep vzdump
```

---

### Restore Fails

**Symptom:**
- Can't restore container
- Restore starts but fails
- Container corrupted after restore

**Common Issues:**

**1. CTID already exists:**
```bash
# Destroy old container first
pct stop <CTID>
pct destroy <CTID>
# Then restore
```

**2. Storage not ready:**
```bash
# Wait for Ceph
ceph -s
# Should show HEALTH_OK
```

**3. Different architecture:**
```bash
# Ensure backup and restore node match
# Check container arch in backup name
```

---

## 🏃 Quick Diagnostic Commands

### One-Line Health Check
```bash
echo "Cluster: $(pvecm status | grep Quorum)" && echo "Ceph: $(ceph -s | grep health)" && echo "Containers: $(pct list | grep running | wc -l)/$(pct list | wc -l)" && echo "Backup Mount: $(df -h /mnt/macpro | tail -1)"
```

### Check All Service Accessibility
```bash
for svc in nginx pihole status cloud automation; do echo -n "$svc: "; curl -sI http://$svc.homelab.local | head -1; done
```

### Test All DNS Entries
```bash
for host in pve1 pve2 pve3 nginx pihole status cloud automation; do echo -n "$host: "; nslookup $host.homelab.local 192.168.40.53 | grep Address | tail -1; done
```

### Container Resource Check
```bash
for ct in 100 101 102 103 104 105 112; do echo "CT$ct: $(pct exec $ct -- free -m | grep Mem | awk '{print $3"/"$2"MB"}') $(pct exec $ct -- df -h / | tail -1 | awk '{print $3"/"$2}')"; done 2>/dev/null
```

---

## 📝 Issue Tracking Template

When encountering new issues, document using this format:

```markdown
### Issue Title (Date)

**Symptom:**
- What you see
- Error messages
- What fails

**Root Cause:**
- Why it happens
- What investigation revealed

**Solution:**
```bash
# Exact commands to fix
```

**Prevention:**
- How to avoid in future
- Configuration changes made
- Documentation updates needed
```

---

## 🔥 Emergency Recovery

### If Everything Is Down

**From laptop with network access:**

1. **Check physical layer:**
   - Power to all devices
   - Network cables connected
   - Switch lights active

2. **Access OPNsense:**
   ```bash
   ping 192.168.10.1
   # If fails, try default VLAN
   ping 192.168.1.1
   ```

3. **Check one node directly:**
   ```bash
   ping 192.168.10.11
   ssh root@192.168.10.11
   ```

4. **If SSH works, check cluster:**
   ```bash
   pvecm status
   ceph -s
   pct list
   ```

5. **Start critical services:**
   ```bash
   pct start 101  # Pi-hole for DNS
   pct start 100  # Tailscale for remote access
   pct start 102  # Nginx Proxy Manager
   ```

---

*Always try quick diagnostics first*  
*Document new issues using the template*  
*Update this guide when solutions are found*