# 📚 Lessons Learned - Phases 1-5

**Last Updated:** October 25, 2025  
**Project Duration:** 3 days (Oct 22-25, 2025)

## Phase 1: OPNsense Router

### What Went Wrong
- **Single NIC Limitation:** HP Elite Mini only has one ethernet port
- **USB Adapter Failure:** Comsol USB-C adapter incompatible with FreeBSD
- **Assumption Error:** Assumed USB networking would work reliably for router

### Key Learnings
1. **Always verify NIC count** before choosing router hardware
2. **USB network adapters** are not suitable for BSD-based routers
3. **FreeBSD interface naming:** em0 not eno1
4. **VLAN syntax:** em0_vlan10 (underscore notation)

### What to Do Differently
- Research hardware compatibility thoroughly
- Check BSD hardware compatibility lists
- Use purpose-built router hardware

## Phase 2: Switch Configuration

### What Went Well
- UniFi switch configuration was straightforward
- VLAN setup worked first time
- Port labeling helped avoid confusion

### Key Learnings
1. **Native VLAN matters:** ISP router needs untagged traffic
2. **Trunk ports:** Essential for multi-VLAN devices
3. **Documentation:** Screenshot all configurations

## Phase 3: Proxmox Installation

### What Went Well
- Installation process smooth once pattern established
- Third node took only 30 minutes

### Key Learnings
1. **VLAN sub-interface approach works:** vmbr0.10, vmbr0.20, etc.
2. **Bridge must be VLAN-aware:** `bridge-vlan-aware yes` critical
3. **Gateway rule:** Only Management VLAN gets gateway
4. **Install offline first:** Configure network after installation

### Common Mistakes Avoided
- Don't assign IPs to physical interface
- Don't assign IPs to main bridge
- Don't add gateways to isolated VLANs

## Phase 4: Cluster Creation

### What Went Well
- Cluster creation took only 15 minutes
- Corosync on dedicated VLAN worked perfectly
- Quorum established immediately

### Key Learnings
1. **Time sync critical:** NTP must be working
2. **Dedicated cluster network:** VLAN 20 isolation perfect
3. **Node IDs:** Sequential and automatic

### Best Practice Confirmed
- Use dedicated network for Corosync
- Test connectivity before clustering
- Join nodes one at a time

## Phase 5: Ceph Storage

### What Went Well
- Installation smooth after repository fix
- Performance good on VLAN 30
- 3x replication working perfectly

### Key Learnings
1. **Use no-subscription repos:** Enterprise repos need license
2. **Storage pre-planning:** Had to resize LVM for Ceph
3. **Monitor placement:** One per node is ideal
4. **Network importance:** Dedicated storage VLAN worth it

### Ceph Specific
- Start with small PG count (32 for small cluster)
- Let Ceph manage itself mostly
- Monitor network more important than OSD network initially

## Overall Project Insights

### Time Investment
| Phase | Estimated | Actual | Reason for Variance |
|-------|-----------|--------|---------------------|
| Phase 1 | 2-3h | 3h | Learning FreeBSD |
| Phase 2 | 1h | 1h | As expected |
| Phase 3 | 2-3h | 3.5h | VLAN troubleshooting |
| Phase 4 | 30m | 15m | Faster than expected |
| Phase 5 | 1h | 45m | Smooth process |
| **Total** | 6.5-8.5h | 8.25h | Very close to estimate |

### What Worked Well
1. **Hardware choice:** HP Elite Minis perfect for nodes
2. **VLAN strategy:** Isolation working as designed
3. **Documentation:** Having guides helped immensely
4. **Incremental approach:** Phase by phase was right
5. **UniFi switch:** Great choice for VLAN management

### What Didn't Work
1. **Router hardware:** Single NIC was showstopper
2. **USB networking:** Complete failure for BSD
3. **Initial assumptions:** Should have verified hardware

### Critical Success Factors
1. **Proper router hardware:** Non-negotiable
2. **Network planning:** VLANs designed correctly
3. **Patience:** Not rushing through steps
4. **Documentation:** Write everything down
5. **Testing:** Verify each step before proceeding

## Technical Specifications Confirmed

### Network Performance
- **Corosync latency:** 1-2ms (excellent)
- **Storage latency:** 1-2ms (excellent)
- **Management access:** Responsive
- **VLAN isolation:** Complete

### Resource Usage
- **Power draw:** ~75W (3 nodes without router)
- **Heat generation:** Minimal, no cooling issues
- **Noise level:** Silent operation

## Recommendations for Others

### Hardware Selection
1. **Router MUST have** 2+ Intel NICs
2. **Nodes:** HP Elite Mini or similar work great
3. **Switch:** Managed with VLAN support essential
4. **Storage:** NVMe recommended for Ceph

### Network Design
1. **Separate VLANs** for management/cluster/storage
2. **Document everything** including IP allocations
3. **Test incrementally** don't configure everything at once

### Software Approach
1. **Use no-subscription repositories** for homelab
2. **Latest stable versions** work fine
3. **Keep configurations simple** initially

## Cost Analysis Review

### Actual Costs
- **Initial hardware:** ~$2000 AUD (nodes + switch)
- **Router fix:** $844 AUD (Protectli)
- **Total investment:** ~$2850 AUD

### Value Assessment
- **Learning value:** Priceless
- **Reliability:** Enterprise-grade
- **Longevity:** 10-year capable
- **Cost per year:** ~$285 amortized

## Future Improvements

### Short Term
1. Install proper router (Protectli ordered)
2. Deploy Phase 6 services
3. Implement backup strategy
4. Add monitoring

### Long Term
1. 10Gb networking for storage
2. Additional nodes for capacity
3. Dedicated backup storage
4. UPS protection

## Darwin-Specific Observations

### Environmental
- **Temperature:** No cooling issues despite heat
- **Humidity:** No problems observed
- **Power stability:** No issues encountered

### Network
- **NBN performance:** Adequate for homelab
- **Latency to Sydney:** ~88ms (acceptable)
- **Local resources:** Limited but manageable

## Documentation Improvements Needed

1. **Add troubleshooting section** for common issues
2. **Create network diagram** with port mappings
3. **Build command reference** for quick access
4. **Develop recovery procedures** for failures

## Final Verdict

**Project Status:** Successful with minor setback (router)

**Key Achievement:** Fully functional 3-node cluster with distributed storage

**Main Challenge:** Router hardware selection

**Resolution:** Proper hardware ordered

**Overall Assessment:** Project on track, learning objectives met, ready for service deployment once router installed.

---

**Most Important Lesson:** Don't compromise on critical infrastructure components. A proper router is worth the investment.
