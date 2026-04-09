#!/bin/bash
# Cluster-aware UPS shutdown script with power-return detection
# Called by NUT (upsmon SHUTDOWNCMD) when battery is critical
#
# Features:
#   - Checks if power returned before each container stop (aborts if so)
#   - Bounded timeouts on container stops (no more infinite hangs)
#   - Restarts stopped containers and clears NUT FSD on abort
#   - Concurrency lock prevents double invocation
#   - Dry-run mode for safe testing
#
# Usage:
#   /usr/local/bin/cluster-shutdown.sh              # Normal (called by NUT)
#   /usr/local/bin/cluster-shutdown.sh --dry-run     # Test mode (no real actions)
#   UPS_STATUS_CMD="echo OL" ./cluster-shutdown.sh --dry-run  # Mock UPS status
#
# Location: /usr/local/bin/cluster-shutdown.sh (pve1 only)
# Deployed from: homelab-proxmox-cluster/scripts/ups/cluster-shutdown.sh

set -euo pipefail

# --- Configuration ---
UPS_STATUS_CMD="${UPS_STATUS_CMD:-timeout 5 upsc cyberpower@localhost ups.status}"
LOCK_FILE="/run/cluster-shutdown.lock"
LOG_FILE="/var/log/ups-shutdown.log"
ALERT_FILE="/run/cluster-shutdown-incomplete"
DRY_RUN=false

# Container stop order (reverse dependency: apps first, infrastructure last)
STOP_ORDER=(112 107 106 104 105 103 102 101 100)

# Container start order (forward dependency: infrastructure first, apps last)
START_ORDER=(100 101 105 106 102 103 104 107 112)

# Timeouts (seconds)
GRACEFUL_TIMEOUT=45
FORCE_TIMEOUT=15
POWER_CHECK_SAMPLES=2
POWER_CHECK_INTERVAL=3

# --- Parse arguments ---
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN=true
fi

# --- Logging ---
log() {
    local msg="$(date '+%Y-%m-%d %H:%M:%S'): $1"
    echo "$msg" >> "$LOG_FILE"
    logger -t cluster-shutdown "$1"
}

# --- Concurrency lock ---
exec 200>"$LOCK_FILE"
if ! flock -n 200; then
    log "Another instance is already running. Exiting."
    exit 0
fi

log "========================================"
log "UPS shutdown initiated (dry_run=$DRY_RUN)"

# --- Track stopped containers ---
declare -a STOPPED_CTS=()

# --- Helper: get UPS status ---
get_ups_status() {
    local status
    status=$($UPS_STATUS_CMD 2>/dev/null) || true
    echo "$status"
}

# --- Helper: check if power is back ---
# Returns 0 (true) if power confirmed back, 1 (false) if still on battery/unknown
# Requires 2 consecutive OL readings 3 seconds apart to filter grid flicker
power_is_back() {
    local pass=0
    local i

    for ((i = 0; i < POWER_CHECK_SAMPLES; i++)); do
        local status
        status=$(get_ups_status)

        # Empty/timeout: assume still on battery (safe default)
        if [[ -z "$status" ]]; then
            log "UPS status check: no response (assuming on battery)"
            return 1
        fi

        # Check: OL must be present, OB and FSD must be absent
        if [[ "$status" == *"OL"* ]] && [[ "$status" != *"OB"* ]] && [[ "$status" != *"FSD"* ]]; then
            pass=$((pass + 1))
            log "UPS status check $((i + 1))/$POWER_CHECK_SAMPLES: '$status' (power appears back)"
        else
            log "UPS status check: '$status' (still on battery/FSD)"
            return 1
        fi

        # Wait between samples (skip after last sample)
        if ((i < POWER_CHECK_SAMPLES - 1)); then
            sleep "$POWER_CHECK_INTERVAL"
        fi
    done

    if ((pass >= POWER_CHECK_SAMPLES)); then
        log "Power confirmed back after $POWER_CHECK_SAMPLES consecutive checks"
        return 0
    fi

    return 1
}

# --- Helper: run or log command based on dry-run mode ---
run_cmd() {
    if $DRY_RUN; then
        log "[DRY-RUN] Would execute: $*"
    else
        "$@"
    fi
}

# --- Abort cleanup: undo shutdown and restore services ---
abort_cleanup() {
    log "ABORT: Power returned. Starting cleanup..."
    local cleanup_ok=true

    # Step 1: Clear NUT FSD state (driver + monitor only, keep nut-server alive for slaves)
    log "Clearing NUT FSD state..."
    if ! run_cmd systemctl restart nut-driver@cyberpower.service; then
        log "WARNING: Failed to restart nut-driver"
        cleanup_ok=false
    fi
    run_cmd sleep 3
    if ! run_cmd systemctl restart nut-monitor.service; then
        log "WARNING: Failed to restart nut-monitor"
        cleanup_ok=false
    fi

    # Step 2: Remove killpower flag
    log "Removing killpower flag..."
    run_cmd rm -f /etc/killpower

    # Step 3: Restart stopped containers in dependency order
    if [[ ${#STOPPED_CTS[@]} -gt 0 ]]; then
        log "Restarting ${#STOPPED_CTS[@]} stopped container(s)..."
        for ct in "${START_ORDER[@]}"; do
            # Only restart containers we actually stopped
            local was_stopped=false
            for stopped in "${STOPPED_CTS[@]}"; do
                if [[ "$stopped" == "$ct" ]]; then
                    was_stopped=true
                    break
                fi
            done

            if $was_stopped; then
                log "Starting CT$ct..."
                if ! run_cmd pct start "$ct"; then
                    log "WARNING: Failed to start CT$ct"
                    cleanup_ok=false
                else
                    # Brief pause for container to initialize
                    run_cmd sleep 2
                fi
            fi
        done
    else
        log "No containers were stopped, nothing to restart"
    fi

    # Step 4: Unset Ceph flags only if cleanup succeeded so far
    if $cleanup_ok; then
        log "Unsetting Ceph maintenance flags..."
        run_cmd ceph osd unset noout
        run_cmd ceph osd unset nobackfill
        run_cmd ceph osd unset norebalance
        log "Ceph flags cleared"
    else
        log "WARNING: Cleanup had failures, leaving Ceph flags set for safety"
        log "WARNING: Manual intervention needed. Run: ceph osd unset noout && ceph osd unset nobackfill && ceph osd unset norebalance"
        run_cmd touch "$ALERT_FILE"
    fi

    log "Abort cleanup complete (success=$cleanup_ok)"
    exit 0
}

# --- Main shutdown sequence ---

# Step 1: Set Ceph maintenance flags
log "Setting Ceph maintenance flags..."
run_cmd ceph osd set noout
run_cmd ceph osd set nobackfill
run_cmd ceph osd set norebalance
log "Ceph flags set"

# Step 2: Stop containers with power checks between each
log "Stopping containers..."
for ct in "${STOP_ORDER[@]}"; do
    # Check if power returned before stopping this container
    if power_is_back; then
        abort_cleanup
    fi

    # Check if container is running
    if ! pct status "$ct" 2>/dev/null | grep -q running; then
        log "CT$ct already stopped, skipping"
        continue
    fi

    log "Stopping CT$ct (graceful ${GRACEFUL_TIMEOUT}s, force ${FORCE_TIMEOUT}s)..."
    if run_cmd timeout "$GRACEFUL_TIMEOUT" pct shutdown "$ct" --timeout "$GRACEFUL_TIMEOUT" 2>/dev/null; then
        log "CT$ct stopped gracefully"
    else
        log "CT$ct graceful stop timed out, forcing..."
        run_cmd timeout "$FORCE_TIMEOUT" pct stop "$ct" 2>/dev/null || log "CT$ct force stop also timed out"
    fi
    STOPPED_CTS+=("$ct")
done
log "All containers stopped"

# Step 3: Final power check before shutdown
if power_is_back; then
    abort_cleanup
fi

# Step 4: Unmount backup storage if present
if mountpoint -q /mnt/backup-storage 2>/dev/null; then
    log "Unmounting backup storage..."
    run_cmd umount /mnt/backup-storage 2>/dev/null || log "Backup storage unmount failed (non-critical)"
fi

# Step 5: Shutdown
log "All checks complete. Initiating system shutdown."
run_cmd /sbin/shutdown -h +0
