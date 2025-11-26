# 🏠 Proxmox Homelab Project Instructions

**Project Owner:** Xavier Espiau  
**Location:** Darwin, Northern Territory, Australia  
**Repository:** https://github.com/lasit/homelab-proxmox-cluster  
**Project Type:** 3-Node Proxmox VE Cluster with OPNsense Router  
**Timeline:** 10-year operational horizon  

## 📋 Project Overview

This is a comprehensive homelab infrastructure project running a 3-node Proxmox cluster with enterprise-grade networking via OPNsense. The project prioritizes reliability and learning through hands-on experience with production technologies.

### Core Infrastructure
- **3× HP Elite Mini 800 G9 nodes** running Proxmox VE 8.2
- **Protectli FW4C** router with OPNsense 25.1
- **UniFi Switch Lite 16 PoE** for VLAN segmentation
- **Mac Pro 2013** with 9.1TB Pegasus array for backups
- **172GB Ceph storage** distributed across nodes
- **7 production containers** providing various services

### Philosophy
- **Reliability over bleeding edge** - 10-year operational horizon
- **Learn by doing** - Hands-on experience with enterprise tech
- **Documentation driven** - Everything documented for future reference

## 📂 Documentation Structure

### Local Master Copy
**Location:** `/home/xavier/Documents/Homelab_Promox_Cluster_Project/homelab-proxmox-cluster/`

This is the SOURCE OF TRUTH. All changes are made here first.

### GitHub Repository  
**URL:** https://github.com/lasit/homelab-proxmox-cluster

Public backup and version control. Updated after local changes.

### Claude Project Files
RAG (Retrieval-Augmented Generation) context files. Should mirror critical documentation from GitHub.

### Structure
```
homelab-proxmox-cluster/
├── README.md                    # Public-facing overview
├── QUICKSTART.md               # 10-minute essential reference
├── CURRENT_STATUS.md           # ⚠️ UPDATE THIS AFTER ANY CHANGE
├── docs/
│   ├── reference/             # Static information
│   │   ├── infrastructure.md  # Hardware inventory
│   │   ├── services.md        # Service catalog
│   │   ├── network-table.md  # Network documentation
│   │   └── commands.md        # Command reference
│   ├── guides/               # How-to procedures
│   │   ├── troubleshooting.md
│   │   ├── power-management.md
│   │   ├── backup-recovery.md
│   │   ├── core-services.md
│   │   └── storage-automation.md
│   └── architecture/         # Design & lessons
│       ├── design-decisions.md
│       └── lessons-learned.md
├── scripts/                  # Operational automation
│   ├── daily-health.sh      # Run each morning
│   ├── fix-dns.sh          # DNS troubleshooting
│   ├── verify-state.sh     # Deep system check
│   └── backup-test.sh      # Backup verification
└── logs/
    └── incidents/           # Post-mortems
        └── 2025-11-24-macpro-boot.md
```

## 🔄 Documentation Workflow

### Making Changes

1. **Local Edit First**
```bash
cd ~/Documents/Homelab_Promox_Cluster_Project/homelab-proxmox-cluster
nano CURRENT_STATUS.md  # Or relevant file
```

2. **Commit to GitHub**
```bash
git add .
git commit -m "Update: Brief description of change"
git push
```

3. **Update Claude Project**
- Copy updated files to Claude project
- Or reference GitHub repo for latest version

### Update Priorities
1. **ALWAYS update after:**
   - Service deployments/removals
   - Network changes
   - Hardware changes
   - Incidents/outages
   - Configuration changes

2. **Update CURRENT_STATUS.md for:**
   - Any service status change
   - Completed tasks
   - New issues discovered
   - Next planned actions

## 💬 Communication Preferences

### How to Interact
- Give clear, step-by-step instructions with exact commands
- Explain WHY before showing HOW
- Warn about potential issues BEFORE they happen
- Provide copy-paste ready commands with explanations
- Include verification steps after each major action
- Be direct - don't oversimplify but don't overwhelm

### Response Format
For technical tasks, structure responses as:
1. **Objective**: What we're trying to achieve
2. **Prerequisites**: What must be ready/verified first
3. **Procedure**: Step-by-step commands
4. **Verification**: How to confirm success
5. **Documentation Update**: What files to update and specific changes needed
6. **Next Steps**: What comes after this task

## 🌏 Important Context

### Technical Background
- Comfortable with Linux command line
- New to enterprise networking concepts
- Learning Proxmox, Ceph, and virtualization
- Prefer understanding over just copying commands

### Project Constraints
- **10-year project horizon** - prioritize reliability over bleeding edge
- **Darwin, NT location** - tropical climate (heat/humidity considerations)
- **Power costs** - $0.30/kWh requires efficiency focus
- **Remote work** - Need reliable remote access for work

### Environmental Factors
- **Climate:** Tropical with high humidity
- **Power:** Expensive, occasional outages during storms
- **Internet:** NBN with potential CGNAT
- **Cooling:** Essential for hardware longevity

## 📋 When Helping

### Your Workflow
1. **Check the files in the project RAG first** for current documentation
2. **Reference specific files** when providing guidance
3. **Suggest documentation updates** when configurations change
4. **Track changes** between conversations via updated documentation files
5. **Maintain consistency** with established configurations
6. **Always verify current state** before suggesting changes

### Before Making Changes
- Check CURRENT_STATUS.md for latest state
- Verify no family members are using services
- Ensure backups are recent (check backup-test.sh)
- Review relevant documentation files
- Consider impact on other services

## 🚀 Quick Access Information

### Critical Access Points
```bash
# Proxmox Nodes
https://192.168.10.11:8006  # pve1
https://192.168.10.12:8006  # pve2  
https://192.168.10.13:8006  # pve3

# Services (via proxy)
http://pihole.homelab.local      # Pi-hole DNS
http://nginx.homelab.local       # Nginx Proxy Manager
http://status.homelab.local      # Uptime Kuma
http://cloud.homelab.local       # Nextcloud
http://automation.homelab.local  # n8n automation

# Infrastructure
https://192.168.10.1            # OPNsense router
https://100.89.200.114          # Tailscale IP
```

### Service Containers
| CT ID | Service | IP | Purpose |
|-------|---------|-----|---------|
| 100 | Tailscale | 192.168.40.10 | Remote access VPN |
| 101 | Pi-hole | 192.168.40.53 | DNS & ad blocking |
| 102 | Nginx Proxy | 192.168.40.22 | Reverse proxy |
| 103 | Uptime Kuma | 192.168.40.23 | Monitoring |
| 104 | Nextcloud | 192.168.40.31 | File storage |
| 105 | MariaDB | 192.168.40.32 | Database |
| 112 | n8n | 192.168.40.61 | Automation |

### Daily Commands
```bash
# Check health
~/homelab-docs/scripts/daily-health.sh

# Fix DNS issues
~/homelab-docs/scripts/fix-dns.sh

# Verify system state
~/homelab-docs/scripts/verify-state.sh

# Test backups
~/homelab-docs/scripts/backup-test.sh verify
```

## ⚠️ Do NOT Touch List

### Critical Services
- **Pi-hole (CT101)** - Family depends on ad blocking
- **Tailscale (CT100)** - Required for remote work access
- **OPNsense firewall rules** - Can lock yourself out

### Network Configuration
- **VLAN 10 (192.168.10.0/24)** - Management network
- **ISP network (10.1.1.x)** - Smart home devices, DO NOT migrate
- **Storage VLAN isolation** - Security boundary

### Hardware
- **Proxmox node IPs** - Changing breaks cluster
- **Mac Pro boot configuration** - Carefully tuned, don't modify
- **Switch port assignments** - Document before changing

## 🔧 Common Tasks Reference

### Daily Health Check
```bash
cd ~/homelab-docs/scripts
./daily-health.sh
# Review output, address any RED items
```

### Adding New Service
1. Check CURRENT_STATUS.md for next container ID
2. Review services/service-catalog.md for planning
3. Deploy following guides in docs/guides/
4. Update CURRENT_STATUS.md
5. Add to Uptime Kuma monitoring
6. Add to backup schedule
7. Test backup/restore

### After Power Outage
1. Follow docs/guides/power-management.md
2. Wait for all systems to boot (~20 minutes)
3. Run verify-state.sh
4. Check all services accessible
5. Update CURRENT_STATUS.md with any issues

## 📊 Current State Summary

### Operational Status
- **Cluster:** 3 nodes, quorum established
- **Services:** 7 containers running
- **Storage:** Ceph HEALTH_OK, 172GB usable
- **Backup:** Automated daily to Mac Pro NAS
- **Monitoring:** Uptime Kuma tracking all services
- **Remote Access:** Tailscale operational

### Known Issues
- Redis (CT106) not configured (systemd namespace issues)
- SSL certificates not configured (using HTTP)
- Neighbor still on shared network (VLAN 50 pending)

### Recent Changes
Check CURRENT_STATUS.md for latest updates

### Upcoming Work
- UPS installation for power protection
- WiFi expansion (UniFi U6+ access points)
- Home Assistant migration to cluster
- SSL certificate configuration

## 🚨 Emergency Procedures

### Cannot Access Services
```bash
# 1. Check DNS
nslookup pihole.homelab.local 192.168.40.53

# 2. Check container status
ssh root@192.168.10.11 "pct list"

# 3. Restart critical services
ssh root@192.168.10.11 "pct restart 101"  # Pi-hole
ssh root@192.168.10.11 "pct restart 100"  # Tailscale
```

### Cluster Issues
```bash
# Check cluster status
ssh root@192.168.10.11 "pvecm status"

# Check Ceph health
ssh root@192.168.10.11 "ceph -s"
```

### Complete Recovery
See: docs/guides/power-management.md for full procedures

## 📚 Key Documentation Files

### Must Read First
- **QUICKSTART.md** - 10-minute orientation
- **CURRENT_STATUS.md** - What's running right now
- **docs/architecture/design-decisions.md** - Why things are built this way

### For Troubleshooting
- **docs/guides/troubleshooting.md** - Common issues and fixes
- **docs/architecture/lessons-learned.md** - What we've learned (often the hard way)

### For Operations
- **docs/guides/power-management.md** - Shutdown/startup procedures
- **docs/guides/backup-recovery.md** - Backup and restore guide
- **scripts/*** - Automation tools

## 🎯 Success Metrics

### Technical Goals
- 99.9% uptime for family services
- <24 hour recovery from any failure
- Zero data loss events
- Successful monthly backup restore test

### Learning Goals
- Understand every component deployed
- Can troubleshoot without external help
- Can explain architecture to others
- Building reusable knowledge base

## 📝 Git Commit Conventions

Use these prefixes for clear commit messages:
- **Add:** New service or feature
- **Update:** Existing documentation changes
- **Fix:** Correcting errors or issues
- **Remove:** Deleting services or content
- **Refactor:** Reorganizing without changing function
- **Incident:** Post-mortem documentation

Examples:
```bash
git commit -m "Add: Jellyfin media server deployment"
git commit -m "Update: Container resource allocations"
git commit -m "Fix: DNS resolution for services"
git commit -m "Incident: Power outage recovery 2025-11-27"
```

## 🔄 Review Schedule

### Daily
- Run daily-health.sh
- Check Uptime Kuma dashboard
- Review any alerts

### Weekly  
- Update CURRENT_STATUS.md
- Check backup status
- Review resource usage

### Monthly
- Run backup-test.sh restore
- Review and update documentation
- Check for security updates
- Analyze power consumption

## 💡 Important Reminders

1. **Family First** - If family notices issues, it's a priority
2. **Document Everything** - Future you will thank present you
3. **Test Before Production** - Snapshot, test, then deploy
4. **Backup Before Changes** - Can't have too many backups
5. **Learn From Failures** - Every issue is a learning opportunity

## 🤝 How to Use This Project

### For Questions
1. Provide current status/issue
2. Reference what you've already tried
3. Mention any time constraints
4. Indicate if family services are affected

### For Changes
1. Describe the goal
2. Provide current state from CURRENT_STATUS.md
3. Mention any concerns
4. Ask for pre-change checklist

### For Learning
1. Ask "why" questions freely
2. Request explanations of concepts
3. Ask for analogies if needed
4. Request deep dives on topics