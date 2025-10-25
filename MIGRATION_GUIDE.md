# 📚 Documentation Migration Guide

**Purpose:** Map old documentation files to new structure  
**Date:** October 25, 2025

## Old Files → New Structure Mapping

### Status Files (Consolidated)
**Old Files:**
- PROJECT_STATUS_SUMMARY.md
- INSTALLATION_PROGRESS.md
- PHASE_5_CEPH_COMPLETE.md
- PHASE_4_CLUSTER_CREATION_COMPLETE.md

**New Location:**
- `CURRENT_STATUS.md` - Single source of truth
- Phase details moved to `/lessons-learned/`

### Architecture Documentation
**Old Files:**
- network-design.md
- system-overview.md

**New Location:**
- `/architecture/network-design.md` - Consolidated and updated
- `/architecture/hardware-inventory.md` - Extracted hardware details
- `/architecture/storage-architecture.md` - To be created

### Installation Guides
**Old Files:**
- installation-runbook.md
- PVE_INSTALLATION_VALIDATED_GUIDE.md
- PVE_INSTALLATION_QUICK_REFERENCE.md
- INSTALLATION_RUNBOOK_UPDATES.md

**New Location:**
- `/installation/00-prerequisites.md` - Pre-flight checklist
- `/installation/01-opnsense.md` - To be created
- `/installation/02-switch-config.md` - To be created
- `/installation/03-proxmox-nodes.md` - To be created
- `/installation/04-cluster-creation.md` - To be created
- `/installation/05-ceph-storage.md` - To be created

### Service Documentation
**Old Files:**
- service-catalog.md
- tailscale-guide.md

**New Location:**
- `/services/service-catalog.md` - Updated with tiers
- `/services/tailscale-setup.md` - To be created from guide
- `/services/configs/*/` - Service-specific configurations

### Lessons Learned
**Old Files:**
- PHASE_3_LESSONS_LEARNED.md
- PHASE_3_COMPLETE_DOCUMENTATION.md
- TECHNICAL_NOTES.md

**New Location:**
- `/lessons-learned/phase-1-router.md` - To be extracted
- `/lessons-learned/phase-2-networking.md` - To be extracted
- `/lessons-learned/phase-3-proxmox.md` - To be extracted
- `/lessons-learned/phase-4-clustering.md` - To be extracted
- `/lessons-learned/phase-5-ceph.md` - To be extracted

### Operations Documentation
**Old Files:**
- backup-strategy.md
- TROUBLESHOOTING_GUIDE.md
- quick-start.md

**New Location:**
- `/operations/backup-strategy.md` - To be migrated
- `/operations/troubleshooting.md` - To be migrated
- `/operations/monitoring.md` - To be created
- `/operations/maintenance.md` - To be created

### Reference Documentation
**Old Files:**
- project-instructions.md
- FILE_UPLOAD_INSTRUCTIONS.md

**New Location:**
- `/reference/commands.md` - To be extracted
- `/reference/urls.md` - To be created
- `/reference/darwin-specific.md` - To be created

## Files to Retire

These files are no longer needed in the new structure:
- DOCUMENTATION_COMPLETE_SUMMARY.md (redundant)
- PHASE_3_SUMMARY.md (consolidated)
- FILE_UPLOAD_INSTRUCTIONS.md (obsolete)
- Multiple overlapping installation guides

## Migration Steps

### Phase 1: Structure Creation ✅
1. Create directory structure
2. Create main README.md
3. Create CURRENT_STATUS.md
4. Create key architecture docs

### Phase 2: Content Migration (To Do)
1. Extract lessons learned from phase documents
2. Consolidate installation guides
3. Update service configurations
4. Create missing reference docs

### Phase 3: Validation
1. Review all links
2. Verify no information lost
3. Test procedures against new docs
4. Archive old documentation

## Key Improvements in New Structure

### Single Source of Truth
- One status file instead of multiple
- Clear hierarchy of information
- No duplicate content

### Better Organization
- Logical folder structure
- Easy to find information
- Clear naming conventions

### Git-Friendly
- Markdown files only
- Small, focused documents
- Easy to track changes

### Future-Proof
- Room for growth
- Service-specific folders
- Scalable structure

## Information Still Needed

### From You
1. **Hardware Details**
   - Serial numbers
   - MAC addresses
   - Exact purchase dates
   - Current power consumption

2. **Network Specifics**
   - ISP router model
   - Internet speed
   - NBN type

3. **Current State**
   - Any VMs/containers running?
   - Tailscale installed anywhere?
   - Any services deployed?

### To Be Documented
1. **Detailed installation steps** for each phase
2. **Service deployment guides** with screenshots
3. **Troubleshooting procedures** from experience
4. **Update/maintenance procedures**
5. **Disaster recovery plans**

## Quick Command Reference

### Copy documentation to laptop
```bash
# On your laptop
cd ~/Documents/Homelab_Promox_Cluster_Project/
scp -r root@<your-IP>:/home/claude/homelab-proxmox-cluster .
```

### Set up GitHub
```bash
cd homelab-proxmox-cluster
chmod +x setup-github.sh
./setup-github.sh
```

### Keep documentation updated
```bash
# After changes
git add .
git commit -m "Update: description of changes"
git push
```

## Next Actions

1. **Review** the created structure
2. **Answer** the verification questions
3. **Run** the GitHub setup script
4. **Migrate** remaining content
5. **Start** Phase 6 with clean documentation

---

**Note:** The old documentation files are preserved until migration is complete. No information has been lost, only reorganized for clarity.
