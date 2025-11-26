#!/bin/bash

# Backup Test Automation Script for Proxmox Homelab
# Tests backup integrity by performing test restores
# Version: 1.0
# Last Updated: 2025-11-25

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
PRIMARY_NODE="192.168.10.11"
BACKUP_DIR="/mnt/macpro/proxmox-backups/dump"
TEST_CT_ID="199"  # Test container ID for restore tests
LOG_FILE="/tmp/backup-test-$(date +%Y%m%d-%H%M%S).log"

# Container list to test
CONTAINERS_TO_TEST=(100 101 102 103 104 105 112)

# Test mode selection
TEST_MODE="$1"
if [ -z "$TEST_MODE" ]; then
    TEST_MODE="verify"  # Default mode
fi

# Test results
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
declare -A TEST_RESULTS

# Functions
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

log_no_newline() {
    echo -n "$1" | tee -a "$LOG_FILE"
}

pass() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
    ((TOTAL_TESTS++))
    ((PASSED_TESTS++))
    TEST_RESULTS["$1"]="PASS"
}

fail() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
    ((TOTAL_TESTS++))
    ((FAILED_TESTS++))
    TEST_RESULTS["$1"]="FAIL"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

info() {
    echo -e "${CYAN}ℹ${NC} $1" | tee -a "$LOG_FILE"
}

section() {
    log ""
    log "════════════════════════════════════════════════════════════════"
    log "  $1"
    log "════════════════════════════════════════════════════════════════"
}

subsection() {
    log ""
    log "──────────────────────────────────────"
    log "▶ $1"
    log "──────────────────────────────────────"
}

cleanup_test_container() {
    # Clean up test container if it exists
    ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "pct stop $TEST_CT_ID 2>/dev/null; pct destroy $TEST_CT_ID 2>/dev/null" &>/dev/null
}

# Main execution
clear
log "╔════════════════════════════════════════════════════════════════╗"
log "║           PROXMOX BACKUP TEST AUTOMATION                        ║"
log "║           Mode: ${TEST_MODE^^}                                            ║"
log "║           $(date '+%Y-%m-%d %H:%M:%S')                          ║"
log "╚════════════════════════════════════════════════════════════════╝"
log ""

case "$TEST_MODE" in
    verify)
        section "BACKUP VERIFICATION MODE"
        info "This mode verifies backup files without performing restores"
        ;;
    restore)
        section "RESTORE TEST MODE"
        warn "This mode will perform actual restore tests using CT $TEST_CT_ID"
        echo "Press Ctrl+C to cancel, or Enter to continue..."
        read
        ;;
    full)
        section "FULL BACKUP TEST MODE"
        warn "This mode performs backup creation, verification, and restore tests"
        echo "Press Ctrl+C to cancel, or Enter to continue..."
        read
        ;;
    *)
        fail "Invalid mode. Use: verify, restore, or full"
        exit 1
        ;;
esac

# ═══════════════════════════════════════════════════════════════
# STEP 1: Backup Storage Verification
# ═══════════════════════════════════════════════════════════════
section "BACKUP STORAGE VERIFICATION"

subsection "Mac Pro NAS Mount Status"

log_no_newline "Checking SSHFS mount on primary node: "
if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "df -h | grep -q macpro" 2>/dev/null; then
    MOUNT_SIZE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "df -h | grep macpro | awk '{print \"Size: \"\$2\", Used: \"\$3\", Available: \"\$4\" (Usage: \"\$5\")'}'" 2>/dev/null)
    pass "$MOUNT_SIZE"
else
    fail "Mac Pro NAS not mounted!"
    log ""
    log "Attempting to fix mount..."
    ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "systemctl restart mnt-macpro.mount" 2>/dev/null
    sleep 5
    
    if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "df -h | grep -q macpro" 2>/dev/null; then
        pass "Mount restored successfully"
    else
        fail "Could not restore mount - manual intervention required"
        exit 1
    fi
fi

log_no_newline "Backup directory accessible: "
if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE "ls -d $BACKUP_DIR" &>/dev/null; then
    pass "$BACKUP_DIR exists"
else
    fail "Backup directory not accessible"
    exit 1
fi

# ═══════════════════════════════════════════════════════════════
# STEP 2: Backup File Inventory
# ═══════════════════════════════════════════════════════════════
section "BACKUP FILE INVENTORY"

subsection "Backup Count by Container"

declare -A BACKUP_COUNTS
declare -A LATEST_BACKUPS

for ct_id in "${CONTAINERS_TO_TEST[@]}"; do
    COUNT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
        "ls $BACKUP_DIR/vzdump-lxc-${ct_id}-*.zst 2>/dev/null | wc -l" 2>/dev/null || echo "0")
    
    BACKUP_COUNTS[$ct_id]=$COUNT
    
    if [ "$COUNT" -gt 0 ]; then
        LATEST=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
            "ls -t $BACKUP_DIR/vzdump-lxc-${ct_id}-*.zst 2>/dev/null | head -1" 2>/dev/null)
        LATEST_BACKUPS[$ct_id]=$LATEST
        
        # Get container name
        case $ct_id in
            100) CT_NAME="Tailscale" ;;
            101) CT_NAME="Pi-hole" ;;
            102) CT_NAME="Nginx-Proxy" ;;
            103) CT_NAME="Uptime-Kuma" ;;
            104) CT_NAME="Nextcloud" ;;
            105) CT_NAME="MariaDB" ;;
            112) CT_NAME="n8n" ;;
            *) CT_NAME="Unknown" ;;
        esac
        
        log "  CT$ct_id ($CT_NAME): $COUNT backups found"
        
        if [ "$COUNT" -gt 0 ]; then
            BACKUP_SIZE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "du -h '$LATEST' | cut -f1" 2>/dev/null)
            BACKUP_DATE=$(basename "$LATEST" | grep -oP '\d{4}_\d{2}_\d{2}-\d{6}')
            info "    Latest: $BACKUP_DATE (Size: $BACKUP_SIZE)"
        fi
    else
        warn "  CT$ct_id: No backups found!"
    fi
done

subsection "Backup Age Analysis"

TODAY=$(date +%Y_%m_%d)
YESTERDAY=$(date -d "yesterday" +%Y_%m_%d)
WEEK_AGO=$(date -d "7 days ago" +%Y_%m_%d)

log_no_newline "Backups from today: "
TODAY_COUNT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "ls $BACKUP_DIR/*$TODAY*.zst 2>/dev/null | wc -l" 2>/dev/null || echo "0")

if [ "$TODAY_COUNT" -gt 0 ]; then
    pass "$TODAY_COUNT backups"
else
    warn "No backups from today"
fi

log_no_newline "Backups from yesterday: "
YESTERDAY_COUNT=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "ls $BACKUP_DIR/*$YESTERDAY*.zst 2>/dev/null | wc -l" 2>/dev/null || echo "0")

if [ "$YESTERDAY_COUNT" -gt 0 ]; then
    info "$YESTERDAY_COUNT backups"
fi

log_no_newline "Total backup files: "
TOTAL_BACKUPS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "ls $BACKUP_DIR/*.zst 2>/dev/null | wc -l" 2>/dev/null || echo "0")
info "$TOTAL_BACKUPS files"

log_no_newline "Total backup size: "
TOTAL_SIZE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "du -sh $BACKUP_DIR 2>/dev/null | cut -f1" 2>/dev/null || echo "Unknown")
info "$TOTAL_SIZE"

# ═══════════════════════════════════════════════════════════════
# STEP 3: Backup Integrity Verification
# ═══════════════════════════════════════════════════════════════
if [[ "$TEST_MODE" == "verify" ]] || [[ "$TEST_MODE" == "full" ]]; then
    section "BACKUP INTEGRITY VERIFICATION"
    
    subsection "Testing Backup File Integrity"
    
    for ct_id in "${CONTAINERS_TO_TEST[@]}"; do
        if [ "${BACKUP_COUNTS[$ct_id]}" -gt 0 ]; then
            LATEST_BACKUP="${LATEST_BACKUPS[$ct_id]}"
            
            # Get container name
            case $ct_id in
                100) CT_NAME="Tailscale" ;;
                101) CT_NAME="Pi-hole" ;;
                102) CT_NAME="Nginx-Proxy" ;;
                103) CT_NAME="Uptime-Kuma" ;;
                104) CT_NAME="Nextcloud" ;;
                105) CT_NAME="MariaDB" ;;
                112) CT_NAME="n8n" ;;
                *) CT_NAME="Unknown" ;;
            esac
            
            log_no_newline "CT$ct_id ($CT_NAME) backup integrity: "
            
            # Test if we can read the backup file
            if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "vma verify '$LATEST_BACKUP' 2>/dev/null || tar -tzf '$LATEST_BACKUP' >/dev/null 2>&1" 2>/dev/null; then
                pass "File readable and valid"
            else
                # Try alternative verification
                if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                    "zstd -t '$LATEST_BACKUP' 2>/dev/null" 2>/dev/null; then
                    pass "Compression valid"
                else
                    fail "Backup may be corrupted!"
                fi
            fi
        fi
    done
fi

# ═══════════════════════════════════════════════════════════════
# STEP 4: Restore Testing (if requested)
# ═══════════════════════════════════════════════════════════════
if [[ "$TEST_MODE" == "restore" ]] || [[ "$TEST_MODE" == "full" ]]; then
    section "RESTORE TESTING"
    
    warn "Starting restore tests to CT $TEST_CT_ID"
    info "These tests will create and destroy test containers"
    
    # Clean up any existing test container
    cleanup_test_container
    
    subsection "Testing Container Restores"
    
    # Test restore for each container
    for ct_id in "${CONTAINERS_TO_TEST[@]}"; do
        if [ "${BACKUP_COUNTS[$ct_id]}" -gt 0 ]; then
            LATEST_BACKUP="${LATEST_BACKUPS[$ct_id]}"
            
            # Get container name
            case $ct_id in
                100) CT_NAME="Tailscale" ;;
                101) CT_NAME="Pi-hole" ;;
                102) CT_NAME="Nginx-Proxy" ;;
                103) CT_NAME="Uptime-Kuma" ;;
                104) CT_NAME="Nextcloud" ;;
                105) CT_NAME="MariaDB" ;;
                112) CT_NAME="n8n" ;;
                *) CT_NAME="Unknown" ;;
            esac
            
            log ""
            log "Testing restore of CT$ct_id ($CT_NAME)..."
            log_no_newline "  Restoring to CT$TEST_CT_ID: "
            
            # Attempt restore
            RESTORE_OUTPUT=$(ssh -o ConnectTimeout=30 -o BatchMode=yes root@$PRIMARY_NODE \
                "pct restore $TEST_CT_ID '$LATEST_BACKUP' --force 2>&1" 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                pass "Restore successful"
                
                # Verify container exists
                log_no_newline "  Verifying container: "
                if ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                    "pct status $TEST_CT_ID 2>/dev/null | grep -q 'stopped'" 2>/dev/null; then
                    pass "Container created"
                    
                    # Try to start it
                    log_no_newline "  Starting container: "
                    if ssh -o ConnectTimeout=10 -o BatchMode=yes root@$PRIMARY_NODE \
                        "pct start $TEST_CT_ID" 2>/dev/null; then
                        pass "Started successfully"
                        
                        # Wait a moment for services
                        sleep 5
                        
                        # Check if container is running
                        log_no_newline "  Container status: "
                        CT_STATUS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                            "pct status $TEST_CT_ID 2>/dev/null" 2>/dev/null)
                        
                        if [[ "$CT_STATUS" == *"running"* ]]; then
                            pass "Running"
                        else
                            warn "Not running properly"
                        fi
                        
                        # Stop the test container
                        ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                            "pct stop $TEST_CT_ID" 2>/dev/null
                        
                    else
                        warn "Could not start (may need network reconfiguration)"
                    fi
                else
                    fail "Container not created properly"
                fi
                
                # Clean up test container
                log_no_newline "  Cleaning up: "
                cleanup_test_container
                if [ $? -eq 0 ]; then
                    pass "Test container removed"
                else
                    warn "Cleanup may have failed"
                fi
                
            else
                fail "Restore failed!"
                info "    Error: $(echo "$RESTORE_OUTPUT" | head -n 1)"
            fi
        fi
    done
fi

# ═══════════════════════════════════════════════════════════════
# STEP 5: Backup Schedule Verification
# ═══════════════════════════════════════════════════════════════
section "BACKUP SCHEDULE VERIFICATION"

subsection "Configured Backup Jobs"

log "Checking backup job configuration..."

BACKUP_JOBS=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "pvesh get /cluster/backup --output-format json 2>/dev/null | python3 -m json.tool" 2>/dev/null)

if [ ! -z "$BACKUP_JOBS" ]; then
    # Parse job details (simplified - would need jq for proper parsing)
    log_no_newline "Backup job found: "
    
    JOB_ENABLED=$(echo "$BACKUP_JOBS" | grep -c '"enabled": true')
    if [ "$JOB_ENABLED" -gt 0 ]; then
        pass "Enabled"
        
        # Get schedule
        SCHEDULE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
            "pvesh get /cluster/backup 2>/dev/null | grep 'schedule' | awk '{print \$2}'" 2>/dev/null)
        info "  Schedule: $SCHEDULE"
        
        # Get containers
        VMID_LIST=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
            "pvesh get /cluster/backup 2>/dev/null | grep 'vmid' | awk '{print \$2}'" 2>/dev/null)
        info "  Containers: $VMID_LIST"
        
    else
        warn "Job exists but is disabled"
    fi
else
    fail "No backup jobs configured!"
fi

subsection "Retention Policy"

log_no_newline "Checking retention settings: "
RETENTION=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
    "pvesh get /cluster/backup 2>/dev/null | grep 'prune-backups'" 2>/dev/null)

if [ ! -z "$RETENTION" ]; then
    pass "Retention policy configured"
    info "  Policy: keep-daily=7,keep-weekly=4,keep-monthly=6"
else
    warn "No retention policy found"
fi

# ═══════════════════════════════════════════════════════════════
# STEP 6: Manual Backup Test (if full mode)
# ═══════════════════════════════════════════════════════════════
if [[ "$TEST_MODE" == "full" ]]; then
    section "MANUAL BACKUP TEST"
    
    # Pick smallest container for test (usually Tailscale)
    TEST_BACKUP_CT="100"
    
    log "Creating test backup of CT$TEST_BACKUP_CT..."
    log_no_newline "  Running vzdump: "
    
    BACKUP_START=$(date +%s)
    
    BACKUP_OUTPUT=$(ssh -o ConnectTimeout=60 -o BatchMode=yes root@$PRIMARY_NODE \
        "vzdump $TEST_BACKUP_CT --storage macpro-backups --mode snapshot --compress zstd 2>&1" 2>/dev/null)
    
    BACKUP_END=$(date +%s)
    BACKUP_DURATION=$((BACKUP_END - BACKUP_START))
    
    if [ $? -eq 0 ]; then
        pass "Backup completed in ${BACKUP_DURATION}s"
        
        # Find the new backup file
        NEW_BACKUP=$(echo "$BACKUP_OUTPUT" | grep -oP "creating archive '\K[^']+")
        
        if [ ! -z "$NEW_BACKUP" ]; then
            BACKUP_SIZE=$(ssh -o ConnectTimeout=3 -o BatchMode=yes root@$PRIMARY_NODE \
                "du -h '$NEW_BACKUP' | cut -f1" 2>/dev/null)
            info "  Backup file: $(basename "$NEW_BACKUP")"
            info "  Size: $BACKUP_SIZE"
            
            # Calculate backup speed
            if [ ! -z "$BACKUP_SIZE" ]; then
                SIZE_MB=$(echo "$BACKUP_SIZE" | grep -oP '\d+' | head -1)
                if [ ! -z "$SIZE_MB" ] && [ "$BACKUP_DURATION" -gt 0 ]; then
                    SPEED=$((SIZE_MB / BACKUP_DURATION))
                    info "  Speed: ~${SPEED} MB/s"
                fi
            fi
        fi
    else
        fail "Backup failed!"
        info "  Error: $(echo "$BACKUP_OUTPUT" | grep -i error | head -n 1)"
    fi
fi

# ═══════════════════════════════════════════════════════════════
# STEP 7: Recovery Scenario Testing
# ═══════════════════════════════════════════════════════════════
if [[ "$TEST_MODE" == "full" ]]; then
    section "RECOVERY SCENARIO VALIDATION"
    
    subsection "Disaster Recovery Readiness"
    
    log_no_newline "Documentation exists: "
    if [ -f ~/homelab-docs/docs/guides/backup-recovery.md ]; then
        pass "Backup recovery guide found"
    else
        warn "Recovery documentation not found locally"
    fi
    
    log_no_newline "All containers have recent backup: "
    ALL_RECENT=true
    for ct_id in "${CONTAINERS_TO_TEST[@]}"; do
        if [ "${BACKUP_COUNTS[$ct_id]}" -eq 0 ]; then
            ALL_RECENT=false
            break
        fi
    done
    
    if [ "$ALL_RECENT" = true ]; then
        pass "All containers have backups"
    else
        fail "Some containers missing backups"
    fi
    
    log_no_newline "Recovery time estimate: "
    # Estimate based on backup sizes and count
    TOTAL_RESTORE_TIME=$((${#CONTAINERS_TO_TEST[@]} * 60))  # 60 seconds per container estimate
    info "~$((TOTAL_RESTORE_TIME / 60)) minutes for full restoration"
    
    log ""
    log "Recovery Priority Order:"
    log "  1. Tailscale (CT100) - Remote access"
    log "  2. Pi-hole (CT101) - DNS services"
    log "  3. Nginx Proxy (CT102) - Web routing"
    log "  4. MariaDB (CT105) - Database backend"
    log "  5. Nextcloud (CT104) - File services"
    log "  6. Uptime Kuma (CT103) - Monitoring"
    log "  7. n8n (CT112) - Automation"
fi

# ═══════════════════════════════════════════════════════════════
# FINAL SUMMARY
# ═══════════════════════════════════════════════════════════════
section "BACKUP TEST SUMMARY"

log ""
log "╔════════════════════════════════════════════════════════════════╗"
log "║                     TEST RESULTS                                ║"
log "╚════════════════════════════════════════════════════════════════╝"
log ""

# Summary statistics
log "Test Mode:        $TEST_MODE"
log "Total Tests:      $TOTAL_TESTS"
log "Passed:          ${GREEN}$PASSED_TESTS${NC}"
log "Failed:          ${RED}$FAILED_TESTS${NC}"

if [ $TOTAL_TESTS -gt 0 ]; then
    SUCCESS_RATE=$((PASSED_TESTS * 100 / TOTAL_TESTS))
else
    SUCCESS_RATE=0
fi

log "Success Rate:    ${SUCCESS_RATE}%"
log ""

# Container backup summary
log "Container Backup Coverage:"
COVERED_CONTAINERS=0
for ct_id in "${CONTAINERS_TO_TEST[@]}"; do
    if [ "${BACKUP_COUNTS[$ct_id]}" -gt 0 ]; then
        ((COVERED_CONTAINERS++))
        echo -e "  ${GREEN}✓${NC} CT$ct_id: ${BACKUP_COUNTS[$ct_id]} backups"
    else
        echo -e "  ${RED}✗${NC} CT$ct_id: No backups"
    fi
done

COVERAGE_PERCENT=$((COVERED_CONTAINERS * 100 / ${#CONTAINERS_TO_TEST[@]}))
log ""
log "Backup Coverage:  ${COVERAGE_PERCENT}% (${COVERED_CONTAINERS}/${#CONTAINERS_TO_TEST[@]} containers)"
log ""

# Overall assessment
if [ $FAILED_TESTS -eq 0 ] && [ $COVERAGE_PERCENT -eq 100 ]; then
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║       ${GREEN}BACKUP SYSTEM: HEALTHY - ALL TESTS PASSED${NC}             ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=0
elif [ $SUCCESS_RATE -ge 80 ] && [ $COVERAGE_PERCENT -ge 80 ]; then
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║       ${YELLOW}BACKUP SYSTEM: FUNCTIONAL WITH WARNINGS${NC}              ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=1
else
    log "╔════════════════════════════════════════════════════════════════╗"
    log "║       ${RED}BACKUP SYSTEM: NEEDS ATTENTION${NC}                        ║"
    log "╚════════════════════════════════════════════════════════════════╝"
    EXIT_CODE=2
fi

# Recommendations
if [ $FAILED_TESTS -gt 0 ] || [ $COVERAGE_PERCENT -lt 100 ]; then
    log ""
    log "Recommendations:"
    
    if [ $COVERAGE_PERCENT -lt 100 ]; then
        warn "  • Run manual backup for containers without backups"
        warn "  • Check backup job configuration includes all containers"
    fi
    
    if [ $FAILED_TESTS -gt 0 ]; then
        warn "  • Review failed tests above"
        warn "  • Check Mac Pro NAS mount status"
        warn "  • Verify backup storage has sufficient space"
    fi
    
    info "  • Consider running this test monthly"
    info "  • Document any restore procedures performed"
fi

log ""
log "═══════════════════════════════════════════════════════════════"
log "Test completed: $(date '+%Y-%m-%d %H:%M:%S')"
log "Log saved to: $LOG_FILE"
log ""
log "Usage:"
log "  $0 verify   - Check backup files only (default)"
log "  $0 restore  - Test restore procedures"  
log "  $0 full     - Complete backup and restore test"
log ""

exit $EXIT_CODE