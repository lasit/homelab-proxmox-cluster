#!/bin/bash
# NUT FSD boot-time recovery script (master node - pve1)
#
# Runs at boot AFTER nut-server but BEFORE nut-monitor.
# If /etc/killpower exists and UPS is online (power returned),
# clears the stale FSD state so nut-monitor does not re-trigger shutdown.
#
# Location: /usr/local/bin/nut-fsd-recovery.sh (pve1)
# Deployed from: homelab-proxmox-cluster/scripts/ups/nut-fsd-recovery-master.sh

set -euo pipefail

UPS_NAME="cyberpower@localhost"
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

log "Found $KILLPOWER. Checking if power has returned..."

# Wait for NUT driver+server to be ready
ups_status=""
for ((i = 1; i <= MAX_RETRIES; i++)); do
    ups_status=$(timeout 5 upsc "$UPS_NAME" ups.status 2>/dev/null) || true

    if [[ -n "$ups_status" ]]; then
        log "NUT responding (attempt $i/$MAX_RETRIES): status='$ups_status'"
        break
    fi

    log "NUT not ready yet (attempt $i/$MAX_RETRIES), waiting ${RETRY_INTERVAL}s..."
    sleep "$RETRY_INTERVAL"
done

# Check UPS status
if [[ -z "$ups_status" ]]; then
    log "WARNING: NUT did not respond after $MAX_RETRIES attempts ($((MAX_RETRIES * RETRY_INTERVAL))s)"
    log "Removing killpower anyway (machine booted = power returned)"
    rm -f "$KILLPOWER"
    exit 0
fi

# Power is back if OL present, OB and FSD absent
if [[ "$ups_status" == *"OL"* ]] && [[ "$ups_status" != *"OB"* ]] && [[ "$ups_status" != *"FSD"* ]]; then
    log "UPS is online ('$ups_status'). Power has returned."
    log "Removing killpower flag..."
    rm -f "$KILLPOWER"

    log "Restarting NUT driver to clear hardware FSD state..."
    systemctl restart nut-driver@cyberpower.service || log "WARNING: Failed to restart nut-driver"
    sleep 3

    # Note: nut-monitor has not started yet (systemd ordering ensures this)
    # When it starts, it will see clean OL status from the driver
    log "FSD recovery complete. nut-monitor will start with clean state."
else
    log "UPS status is '$ups_status' (not online). Keeping killpower flag."
    log "This node will proceed with shutdown when nut-monitor starts."
fi

exit 0
