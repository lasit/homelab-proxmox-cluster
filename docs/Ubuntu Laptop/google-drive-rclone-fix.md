# Google Drive on Ubuntu: GVFS Issue and rclone Fix

**Date:** 2025-12-04  
**System:** Ubuntu (GNOME Desktop)  
**Issue:** Cannot download files directly to Google Drive or open files from it  

## Problem Description

When using Google Drive through GNOME Online Accounts (Settings → Online Accounts → Google), the following issues occur:

- **Downloads fail** - Browser downloads directly to Google Drive folder fail with "check internet connection" error
- **Opening files fails** - Cannot open files (CSV, documents, etc.) directly from Google Drive
- **Copy works** - Copying files from local storage TO Google Drive works fine

### Root Cause

GNOME Online Accounts creates a **virtual mount** using GVFS (GNOME Virtual File System). This is not a real local folder - it streams files on-demand from Google's servers.

The issues occur because:
1. Browsers try to write directly to a GVFS path, which many applications don't understand
2. Applications expect local files, not streamed virtual ones
3. GVFS handles reads differently than writes

## Solution: rclone with FUSE Mount

Replace the GVFS virtual mount with rclone, which provides a proper FUSE filesystem with local caching.

### Prerequisites

```bash
sudo apt install rclone
```

### Step 1: Configure rclone

```bash
rclone config
```

Follow the prompts:
1. `n` - New remote
2. Name: `gdrive`
3. Storage type: `18` (Google Drive)
4. client_id: Press Enter for default (or create your own at https://rclone.org/drive/#making-your-own-client-id)
5. client_secret: Press Enter for default
6. scope: `1` (Full access all files)
7. service_account_file: Press Enter (leave empty)
8. Edit advanced config: `n`
9. Use auto config: `y`
10. Browser opens - authorize rclone with your Google account
11. Configure as Shared Drive: `n`
12. Confirm: `y`
13. Quit: `q`

### Step 2: Create Mount Point and Test

```bash
# Create mount point
mkdir -p ~/GoogleDrive

# Test connection
rclone ls gdrive: --max-depth 1

# Manual mount (for testing)
rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full --daemon
```

The `--vfs-cache-mode full` flag is critical - it caches files locally, which fixes download and file-opening issues.

### Step 3: Create Systemd Service (Persistent Mount)

Create the service file:

```bash
mkdir -p ~/.config/systemd/user

cat << 'EOF' > ~/.config/systemd/user/rclone-gdrive.service
[Unit]
Description=Google Drive (rclone mount)
After=network-online.target
Wants=network-online.target

[Service]
Type=notify
ExecStart=/usr/bin/rclone mount gdrive: %h/GoogleDrive --vfs-cache-mode full
ExecStop=/bin/fusermount -u %h/GoogleDrive
Restart=on-failure
RestartSec=10

[Install]
WantedBy=default.target
EOF
```

Enable and start the service:

```bash
# Enable service
systemctl --user enable rclone-gdrive.service

# Start service
systemctl --user start rclone-gdrive.service

# Enable user services at boot (before login)
sudo loginctl enable-linger $USER

# Verify
systemctl --user status rclone-gdrive.service
loginctl show-user $USER | grep Linger
```

### Step 4: Disable GNOME Online Accounts Google Drive (Optional)

To avoid having two Google Drive locations:

1. Open **Settings** → **Online Accounts**
2. Click your Google account
3. Toggle off **Files** (keep Calendar, Contacts if desired)

## Troubleshooting

### Mount Already Exists Error

If you see "directory already mounted" errors:

```bash
# Stop service
systemctl --user stop rclone-gdrive.service

# Find what's using the mount
lsof +f -- ~/GoogleDrive 2>/dev/null

# Force lazy unmount
fusermount -uz ~/GoogleDrive

# Restart service
systemctl --user start rclone-gdrive.service
```

### Service Won't Start

Check logs:

```bash
journalctl --user -u rclone-gdrive.service -n 50
```

### Re-authorize Google Account

If authentication expires:

```bash
rclone config reconnect gdrive:
```

## Useful Commands

```bash
# Check mount status
systemctl --user status rclone-gdrive.service

# Restart mount
systemctl --user restart rclone-gdrive.service

# View live logs
journalctl --user -u rclone-gdrive.service -f

# Check disk usage of cache
du -sh ~/.cache/rclone/

# Manual mount (debugging)
rclone mount gdrive: ~/GoogleDrive --vfs-cache-mode full -v
```

## Cache Location

rclone stores its cache at `~/.cache/rclone/`. If disk space becomes an issue, you can limit cache size by adding to the ExecStart line:

```
--vfs-cache-max-size 10G
```

## Configuration File Location

rclone config is stored at `~/.config/rclone/rclone.conf`

## References

- [rclone Google Drive Documentation](https://rclone.org/drive/)
- [rclone Mount Options](https://rclone.org/commands/rclone_mount/)
- [rclone VFS Cache Mode](https://rclone.org/commands/rclone_mount/#vfs-file-caching)