# Rack Migration Log - 2025-12-02

**Date:** 2025-12-02  
**Type:** Planned Maintenance  
**Duration:** ~1 hour  
**Outcome:** ✅ Successful

## Overview

Migrated all homelab infrastructure from desktop deployment to 16U rack.

## Equipment Moved

- ✅ Mac Pro (Late 2013) with Promise Pegasus R6 array
- ✅ 3× HP Elite Mini 800 G9 (pve1, pve2, pve3)
- ✅ Protectli FW4C (OPNsense router)
- ✅ UniFi Switch Lite 16 PoE

## Shutdown Sequence Followed

1. Stopped SSHFS mounts on Proxmox nodes
2. Unmounted Pegasus storage on Mac Pro
3. Shut down Mac Pro (via SSH)
4. Powered off Pegasus array
5. Stopped all containers (reverse dependency order)
6. Set Ceph maintenance flags (noout, nobackfill, norebalance)
7. Shut down Proxmox nodes (pve3 → pve2 → pve1)
8. Powered off UniFi Switch
9. Powered off OPNsense router

## Startup Sequence Followed

1. Powered on UniFi Switch
2. Powered on OPNsense router
3. Connected laptop to switch, verified network
4. Powered on Pegasus array (waited 30 seconds)
5. Powered on Mac Pro (waited 3 minutes)
6. Powered on Proxmox nodes (pve1 → pve2 → pve3)
7. Verified cluster quorum
8. Cleared Ceph maintenance flags
9. Restarted SSHFS mounts

## Issues Encountered

### 1. UniFi Switch Port 15 Reset to Default VLAN

**Symptom:** Mac Pro could not ping gateway (192.168.30.1)

**Cause:** During rack migration, UniFi Switch Port 15 was configured as "Default (1)" instead of "Storage (30)"

**Resolution:** 
1. Accessed UniFi Controller via CT107
2. Changed Port 15 Native VLAN from "Default (1)" to "Storage (30)"
3. Mac Pro immediately reachable

**Prevention:** Document switch port assignments and verify after any physical changes

### 2. Mac Pro Pegasus Did Not Auto-Mount

**Symptom:** `/storage` not mounted after Mac Pro boot

**Cause:** Boot timing issue - Thunderbolt device not fully initialized when systemd pegasus-mount.service runs

**Resolution:** 
```bash
sudo /usr/local/bin/mount-pegasus.sh
```

**Status:** Service is enabled (`systemctl is-enabled pegasus-mount.service` returns "enabled"), but timing remains an issue

**Potential Fix:** Investigate adding longer delay or retry logic to mount script

### 3. Laptop Default Route via ISP Router

**Symptom:** Laptop had no internet despite being on homelab network

**Cause:** Laptop had dual routes (ISP 10.1.1.1 at metric 100, OPNsense 192.168.10.1 at metric 400)

**Resolution:** 
```bash
sudo ip route del default via 10.1.1.1
```

**Note:** Temporary fix - reverts on reboot. Not a homelab issue, just laptop network config.

## Post-Migration Verification

All checks passed:

```
✅ OPNsense reachable at 192.168.10.1
✅ Mac Pro NAS reachable at 192.168.30.20
✅ Pegasus storage mounted at /storage (9.1TB)
✅ All 3 Proxmox nodes online
✅ Cluster quorum established
✅ Ceph HEALTH_OK
✅ All 9 containers running
✅ SSHFS mounts restored on all nodes
✅ Pi-hole DNS working
✅ Uptime Kuma accessible
```

## Lessons Learned

1. **Verify switch port configs after physical changes** - UniFi may reset port settings
2. **Mac Pro Pegasus requires manual mount** - Build this into startup checklist
3. **Keep laptop dual-homed during maintenance** - ISP route provides backup internet
4. **Document the correct switch port assignments** - Port 15 = Storage VLAN 30

## Time Breakdown

| Phase | Duration |
|-------|----------|
| Shutdown sequence | 10 minutes |
| Physical rack work | 30 minutes |
| Startup sequence | 15 minutes |
| Troubleshooting issues | 15 minutes |
| Verification | 5 minutes |
| **Total** | ~75 minutes |

## Files to Update

- [x] CURRENT_STATUS.md - Add rack migration entry
- [ ] network-table.md - Verify Port 15 documented correctly
- [ ] power-management.md - Add note about rack deployment
- [ ] troubleshooting.md - Add switch port reset issue

---

*Migration completed successfully with minor issues resolved*