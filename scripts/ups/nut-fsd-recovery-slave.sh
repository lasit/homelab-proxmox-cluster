#!/bin/bash
# NUT FSD boot-time recovery script (slave nodes - pve2/pve3)
#
# Runs at boot AFTER nut-server (if any) but BEFORE nut-monitor.
# If /etc/killpower exists and the NUT master reports UPS online,
# clears the stale killpower flag so nut-monitor does not re-trigger shutdown.
#
# If the master is unreachable after 60 seconds, removes killpower anyway
# because the machine booting proves power returned.
#
# Location: /usr/local/bin/nut-fsd-recovery.sh (pve2, pve3)
# Deployed from: homelab-proxmox-cluster/scripts/ups/nut-fsd-recovery-slave.sh

set -euo pipefail

UPS_NAME="cyberpower@192.168.10.11"
KILLPOWER="/etc/killpower"
MAX_RETRIES=12
RETRY_INTERVAL=5

log() {
    logger -t nut-fsd-recovery "$1"
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1"
}

# Exit early if no killpower flag
if [[ ! -f "$KILLPOWER" ]]; then
    log "No killpower flag found. Nothing to do."
    exit 0
fi

log "Found $KILLPOWER. Checking NUT master for UPS status..."

# Query the master with retries (master may still be booting)
ups_status=""
for ((i = 1; i <= MAX_RETRIES; i++)); do
    ups_status=$(timeout 5 upsc "$UPS_NAME" ups.status 2>/dev/null) || true

    if [[ -n "$ups_status" ]]; then
        log "Master responding (attempt $i/$MAX_RETRIES): status='$ups_status'"
        break
    fi

    log "Master not reachable yet (attempt $i/$MAX_RETRIES), waiting ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

# If master never responded
if [[ -z "$ups_status" ]]; then
    log "Master did not respond after $MAX_RETRIES attempts ($((MAX_RETRIES * RETRY_INTERVAL))s)"
    log "This machine booted, so power has returned. Removing killpower."
    rm -f "$KILLPOWER"
    exit 0
fi

# Power is back if OL present, OB and FSD absent
if [[ "$ups_status" == *"OL"* ]] && [[ "$ups_status" != *"OB"* ]] && [[ "$ups_status" != *"FSD"* ]]; then
    log "UPS is online ('$ups_status'). Power has returned."
    log "Removing killpower flag..."
    rm -f "$KILLPOWER"
    log "FSD recovery complete. nut-monitor will start with clean state."
else
    log "UPS status is '$ups_status' (not online). Keeping killpower flag."
    log "This node will proceed with shutdown when nut-monitor starts."
fi

exit 0
