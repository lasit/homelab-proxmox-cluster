# 🎓 Lessons Learned from Building a Proxmox Homelab

**Last Updated:** 2025-11-25  
**Project Duration:** 2 months (October - November 2025)  
**Services Deployed:** 7 containers + infrastructure  
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
**Learning:** Check service side simultaneously

```bash
# From client
curl http://service.local

# From service
curl http://localhost
netstat -tlnp | grep :port
```

**Revelation:** Often service is fine, routing is broken

### 19. Logs Don't Lie (But They Hide)

**Log Locations I Always Forget:**

| Service | Log Location |
|---------|-------------|
| Proxmox | /var/log/pve/tasks/ |
| Container systemd | journalctl -xe |
| Docker containers | docker logs container-name |
| OPNsense | /var/log/system.log |
| Application | Check documentation! |

**Lesson:** `journalctl -f` is your friend

### 20. When In Doubt, Restart in Order

**The Recovery Sequence:**
1. Network (but not router!)
2. Storage mounts
3. Databases
4. Applications
5. Frontend services

**Never Restart Together:** Cluster nodes (lose quorum)

---

## Documentation Value

### 21. Documentation Debt Is Real

**Week 1:** "I'll remember this"  
**Week 4:** "What does this IP do?"  
**Week 8:** "How did I configure this?"

**Documentation ROI:**
- Mac Pro recovery: 30 min (had docs) vs 4 hours (would be guessing)
- Service deployment: Copy-paste from docs
- Troubleshooting: Check "Known Issues" first

**Lesson:** Document while doing, not after

### 22. Screenshots Are Not Documentation

**Initial Approach:** Screenshot everything  
**Problem:** Can't search, can't copy-paste, gets outdated  
**Better Approach:** Commands and configuration as text

```bash
# This is searchable, copyable, versionable
pct create 100 local:vztmpl/debian-12-standard.tar.zst \
  --hostname service \
  --cores 2 \
  --memory 2048
```

### 23. Error Messages Are Gold

**Habit Developed:** Copy EXACT error messages

**Example That Saved Hours:**
```
Error: EACCES: permission denied, open '/home/node/.n8n/config'
```
**Result:** Found others with same issue, solution was version pinning

**Lesson:** Document errors verbatim, including context

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
- 7 services running reliably
- Survived multiple power events
- Complete recovery from Mac Pro failure
- Zero data loss incidents

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

### Red Flags to Avoid

- "I'll document this later"
- "Latest tag is fine"
- "I don't need VLANs yet"
- "Backups are running, that's enough"
- "This USB adapter will work fine"
- "I'll just put everything in one VM"
- "We don't need monitoring"
- "I know what this IP does"

### Green Flags to Pursue

- "Let me document this first"
- "What version is stable?"
- "How should the network be segmented?"
- "Let's test the restore procedure"
- "Is there dedicated hardware for this?"
- "How can this be isolated?"
- "What metrics should we track?"
- "Future me will thank current me"

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

After 2 months and countless hours, the homelab is more than infrastructure - it's a learning platform that pays dividends in knowledge. Every failure taught resilience, every success built confidence, and every documentation entry saved future pain.

**Would I do it again?** Absolutely.  
**Would I do it the same way?** Not a chance.  
**Was it worth it?** Without question.

The journey from "what's a VLAN?" to running a fully segmented network with enterprise-grade services has been transformative. The mistakes were teachers, the community was invaluable, and the documentation became a personal knowledge base.

**To anyone considering a homelab:**  
Start. Make mistakes. Document them. Learn. Share. Grow.

The perfect homelab doesn't exist, but the perfect learning environment does - and you build it one mistake at a time.

---

*Remember: In homelabbing, as in life, the journey teaches more than the destination.*