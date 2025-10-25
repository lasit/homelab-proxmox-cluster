# 📦 Phase 6: Service Deployment Plan

**Status:** Ready to begin after router installation  
**Prerequisites:** Protectli router installed and configured  
**Timeline:** 4 weeks after router operational

## Pre-Deployment Checklist

- [ ] OPNsense router operational on Protectli hardware
- [ ] All VLANs configured and routing properly
- [ ] Proxmox cluster accessible via web UI
- [ ] Ceph storage verified healthy
- [ ] Network connectivity verified all nodes
- [ ] DNS resolution working
- [ ] Firewall rules configured

## Week 1: Foundation Services

### Day 1: Tailscale Installation
**Time:** 1 hour  
**Location:** Install on all three Proxmox nodes

```bash
# On each node (pve1, pve2, pve3)
curl -fsSL https://tailscale.com/install.sh | sh
tailscale up --advertise-routes=192.168.10.0/24,192.168.40.0/24
```

**Configuration:**
- Enable subnet routing
- Disable key expiry
- Test remote access

### Day 2: Pi-hole Deployment
**Time:** 1 hour  
**Type:** LXC Container on pve1  
**Resources:** 1 CPU, 1GB RAM, 8GB disk  
**IP:** 192.168.40.21

```bash
# Create container
pct create 100 local:vztmpl/debian-12-standard_12.2-1_amd64.tar.zst \
  --hostname pihole \
  --memory 1024 \
  --cores 1 \
  --net0 name=eth0,bridge=vmbr0,tag=40,ip=192.168.40.21/24,gw=192.168.40.1
```

**Post-Install:**
- Configure upstream DNS
- Add local DNS entries
- Update DHCP to use Pi-hole
- Test ad blocking

### Day 3: Nginx Proxy Manager
**Time:** 1 hour  
**Type:** Docker in LXC on pve2  
**Resources:** 1 CPU, 1GB RAM, 10GB disk  
**IP:** 192.168.40.22

**Features to Configure:**
- SSL certificates via Let's Encrypt
- Proxy hosts for all services
- Access lists for security
- 404 page customization

### Day 4: Uptime Kuma
**Time:** 30 minutes  
**Type:** Docker container  
**Resources:** 1 CPU, 512MB RAM, 5GB disk  
**IP:** 192.168.40.23

**Monitors to Create:**
- All Proxmox nodes
- OPNsense router
- Pi-hole
- Internet connectivity
- Future services

## Week 2: Backup & Security

### Day 1-2: Proxmox Backup Server
**Time:** 2-3 hours  
**Type:** VM on pve3  
**Resources:** 2 CPU, 4GB RAM, 100GB disk  
**IP:** 192.168.10.21

**Configuration:**
- Install PBS from ISO
- Configure datastore on local-lvm
- Add all nodes as clients
- Schedule daily backups
- Test restore procedure

### Day 3: Vaultwarden
**Time:** 1 hour  
**Type:** Docker container  
**Resources:** 1 CPU, 512MB RAM, 5GB disk  
**IP:** 192.168.40.24

**Setup:**
- Enable 2FA
- Configure SMTP for invites
- Nginx reverse proxy
- Backup configuration

### Day 4: Security Hardening
- Review all firewall rules
- Disable unnecessary services
- Configure fail2ban
- Set up log aggregation

## Week 3: Migration & Production

### Home Assistant Migration
**Time:** 3-4 hours  
**Type:** VM on pve1  
**Resources:** 2 CPU, 4GB RAM, 32GB disk  
**IP:** 192.168.40.30

**Migration Steps:**
1. Create backup on existing HA
2. Create new VM with VLAN 40
3. Add secondary NIC for 10.1.1.x access
4. Install Home Assistant OS
5. Restore backup
6. Test all automations
7. Update device configurations
8. Decommission old instance

**Network Configuration:**
```
eth0: VLAN 40 (192.168.40.30) - Primary
eth1: Bridge to physical network - IoT access
```

## Week 4: Additional Services

### Optional Deployments

**Nextcloud** (if needed)
- Resources: 2 CPU, 4GB RAM, 50GB disk
- IP: 192.168.40.31

**Paperless-ngx** (document management)
- Resources: 2 CPU, 2GB RAM, 50GB disk
- IP: 192.168.40.32

**Grafana + Prometheus** (monitoring)
- Resources: 2 CPU, 2GB RAM, 20GB disk
- IP: 192.168.10.26-27

## Service Access Map

### Internal Access (192.168.10.x)
```
https://proxmox.homelab.local → Proxmox cluster
https://pbs.homelab.local → Backup server
https://grafana.homelab.local → Monitoring
```

### Service Network (192.168.40.x)
```
https://pihole.homelab.local → Pi-hole admin
https://npm.homelab.local → Nginx Proxy Manager
https://status.homelab.local → Uptime Kuma
https://vault.homelab.local → Vaultwarden
https://ha.homelab.local → Home Assistant
```

### External Access (via Tailscale)
```
All services accessible via Tailscale IPs
MagicDNS for hostname resolution
No port forwarding required
```

## Resource Allocation Plan

### Node Distribution
**pve1 (Primary Services):**
- Pi-hole (LXC)
- Home Assistant (VM)
- Future: Media services

**pve2 (Support Services):**
- Nginx Proxy Manager (LXC)
- Vaultwarden (Docker)
- Future: Development

**pve3 (Infrastructure):**
- Proxmox Backup Server (VM)
- Monitoring stack
- Future: Databases

### Storage Planning
```
Ceph Pool (172GB available):
├── Service VMs: ~80GB
├── Backups: ~50GB
├── Container volumes: ~20GB
└── Reserve: ~22GB
```

## Firewall Rules Required

### OPNsense Configuration

**VLAN 40 → Internet:**
- HTTP/HTTPS (80/443) - Outbound
- DNS (53) - To Pi-hole only
- NTP (123) - Time sync

**VLAN 40 → VLAN 10:**
- Backup traffic (8007)
- Monitoring (9090)

**VLAN 10 → VLAN 40:**
- All services accessible

**Internet → VLAN 40:**
- None (Tailscale only)

## Backup Strategy

### Daily Backups
- All LXC containers → PBS
- All VMs → PBS
- Configuration files → Git

### Weekly Backups
- PBS to external drive
- Database dumps
- Home Assistant snapshots

### Testing Schedule
- Monthly restore test
- Quarterly DR drill
- Annual full recovery test

## Monitoring & Alerts

### Uptime Kuma Checks
- Service availability (1-minute intervals)
- SSL certificate expiry
- Disk space warnings
- Network latency

### Alert Channels
- Email notifications
- Push notifications (Pushover)
- Dashboard display

## Documentation Requirements

### For Each Service
- Installation steps
- Configuration backup
- Troubleshooting guide
- Update procedure
- Recovery process

### Network Diagrams
- Update with each service
- Document firewall rules
- Track IP allocations

## Success Criteria

### Week 1
- [ ] Remote access working via Tailscale
- [ ] Ad blocking operational
- [ ] All services have SSL
- [ ] Monitoring active

### Week 2
- [ ] Automated backups running
- [ ] Password manager deployed
- [ ] Security hardened

### Week 3
- [ ] Home Assistant migrated
- [ ] All automations working
- [ ] Old instance decommissioned

### Week 4
- [ ] All planned services deployed
- [ ] Documentation complete
- [ ] Monitoring comprehensive

---

**Note:** Begin deployment only after router is installed and network is fully operational. Test each service thoroughly before moving to the next.
