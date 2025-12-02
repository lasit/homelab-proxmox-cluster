# 🎓 Lessons Learned from Building a Proxmox Homelab

**Last Updated:** 2025-12-02  
**Project Duration:** 3 months (October - December 2025)  
**Services Deployed:** 9 containers + infrastructure  
**Mistakes Made:** Plenty (and documented!)

## 📚 Table of Contents

1. [Critical Lessons](#critical-lessons)
2. [Network Lessons](#network-lessons)
3. [Container & Virtualization](#container--virtualization)
4. [Storage Insights](#storage-insights)
5. [Service Deployment](#service-deployment)
6. [Troubleshooting Wisdom](#troubleshooting-wisdom)
7. [Documentation Value](#documentation-value)
8. [Time & Cost Reality](#time--cost-reality)
9. [What I Wish I Knew Earlier](#what-i-wish-i-knew-earlier)
10. [Mistakes That Taught Me Most](#mistakes-that-taught-me-most)
11. [Hardware & Physical Operations](#hardware--physical-operations)

---

## Critical Lessons

### 1. The Router Must Be Physical Hardware

**Initial Assumption:** "I'll virtualize OPNsense on a Proxmox node"  
**Reality Check:** USB NICs are terrible with BSD  
**Time Wasted:** 2 weeks trying to make USB adapters work  
**Solution:** Bought Protectli FW4C for $400  
**Lesson:** Some infrastructure needs dedicated hardware

**Key Insight:** The router is your network's foundation. Don't compromise here. A stable network makes everything else possible.

### 2. Version Tags Are Not Optional

**The n8n Incident:**
```yaml
# What I used initially
image: n8nio/n8n:latest

# What actually worked
image: n8nio/n8n:1.63.4
```

**Impact:** 3 hours troubleshooting permission errors  
**Root Cause:** Latest tag introduced breaking changes  
**Lesson:** ALWAYS use specific version tags in production

**Applied To:**
- Docker images
- Package installations
- OS versions
- Backup scripts

### 3. DNS Architecture with Reverse Proxy

**Concept That Clicked:** All service DNS entries must point to the PROXY IP, not the service IP

```
WRONG: pihole.homelab.local → 192.168.40.53
RIGHT: pihole.homelab.local → 192.168.40.22 (proxy)
```

**Why It Matters:**
- Nginx Proxy Manager reads HTTP Host header
- Direct DNS bypasses proxy completely
- Breaks centralized access control
- No SSL termination

**Times This Bit Me:** 3 (Pi-hole, Uptime Kuma, Nextcloud)

### 4. Unprivileged LXC Has Limits

**Services That Failed in Unprivileged LXC:**
1. Redis - systemd namespace restrictions
2. n8n (initially) - permission issues
3. Anything with heavy systemd hardening

**Solution Pattern:**
```bash
# Docker in LXC configuration
lxc.apparmor.profile: unconfined
lxc.cgroup2.devices.allow: a
lxc.cap.drop:
```

**Lesson:** Docker inside LXC often works better than native services

---

## Network Lessons

### 5. VLANs Must Be Planned, Not Evolved

**Initial Approach:** "I'll figure out VLANs as I go"  
**Result:** Had to reconfigure everything twice

**Final VLAN Strategy:**
| VLAN | Purpose | Lesson |
|------|---------|--------|
| 10 | Management | Keep admin traffic separate |
| 20 | Corosync | Cluster heartbeat needs isolation |
| 30 | Storage | Storage traffic floods networks |
| 40 | Services | All user services together |
| 50 | Neighbor | Isolation is a kindness |

**Key Learning:** Draw the network diagram FIRST, build second

### 6. All Trunk VLANs Should Be Tagged

**Initial Config:** Native VLAN on trunks  
**Problem:** Confusion about default behavior  
**Solution:** Tag everything explicitly

```
# Good trunk configuration
auto vmbr0
iface vmbr0 inet manual
    bridge-ports eno1
    bridge-stp off
    bridge-fd 0
    bridge-vlan-aware yes
    # No native VLAN - all tagged
```

**Exception:** Single-purpose devices can use native VLAN (Mac Pro NAS)

### 7. Smart Home Devices: If It Works, Don't Touch It

**Temptation:** Move all IoT to isolated VLAN  
**Reality:** MQTT broker established, automations working  
**Decision:** Left on 10.1.1.x network  
**Result:** Happy family, no 2am "why doesn't the light work?" calls

**Lesson:** Technical perfection < family harmony

---

## Container & Virtualization

### 8. Container Resources: Start Small, Scale Up

**Initial Approach:** Overprovision "just in case"  
**Problem:** Wasted resources, no capacity for new services

**Learned Resource Patterns:**
| Service Type | CPU | RAM | Disk | Actual Usage |
|--------------|-----|-----|------|--------------|
| DNS/Network | 1 core | 512MB | 8GB | <100MB RAM |
| Web Services | 2 cores | 1-2GB | 8-10GB | ~200MB RAM |
| Databases | 2 cores | 2GB | 10GB | ~150MB RAM |
| Docker Hosts | 2 cores | 2GB | 20GB | Varies |

**Lesson:** Most services use FAR less than allocated

### 9. Auto-Start Is Not Automatic

**Assumption:** Services restart after reboot  
**Reality:** Needed configuration at multiple layers

```bash
# LXC level
pct set 100 --onboot 1

# Service level
systemctl enable service-name

# Docker level
restart: unless-stopped
```

**Lesson:** Test reboot recovery BEFORE you need it

### 10. Permissions Are Everything in Containers

**Pattern Recognition:**

**Tailscale:** Needs TUN/TAP device
```bash
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

**Docker:** Needs AppArmor adjustment
```bash
lxc.apparmor.profile: unconfined
```

**n8n:** Needs UID 1000 for data
```bash
chown -R 1000:1000 ./data
```

**Lesson:** Permission errors = check ownership first, config second

---

## Storage Insights

### 11. Ceph Is Amazing But Hungry

**Initial Calculation:** 3 × 500GB = 1.5TB usable!  
**Reality:** 3× replication = 172GB usable  
**Mistake:** Didn't understand replication overhead

```
Raw Capacity: 515 GiB
Replication: Size 3
Usable: 172 GiB (33% of raw)
```

**Lesson:** Storage overhead is real and significant

### 12. Backup Storage Must Be Separate

**Good Decision:** Mac Pro NAS on different VLAN  
**Why It Worked:**
- Different failure domain
- Different filesystem
- Physical separation
- Can survive cluster failure

**Validation:** Mac Pro boot failure didn't affect cluster

### 13. The Thunderbolt Timing Dance

**Problem:** Mac Pro wouldn't boot with Pegasus connected  
**Cause:** stex driver loads before Thunderbolt ready  
**Solution:** Blacklist driver, load post-boot

```bash
# /etc/modprobe.d/blacklist-stex.conf
blacklist stex

# Load after boot via systemd
systemctl enable pegasus-mount.service
```

**Lesson:** Boot order matters with external storage

---

## Service Deployment

### 14. Build Order Matters

**Wrong Order:** Nextcloud → realize need database → scramble  
**Right Order:** Database → Application → Cache → Frontend

**Proper Dependency Chain:**
1. Network infrastructure (OPNsense, VLANs)
2. DNS (Pi-hole)
3. Reverse Proxy (Nginx Proxy Manager)
4. Databases (MariaDB)
5. Applications (Nextcloud)
6. Monitoring (Uptime Kuma)
7. Enhancements (Redis - failed)

**Lesson:** Map dependencies before deploying anything

### 15. One Service Per Container

**Temptation:** Put Nextcloud + MariaDB together  
**Resistance:** Separated into CT104 and CT105  
**Benefits Realized:**
- Database backup independent
- Resource allocation cleaner
- Troubleshooting easier
- Updates isolated

**Validation:** MariaDB updates didn't affect Nextcloud

### 16. Docker Compose > Manual Docker

**Initial Approach:** `docker run` commands  
**Problem:** Not reproducible, hard to update  
**Solution:** docker-compose.yml for everything

```yaml
# Reproducible, versionable, documentable
version: '3.8'
services:
  app:
    image: app:1.0.0
    restart: unless-stopped
    # Configuration as code
```

**Lesson:** Infrastructure as code, even for containers

---

## Troubleshooting Wisdom

### 17. The Troubleshooting Ladder

**Developed Pattern:**
1. Can I ping it? (Network layer)
2. Can I access port? (Transport layer)
3. Can I authenticate? (Application layer)
4. Does DNS resolve? (Name resolution)
5. What do logs say? (Application logs)
6. What does host think? (System logs)

**Success Rate:** 90% of issues found by step 3

### 18. Always Check Both Ends

**Scenario:** Service not accessible  
**Mistake:** Only checking from client side  
**Better:** Check server logs too

```bash
# Client side
curl -v http://service

# Server side
journalctl -u service -f
tail -f /var/log/service.log
```

**Lesson:** Problems can be at either end

### 19. DNS Is Always Suspect

**When Service Unreachable:**
1. Ping by IP - works?
2. Ping by hostname - fails?
3. → DNS problem

```bash
# Quick DNS check
nslookup hostname 192.168.40.53
dig @192.168.40.53 hostname
```

**Times DNS Was The Issue:** 5+

### 20. Logs Are Your Friends

**Log Locations That Mattered:**

| Service | Log Location |
|---------|--------------|
| Proxmox | /var/log/pve/ |
| Containers | journalctl -u pve-container@CTID |
| Docker | docker compose logs |
| OPNsense | System → Log Files |
| Pi-hole | /var/log/pihole/ |

**Lesson:** Know where logs live before you need them

---

## Documentation Value

### 21. Write It Down Immediately

**Pattern Observed:** Forget config details within 24 hours  
**Solution:** Document while doing, not after

**Documentation Saved Me:**
- Mac Pro recovery (had exact commands)
- Service deployments (repeatable)
- Network troubleshooting (known working state)

### 22. Screenshots Are Worth 1000 Words

**Captured:**
- OPNsense firewall rules
- UniFi VLAN settings
- Proxmox resource allocation
- Pi-hole DNS entries

**Value:** Visual reference when text isn't enough

### 23. Git Everything

**Version Controlled:**
- All documentation (markdown)
- Docker compose files
- Configuration snippets
- Scripts

**Benefits:**
- History of changes
- Rollback capability
- Off-site backup
- Shareable

---

## Time & Cost Reality

### 24. Everything Takes 3x Longer

**Initial Estimates vs Reality:**

| Task | Estimated | Actual | Why |
|------|-----------|--------|-----|
| Router setup | 2 hours | 2 weeks | USB NIC issues |
| Service deployment | 1 hour each | 3 hours each | Troubleshooting |
| Documentation | 30 min/day | 2 hours/day | Detail needed |
| Nextcloud setup | 1 hour | 4 hours | Database, DNS, proxy |

**Lesson:** Budget time for learning, not just doing

### 25. The True Cost Includes Tools

**Initial Budget:** $2,650 (hardware)  
**Hidden Costs:**
- Ethernet cables: $50
- Power boards: $40
- USB drives: $30
- Extra keyboard/mouse: $60
- Time: 200+ hours

**Ongoing Costs:**
- Electricity: $374/year
- Replacement drives: ~$200/year
- Domain (future): $20/year

**Lesson:** Hardware is 70% of cost, accessories/time is 30%

---

## What I Wish I Knew Earlier

### 26. Start with the Router

**What I Did:** Tried to build cluster first  
**What I Should've Done:** Router → Switch → Cluster  
**Impact:** 2 weeks of USB NIC frustration

### 27. Pi-hole Is Not Optional

**Initial Thought:** "Ad blocking is nice to have"  
**Reality:** Pi-hole became critical infrastructure
- Local DNS for all services
- Network-wide protection
- Central DNS management

**Lesson:** Deploy DNS infrastructure early

### 28. VLANs Can't Be "Fixed Later"

**Mistake:** Started with flat network  
**Pain:** Reconfiguring everything for VLANs  
**Should Have:** Planned network isolation from day 1

### 29. Proxmox Cluster Quorum Matters

**Learned The Hard Way:** Rebooting 2 nodes = no quorum  
**Impact:** Cluster frozen until manual intervention  
**Lesson:** Understand `pvecm expected 1` for maintenance

### 30. Backup Testing > Backup Creation

**False Security:** Daily backups running  
**Reality Check:** Never tested restore  
**Near Miss:** Almost needed recovery without practice

**Now:** Monthly restore test scheduled

---

## Mistakes That Taught Me Most

### 31. The Great Redis Failure

**Attempt:** Run Redis in unprivileged LXC  
**Result:** 4 hours of troubleshooting systemd  
**Learning:** Some battles aren't worth fighting  
**Outcome:** Nextcloud runs fine without Redis

**Wisdom:** Perfection is the enemy of good enough

### 32. The Mac Pro Boot Loop

**Mistake:** Hard reset during hang  
**Result:** Corrupted bootloader  
**Recovery:** Complete OS reinstall  
**Learning:** Patience > Force

**Prevention:** Document everything, including recovery

### 33. The DNS Pointing Paradox

**Configuration:**
```
pihole.homelab.local → 192.168.40.53 (WRONG!)
```

**Symptom:** "Connection refused"  
**Debugging:** 2 hours checking everything except DNS  
**Facepalm:** DNS should point to proxy!

**Learning:** Question assumptions, check fundamentals

### 34. The Docker :latest Trap

**Instances Hit:**
1. n8n - permission errors
2. NPM - breaking changes
3. Almost Uptime Kuma (caught in time)

**Lesson Learned:** `:latest` is for development only

### 35. The VLAN Native Confusion

**Original Config:** Mixed native and tagged VLANs  
**Problem:** Inconsistent behavior  
**Solution:** Tagged everything (except Mac Pro)

**Understanding:** Explicit > Implicit

---

## Philosophical Lessons

### 36. Simple Solutions Often Win

**Complex Attempt:** Kubernetes cluster  
**Simple Solution:** Docker Compose  
**Result:** Same functionality, 10% complexity

### 37. Family Users != Tech Users

**Tech User:** "Check the logs"  
**Family User:** "It doesn't work"  
**Solution:** Make it work reliably, not flexibly

### 38. Perfect Is the Enemy of Done

**Perfectionist Trap:** Waiting for ideal solution  
**Reality:** Working solution > perfect plan  
**Example:** No SSL yet, but services work

### 39. Learn by Breaking (In Dev)

**Best Learning:** Breaking things and fixing them  
**Requirement:** Dev environment (thanks, Proxmox snapshots!)  
**Result:** Confidence through recovery

### 40. Community Knowledge Is Gold

**Resources That Saved Me:**
- r/homelab Reddit
- Proxmox forums
- ServeTheHome forums
- GitHub issues
- Stack Overflow

**Lesson:** Someone has hit your error before

---

## Hardware & Physical Operations

### 41. UniFi Switch Ports May Reset After Physical Changes

**Event:** After rack migration, Mac Pro couldn't reach its gateway

**Cause:** UniFi Switch Port 15 was reset from "Storage (30)" to "Default (1)"

**Diagnosis Time:** 15 minutes (after starting UniFi Controller)

**Prevention:**
- Document all switch port assignments before physical changes
- Verify port configs immediately after reconnecting
- Keep UniFi Controller accessible (CT107) during migrations

**Lesson:** Physical moves can cause logical resets - always verify switch config after hardware changes

### 42. Start Infrastructure in Correct Order

**Correct Startup Order:**
1. Network switch (provides connectivity)
2. Router (provides routing/DHCP)
3. NAS storage (Pegasus first, then Mac Pro)
4. Cluster nodes (pve1 → pve2 → pve3)
5. Services (containers auto-start)

**Why It Matters:**
- Proxmox nodes need network to form cluster
- Containers need DNS (Pi-hole) to function
- SSHFS mounts need NAS online first

**Lesson:** Infrastructure has dependencies - respect the boot order

### 43. Thunderbolt Storage Boot Timing Is Fragile

**Observed:** Mac Pro Pegasus auto-mount service didn't trigger on cold boot

**Service Status:** Enabled (`systemctl is-enabled pegasus-mount.service`)

**Root Cause:** Thunderbolt device initialization timing varies

**Manual Workaround:**
```bash
sudo /usr/local/bin/mount-pegasus.sh
```

**Potential Fixes to Investigate:**
- Add retry logic to mount script
- Increase startup delay
- Use udev rules for Thunderbolt device detection
- Create timer-based retry service

**Lesson:** External storage boot timing is inherently unreliable - build in manual verification step

### 44. Keep ISP Network Available During Maintenance

**Situation:** Laptop had dual routes (ISP and OPNsense)

**Benefit:** Could still reach internet when homelab network was down

**Downside:** Had to manually remove ISP route after startup

**Command Used:**
```bash
sudo ip route del default via 10.1.1.1
```

**Lesson:** Dual-homed management workstation provides fallback during maintenance

### 45. Rack Migration Checklist Is Essential

**Created Checklist:**

**Pre-Migration:**
- [ ] Run daily-health.sh
- [ ] Verify recent backup
- [ ] Document switch port assignments
- [ ] Note current container states
- [ ] Configure DNS fallback on laptop

**Shutdown Sequence:**
- [ ] Stop SSHFS mounts on all nodes
- [ ] Shutdown Mac Pro (storage unmounted)
- [ ] Power off Pegasus array
- [ ] Stop containers (reverse dependency order)
- [ ] Set Ceph maintenance flags
- [ ] Shutdown nodes (pve3 → pve2 → pve1)
- [ ] Power off switch
- [ ] Power off router

**Startup Sequence:**
- [ ] Power on switch (wait 60s)
- [ ] Power on router (wait 2min)
- [ ] Verify network connectivity
- [ ] Power on Pegasus (wait 30s)
- [ ] Power on Mac Pro (wait 3min)
- [ ] Verify/run Pegasus mount script
- [ ] Power on nodes (pve1 → pve2 → pve3)
- [ ] Verify cluster quorum
- [ ] Clear Ceph flags
- [ ] Restart SSHFS mounts
- [ ] Verify all containers running
- [ ] Verify DNS working
- [ ] Verify switch port configs

**Lesson:** Complex operations need written checklists - memory fails under pressure

### 46. Ceph Maintenance Flags Are Critical

**Flags Used Before Shutdown:**
```bash
ceph osd set noout
ceph osd set nobackfill
ceph osd set norebalance
```

**Why They Matter:**
- Prevents Ceph from marking OSDs as "out" during shutdown
- Prevents unnecessary data movement
- Allows clean recovery after restart

**Must Clear After Startup:**
```bash
ceph osd unset noout
ceph osd unset nobackfill
ceph osd unset norebalance
```

**Lesson:** Ceph is smart but needs hints about planned maintenance

---

## Technical Patterns Recognized

### Infrastructure Patterns

```bash
# The Universal Fix Attempt Sequence
systemctl restart service
systemctl status service
journalctl -xe
check logs
check permissions
check network
check DNS
Google error message
```

### Container Patterns

```bash
# The Container Deployment Pattern
1. Create container with minimal resources
2. Install dependencies
3. Configure network
4. Test direct access
5. Add to reverse proxy
6. Configure DNS
7. Document everything
```

### Network Patterns

```bash
# The Network Troubleshooting Pattern
ping ip
ping hostname
nslookup hostname
curl http://ip:port
curl http://hostname
tcpdump if needed
```

---

## Success Metrics

### What Success Looks Like

**Technical Success:**
- 9 services running reliably
- Survived multiple power events
- Complete recovery from Mac Pro failure
- Zero data loss incidents
- Successful rack migration

**Learning Success:**
- Can explain every configuration decision
- Can troubleshoot systematically
- Can deploy new services confidently
- Can recover from failures

**Family Success:**
- Services "just work"
- No complaints about speed
- Ad blocking appreciated
- Remote access valued

---

## Advice for Others

### If Starting Tomorrow

1. **Buy the router first** - Don't virtualize network infrastructure
2. **Plan the network** - Draw diagrams before creating VLANs
3. **Document as you go** - Not later, not tomorrow, NOW
4. **Use version tags** - :latest will hurt you
5. **Test backups** - Untested backups aren't backups
6. **Start simple** - Complexity can always be added
7. **Monitor from day 1** - You can't fix what you can't see
8. **Separate concerns** - One service per container
9. **Learn the basics** - Understand networking before SDN
10. **Enjoy the journey** - It's a homelab, not production
11. **Create shutdown/startup checklists** - Document the order before you need it
12. **Verify switch configs after physical changes** - Don't assume they persist
13. **External storage needs manual verification** - Boot timing is unreliable
14. **Keep fallback network access** - Dual-homed workstation saves time

### Red Flags to Avoid

- "I'll document this later"
- "Latest tag is fine"
- "I don't need VLANs yet"
- "Backups are running, that's enough"
- "This USB adapter will work fine"
- "I'll just put everything in one VM"
- "We don't need monitoring"
- "I know what this IP does"
- "The switch config will survive the move"
- "Auto-mount always works"

### Green Flags to Pursue

- "Let me document this first"
- "What version is stable?"
- "How should the network be segmented?"
- "Let's test the restore procedure"
- "Is there dedicated hardware for this?"
- "How can this be isolated?"
- "What metrics should we track?"
- "Future me will thank current me"
- "Let me verify the switch config"
- "I'll check the storage mount after boot"

---

## The Meta Lesson

### The Homelab Paradox

**Goal:** Learn enterprise technologies  
**Reality:** Learned troubleshooting, patience, and documentation  
**Truth:** The soft skills matter more than the technology

**What I Really Learned:**
- Problem-solving methodology
- Systematic thinking
- Documentation discipline
- Failure recovery
- Patient debugging
- Community engagement

**The Ultimate Lesson:**  
*Building a homelab isn't about the services you run - it's about the engineer you become while building it.*

---

## Final Thoughts

After 3 months and countless hours, the homelab is more than infrastructure - it's a learning platform that pays dividends in knowledge. Every failure taught resilience, every success built confidence, and every documentation entry saved future pain.

**Would I do it again?** Absolutely.  
**Would I do it the same way?** Not a chance.  
**Was it worth it?** Without question.

The journey from "what's a VLAN?" to running a fully segmented network with enterprise-grade services has been transformative. The mistakes were teachers, the community was invaluable, and the documentation became a personal knowledge base.

**To anyone considering a homelab:**  
Start. Make mistakes. Document them. Learn. Share. Grow.

The perfect homelab doesn't exist, but the perfect learning environment does - and you build it one mistake at a time.

---

*Remember: In homelabbing, as in life, the journey teaches more than the destination.*