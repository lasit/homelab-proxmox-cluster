# 🏗️ Design Decisions & Architecture Rationale

**Last Updated:** 2025-11-25  
**Project Started:** October 2025  
**Purpose:** Document the "why" behind technology choices for the homelab

## 📚 Table of Contents

1. [Core Principles](#core-principles)
2. [Hardware Decisions](#hardware-decisions)
3. [Network Architecture](#network-architecture)
4. [Storage Strategy](#storage-strategy)
5. [Service Architecture](#service-architecture)
6. [Security Decisions](#security-decisions)
7. [Operational Choices](#operational-choices)
8. [Trade-offs & Alternatives Considered](#trade-offs--alternatives-considered)

---

## Core Principles

### 1. Reliability Over Bleeding Edge
**Decision:** Use proven, stable technologies rather than newest releases  
**Rationale:**
- 10-year operational horizon requires stability
- Darwin location means no quick hardware replacements
- Family depends on services (smart home, file storage)
- Learning happens better on stable platforms

**Implementation:**
- Proxmox VE instead of experimental hypervisors
- Debian/Ubuntu instead of rolling releases
- LTS versions where available
- Version pinning for critical services (n8n 1.63.4 not :latest)

### 2. Learn by Doing
**Decision:** Build everything from scratch rather than using turnkey solutions  
**Rationale:**
- Understanding requires hands-on experience
- Troubleshooting skills come from building
- Career development in enterprise IT
- Satisfaction of self-built infrastructure

**Implementation:**
- Manual VLAN configuration instead of SDN
- Building containers from base OS
- Writing own automation scripts
- Comprehensive documentation of every step

### 3. Data Sovereignty
**Decision:** Keep all data in Australia under personal control  
**Rationale:**
- Privacy concerns with cloud providers
- Australian data should stay in Australia
- No subscription fees for basic services
- Complete control over data lifecycle

**Implementation:**
- Nextcloud instead of Google Drive
- Local Obsidian sync via WebDAV
- Self-hosted photo management planned
- All backups on local storage

### 4. Cost Efficiency
**Decision:** Optimize for Darwin's high electricity costs ($0.30/kWh)  
**Rationale:**
- Power is major ongoing operational cost
- Every watt counts at Darwin rates
- Hardware efficiency more important than raw power

**Implementation:**
- HP Elite Mini (45W idle) instead of full servers
- Shared storage (Ceph) instead of dedicated NAS initially
- Container-first approach (lower overhead than VMs)
- Mac Pro repurposed instead of new NAS

---

## Hardware Decisions

### Compute Nodes: HP Elite Mini 800 G9

**Decision:** 3× HP Elite Mini instead of single powerful server  
**Rationale:**
- **High Availability:** Cluster survives node failures
- **Power Efficiency:** 45W each vs 200W+ for servers
- **Quiet Operation:** Fanless possible in Darwin climate
- **Cost Effective:** ~$650 each vs $3000+ for server
- **Sufficient Power:** 6 cores, 32GB RAM per node plenty

**Alternatives Considered:**
- Dell R730 (rejected: 200W idle, noisy, overkill)
- Single NUC (rejected: no redundancy)
- Raspberry Pi cluster (rejected: ARM limitations)

### Router: Protectli FW4C

**Decision:** Dedicated hardware router instead of virtualized  
**Initial Plan:** HP Elite Mini with OPNsense  
**Changed To:** Protectli FW4C  
**Rationale:**
- USB NICs unreliable with BSD
- Router needs dedicated hardware
- 4× 2.5GbE ports for future growth
- Silent fanless operation
- Rock-solid Intel NICs

**Cost:** $400 AUD (vs $844 for higher-end VP2420)  
**Result:** Perfect stability, no issues since deployment

### Network Switch: UniFi Switch Lite 16 PoE

**Decision:** Managed PoE switch with VLAN support  
**Rationale:**
- **VLAN Support:** Essential for network segmentation
- **PoE Budget:** 45W for access points and IoT
- **Port Count:** 16 ports sufficient with room to grow
- **Management:** UniFi controller already familiar
- **Price:** Good value at ~$300 AUD

**Alternatives Considered:**
- Netgear managed switch (rejected: poor VLAN UI)
- MikroTik (rejected: steep learning curve)
- Cisco (rejected: expensive, complex for home use)

### Storage: Mac Pro Repurpose

**Decision:** Repurpose 2013 Mac Pro as NAS  
**Rationale:**
- **Already Owned:** Zero additional cost
- **Thunderbolt Storage:** 9.1TB Pegasus array included
- **Sufficient Performance:** Gigabit ethernet adequate
- **Power Efficient:** ~75W idle with array
- **Ubuntu Compatible:** Proven Linux support

**Challenges:**
- Boot hang issue with stex driver (resolved)
- Thunderbolt timing issues (solved with delayed mount)
- Network isolation on Storage VLAN

---

## Network Architecture

### VLAN Segmentation Strategy

**Decision:** 5 VLANs with strict isolation  
**Implementation:**

| VLAN | Purpose | Routing | Rationale |
|------|---------|---------|-----------|
| 10 | Management | Full access | Admin traffic isolation |
| 20 | Corosync | None | Cluster heartbeat protection |
| 30 | Storage | None | Ceph traffic isolation |
| 40 | Services | Internet only | Service separation |
| 50 | Neighbor | Internet only | Complete isolation |

**Rationale:**
- Security through isolation
- Performance isolation for storage/cluster
- Compliance with best practices
- Learning enterprise patterns

### All VLANs Tagged

**Decision:** No native VLANs on trunk ports  
**Rationale:**
- Cleaner configuration
- Avoids VLAN hopping attacks
- Explicit VLAN assignment
- Industry best practice

**Exception:** Mac Pro on native VLAN 30 (single-purpose device)

### Smart Home on ISP Network

**Decision:** Keep IoT devices on 10.1.1.x (not migrated)  
**Rationale:**
- Working system shouldn't be broken
- Family disruption minimized
- MQTT broker established connections
- Complexity not worth the benefit

**Implementation:**
- OPNsense routes between networks
- Firewall rules control access
- Future migration possible if needed

---

## Storage Strategy

### Ceph for Primary Storage

**Decision:** Distributed Ceph instead of central NAS  
**Rationale:**
- **High Availability:** Survives node failures
- **Performance:** Local NVMe speed
- **Learning:** Enterprise storage technology
- **Included:** No additional hardware needed
- **Scalable:** Can add OSDs as needed

**Configuration:**
- 3× 500GB NVMe OSDs
- Size 3/Min 2 replication
- 172GB usable capacity
- Sufficient for VMs/containers

### Mac Pro for Backup Storage

**Decision:** Separate backup storage from primary  
**Rationale:**
- **3-2-1 Rule:** Different storage system
- **Capacity:** 9.1TB for long-term retention
- **Isolation:** Storage VLAN separation
- **Cost:** Repurposed hardware

**Implementation:**
- SSHFS mounts from all nodes
- Automated VZDump backups
- 7-day, 4-week, 6-month retention

---

## Service Architecture

### Container-First Approach

**Decision:** LXC containers preferred over VMs  
**Rationale:**
- **Lower Overhead:** ~100MB vs 1GB+ RAM
- **Faster Deployment:** Seconds vs minutes
- **Better Density:** More services per node
- **Native Performance:** No virtualization penalty

**Exceptions:**
- Services requiring kernel modules (future)
- Windows-based services (if needed)
- Services requiring full isolation

### Service Separation

**Decision:** One service per container  
**Rationale:**
- **Isolation:** Service failures contained
- **Maintenance:** Update one service without affecting others
- **Resources:** Easier to allocate and monitor
- **Backup:** Granular backup control

**Implementation:**
- Nextcloud (CT104) separate from MariaDB (CT105)
- Each service gets dedicated IP
- Clear dependency mapping

### Docker for Complex Services

**Decision:** Docker inside LXC for certain services  
**Rationale:**
- **Version Management:** Easy updates and rollbacks
- **Dependency Isolation:** No system contamination
- **Systemd Issues:** Bypass namespace restrictions
- **Portability:** Easy migration if needed

**Examples:**
- Nginx Proxy Manager (Docker in CT102)
- Uptime Kuma (Docker in CT103)
- n8n (Docker in CT112)

### Database Separation

**Decision:** Dedicated database container  
**Rationale:**
- **Performance:** Dedicated resources for database
- **Backup:** Separate database backups
- **Sharing:** Multiple services can use same database
- **Management:** Centralized database administration

**Implementation:**
- MariaDB in CT105
- Network accessible only from specific IPs
- Separate backup strategy

---

## Security Decisions

### Zero Trust Networking

**Decision:** No trust between VLANs by default  
**Rationale:**
- Defense in depth
- Limit breach impact
- Learn proper security practices
- Industry standard approach

**Implementation:**
- Explicit firewall rules for any inter-VLAN traffic
- Services isolated by default
- Management network separate

### Tailscale for Remote Access

**Decision:** Tailscale VPN instead of port forwarding  
**Rationale:**
- **Zero Config:** Works through CGNAT
- **Security:** WireGuard encryption
- **Usability:** No certificates to manage
- **Free Tier:** Sufficient for home use

**Trade-offs:**
- Dependency on external service
- Requires internet for authentication
- Another service to trust

### No Public Exposure

**Decision:** No services directly exposed to internet  
**Rationale:**
- Reduces attack surface
- No certificate management (yet)
- Family safety
- Learning internally first

**Future:** May expose certain services with proper SSL/reverse proxy

---

## Operational Choices

### Comprehensive Documentation

**Decision:** Document everything in detail  
**Rationale:**
- **Future Self:** Will forget details in 6 months
- **Disaster Recovery:** Quick restoration possible
- **Knowledge Sharing:** Can help others
- **Learning:** Writing reinforces understanding

**Implementation:**
- Step-by-step deployment guides
- Architecture diagrams
- Troubleshooting database
- Decision documentation (this file)

### Manual Before Automation

**Decision:** Build manually first, automate later  
**Rationale:**
- Understanding requires manual process
- Automation hides important details
- Debugging easier when you built it
- Automation meaningful after understanding

**Examples:**
- Manual VLAN configuration before considering SDN
- Manual backups before automated schedules
- Manual monitoring before Prometheus/Grafana

### Conservative Update Policy

**Decision:** Don't update unless necessary  
**Rationale:**
- Stability over features
- "If it ain't broke, don't fix it"
- Updates can introduce bugs
- Time is valuable resource

**Implementation:**
- Security updates: Yes
- Feature updates: Evaluate carefully
- Major versions: Test first
- Version pinning where critical

---

## Trade-offs & Alternatives Considered

### Considered: Single Powerful Server

**Option:** Dell R730 or similar  
**Pros:**
- More RAM/CPU capacity
- Hardware RAID
- IPMI/iDRAC

**Cons:**
- 200W+ power consumption
- Noise levels
- No redundancy
- Expensive

**Decision:** Rejected for power/noise/redundancy reasons

### Considered: Kubernetes

**Option:** K3s or full K8s cluster  
**Pros:**
- Industry standard
- Great learning
- Auto-scaling
- Self-healing

**Cons:**
- Complexity overkill for home
- Resource overhead
- Learning curve
- Another abstraction layer

**Decision:** Rejected as over-engineering for home use

### Considered: TrueNAS

**Option:** TrueNAS for storage  
**Pros:**
- ZFS benefits
- Nice web UI
- Integrated apps
- Popular choice

**Cons:**
- Requires dedicated hardware
- BSD base (less familiar)
- Memory hungry
- Another system to manage

**Decision:** Deferred - might revisit when need more storage

### Considered: All Docker/Docker Compose

**Option:** Everything in Docker  
**Pros:**
- Consistent deployment
- Easy migration
- Version management
- Popular approach

**Cons:**
- Loses LXC benefits
- More overhead
- Another abstraction
- Network complexity

**Decision:** Hybrid approach - LXC first, Docker where beneficial

### Considered: Cloud Backup

**Option:** Backblaze B2 or similar  
**Pros:**
- True offsite backup
- Disaster proof
- Relatively cheap

**Cons:**
- Ongoing costs
- Internet dependency
- Privacy concerns
- Slow restores

**Decision:** Deferred - implement after local backup proven

---

## Validation of Decisions

### What's Working Well

1. **3-Node Cluster:** Survived multiple maintenance windows
2. **VLAN Segmentation:** Clean isolation, no security issues
3. **Container Approach:** Low resource usage, fast deployment
4. **Tailscale:** Perfect remote access solution
5. **Documentation:** Invaluable during troubleshooting

### What Would We Change

1. **Router First:** Should have bought Protectli immediately
2. **Skip Redis:** Not worth the troubleshooting time
3. **Docker Earlier:** For services with systemd issues
4. **More RAM:** 32GB sufficient but 64GB would be comfortable
5. **UPS Immediately:** Power protection should be day 1

### Decisions Pending Review

1. **Backup Strategy:** Need offsite component
2. **Storage Capacity:** Ceph filling up faster than expected
3. **Monitoring:** Need better observability
4. **SSL Certificates:** Should implement proper certificates
5. **IoT Migration:** May eventually move to VLANs

---

## Cost Analysis

### Initial Hardware Investment
- 3× HP Elite Mini: ~$1,950 AUD
- Protectli FW4C: $400 AUD
- UniFi Switch: $300 AUD
- **Total:** ~$2,650 AUD

### Annual Operating Costs
- Power (142W average): ~$374 AUD
- Domain (future): ~$20 AUD
- Cloud backup (future): ~$60 AUD
- **Total:** ~$454 AUD/year

### Compared to Cloud
- Google One 2TB: $125 AUD/year
- Dropbox Plus: $180 AUD/year
- Various SaaS: $500+ AUD/year
- **Savings:** Break-even in ~4 years

---

## Conclusion

The architecture decisions have proven sound for a homelab that prioritizes:
- Learning enterprise technologies
- Family-friendly reliability
- Power efficiency in tropical climate
- Data sovereignty
- Long-term sustainability

The modular approach allows for incremental improvements without major redesigns, and the comprehensive documentation ensures knowledge preservation.

**Key Success Factors:**
1. Start simple, expand gradually
2. Document everything
3. Test before production
4. Separate concerns (network, storage, services)
5. Plan for failure (HA, backups)

**Next Major Decisions:**
1. Offsite backup strategy
2. Storage expansion approach
3. SSL certificate implementation
4. Observability stack
5. Service expansion priorities