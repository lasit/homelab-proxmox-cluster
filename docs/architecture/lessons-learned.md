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
11. [UPS & Power Protection](#ups--power-protection)
12. [Physical Infrastructure](#physical-infrastructure)

---

## Critical Lessons

### 1. The Router Must Be Physical Hardware

**Initial Assumption:** "I'll virtualize OPNsense on a Proxmox node"  
**Reality Check:** USB NICs are terrible with BSD  
**Time Wasted:** 2 weeks trying to make USB adapters work  
**Solution:** Bought Protectli FW4C for $400  
**Lesson:** Some infrastructure needs dedicated hardware

### 2. Version Tags Are Not Optional

**The n8n Incident:** Using :latest caused 3 hours of troubleshooting  
**Lesson:** ALWAYS use specific version tags in production

### 3. DNS Architecture with Reverse Proxy

**Concept:** All service DNS entries must point to the PROXY IP, not the service IP  
**Times This Bit Me:** 3 (Pi-hole, Uptime Kuma, Nextcloud)

### 4. Unprivileged LXC Has Limits

Docker inside LXC often works better than native services for complex applications.

---

## Network Lessons

### 5. VLANs Must Be Planned, Not Evolved

Draw the network diagram FIRST, build second.

### 6. All Trunk VLANs Should Be Tagged

Tag everything explicitly to avoid confusion.

### 7. Smart Home Devices: If It Works, Don't Touch It

Technical perfection < family harmony

---

## Container & Virtualization

### 8. Container Resources: Start Small, Scale Up

Most services use FAR less than allocated.

### 9. Auto-Start Is Not Automatic

Configure at LXC level, service level, AND Docker level.

### 10. Permissions Are Everything in Containers

Permission errors = check ownership first, config second.

---

## Storage Insights

### 11. Ceph Is Amazing But Hungry

3× replication means only 33% usable capacity.

### 12. Backup Storage Must Be Separate

Mac Pro NAS on different VLAN = different failure domain.

### 13. The Thunderbolt Timing Dance

Boot order matters with external storage - blacklist driver, load post-boot.

---

## Service Deployment

### 14. Build Order Matters

Database → Application → Cache → Frontend

### 15. One Service Per Container

Separation enables independent backups, updates, troubleshooting.

### 16. Docker Compose > Manual Docker

Infrastructure as code, even for containers.

---

## Troubleshooting Wisdom

### 17. The Troubleshooting Ladder

1. Can I ping it?
2. Can I access port?
3. Can I authenticate?
4. Does DNS resolve?
5. What do logs say?

### 18. Always Check Both Ends

Network problems need dual-ended debugging.

### 19. Logs Are Your Friends

Check logs first, restart second.

### 20. When In Doubt, Packet Capture

tcpdump shows what's actually happening vs what's configured.

---

## Documentation Value

### 21. Document Before Forgetting

Configure → Document → Verify

### 22. Screenshots Are Worth 1000 Words

OPNsense rules, switch config, dashboards.

### 23. Runbooks > Memory

Can follow procedure when stressed.

---

## Time & Cost Reality

### 24. Everything Takes 3x Longer

Budget time for learning, not just doing.

### 25. The True Cost Includes Tools

Hardware is 60% of cost, accessories/power protection is 40%.

---

## What I Wish I Knew Earlier

### 26. Start with the Router

Router → Switch → Cluster

### 27. Pi-hole Is Not Optional

Deploy DNS infrastructure early.

### 28. VLANs Can't Be "Fixed Later"

Plan network isolation from day 1.

### 29. Proxmox Cluster Quorum Matters

Understand `pvecm expected 1` for maintenance.

### 30. Backup Testing > Backup Creation

Untested backups aren't backups.

---

## Mistakes That Taught Me Most

### 31. The Great Redis Failure

Perfection is the enemy of good enough.

### 32. The Mac Pro Boot Loop

Patience > Force

### 33. The DNS Pointing Paradox

Question assumptions, check fundamentals.

### 34. The Docker :latest Trap

:latest is for development only.

### 35. The VLAN Native Confusion

Explicit > Implicit

---

## Philosophical Lessons

### 36. Simple Solutions Often Win

Docker Compose > Kubernetes for homelab.

### 37. Family Users != Tech Users

Make it work reliably, not flexibly.

### 38. Perfect Is the Enemy of Done

Working solution > perfect plan.

### 39. Learn by Breaking (In Dev)

Confidence through recovery.

### 40. Community Knowledge Is Gold

Someone has hit your error before.

---

## UPS & Power Protection

### 41. UPS Is Not Optional Infrastructure

**Initial Mindset:** "UPS is a nice-to-have"  
**Reality Check:** Darwin has tropical storms and power fluctuations  
**Decision:** CyberPower CP1600EPFCLCD-AU (1600VA/1000W)  
**Current Load:** ~17% (~142W), ~34-45 minutes runtime  
**Lesson:** Power protection is foundational infrastructure

### 42. NUT Makes UPS Smart

**Architecture:**
```
UPS ──USB──► pve1 (NUT Master)
                    │
         ┌──────────┼──────────┐
         ▼          ▼          ▼
       pve2       pve3     Mac Pro
     (Slave)    (Slave)    (Slave)
```
**Key Insight:** One USB connection, all systems monitored

### 43. Cross-VLAN NUT Requires Multiple Listen Addresses

**Problem:** Mac Pro on Storage VLAN (30), NUT on Management VLAN (10)  
**Solution:** NUT server listens on both VLANs
```bash
LISTEN 127.0.0.1 3493      # localhost
LISTEN 192.168.10.11 3493   # Management VLAN
LISTEN 192.168.30.11 3493   # Storage VLAN
```
**Lesson:** Plan NUT network access during VLAN design

### 44. Package Versions Matter Across Distributions

**Problem:** Mac Pro on Ubuntu 22.04, laptop on Ubuntu 24.04  
**Symptom:** Downloaded packages won't install (libc version mismatch)  
**Solution:** Download correct version for target OS  
**Lesson:** Always verify target OS before downloading packages

### 45. Cluster-Aware Shutdown Scripts Are Essential

**Default NUT Behavior:** Each system shuts down independently  
**Problem:** Ceph doesn't know it's intentional → starts rebalancing  
**Solution:** Custom shutdown script on master that:
1. Sets Ceph maintenance flags
2. Stops containers gracefully
3. Then initiates shutdown

**Lesson:** Distributed systems need coordinated shutdown

### 46. UPS Runtime Estimates Are Optimistic

**Rule of Thumb:** Expect 70% of stated runtime  
**Factors:** Battery age, temperature, load variation  
**Lesson:** Plan for shorter runtime than specified

---

## Physical Infrastructure

### 47. Rack Migration Requires Written Checklists

**First Attempt:** "I'll remember the order"  
**Result:** Almost forgot Ceph flags  
**Solution:** Written checklist for shutdown/startup sequence  
**Lesson:** Complex operations need written procedures

### 48. Switch Ports Reset After Physical Changes

**Surprise:** UniFi Switch Port 15 reset to Default VLAN after rack move  
**Impact:** Mac Pro unreachable  
**Recovery:** Reconfigured via UniFi Controller  
**Lesson:** Always verify switch config after physical changes

### 49. Label Everything

Cables, ports, IPs on physical hosts  
**Lesson:** Labels are cheap, confusion is expensive

### 50. Keep ISP Network Available During Maintenance

Dual-homed laptop provides fallback management path  
**Lesson:** Always have a fallback management path

---

## Advice for Others

### If Starting Tomorrow

1. **Buy the router first**
2. **Plan the network**
3. **Document as you go**
4. **Use version tags**
5. **Test backups**
6. **Start simple**
7. **Monitor from day 1**
8. **Separate concerns**
9. **Learn the basics**
10. **Enjoy the journey**
11. **Get a UPS early**
12. **Label your cables**
13. **Verify switch config after moves**
14. **Plan NUT across VLANs**

### Red Flags to Avoid

- "I'll document this later"
- "Latest tag is fine"
- "UPS is optional"
- "I'll remember the shutdown order"
- "Backups are running, that's enough"

### Green Flags to Pursue

- "Let me document this first"
- "What version is stable?"
- "What happens if power fails?"
- "Let me create a checklist"
- "Let's test the restore procedure"

---

## The Meta Lesson

*Building a homelab isn't about the services you run - it's about the engineer you become while building it.*

---

*Remember: In homelabbing, as in life, the journey teaches more than the destination.*