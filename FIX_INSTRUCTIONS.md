# VPS GUI NoVNC - POP OS Fix Instructions

## Problem You Experienced

Service `vps-gui` failed to start with error: `exit code 127 (command not found)`

## Root Cause

1. Service file had broken syntax for inline bash commands
2. check.sh was hardcoded for display :1 instead of auto-detecting :0
3. X socket permissions not properly handled for existing display

## Fixes Applied to Scripts

✅ check.sh - Now auto-detects display mode
✅ auto-install.sh - Now uses wrapper scripts instead of inline bash
✅ Wrapper scripts include X socket permission handling
✅ Service files improved with better dependencies

## What You Need to Do Now

### Step 1: Re-run the Installation

```bash
cd ~/vps-gui-noVnc
sudo bash auto-install.sh adens yes
```

This will:

- Detect your display mode (:0 on POP OS)
- Create wrapper scripts at `/usr/local/bin/`
- Create new service file with proper syntax
- Reload systemd
- Start the vps-gui service
- Verify everything works

### Step 2: Verify the Fix

```bash
sudo bash check.sh adens
```

Expected results:

- ✅ vps-gui service is RUNNING
- ✅ x11vnc (VNC Server) is running
- ✅ Port 6080 (noVNC) is LISTENING
- ✅ Port 5900 (VNC Direct) is LISTENING
- ✅ X Server (:0) is responding

### Step 3: Access Your Desktop

- Browser: `http://localhost:6080`
- VNC Direct: `vnc://localhost:5900`
- Server IP: Check output of auto-install.sh

## If Issues Persist

### View Service Logs

```bash
sudo journalctl -u vps-gui -n 50 -f
```

### Check Service Status

```bash
sudo systemctl status vps-gui
```

### Manual Service Restart

```bash
sudo systemctl restart vps-gui
sleep 3
sudo systemctl status vps-gui
```

### View Service File

```bash
cat /etc/systemd/system/vps-gui.service
```

### Check Wrapper Script

```bash
cat /usr/local/bin/vps-gui-wrapper-existing
```

## Technical Changes Made

### check.sh

- Added display mode auto-detection (lines 50-64)
- Detects Xorg/Wayland to identify existing display
- Sets DISPLAY_NUM=":0" for POP OS
- Conditional process checks based on mode
- Display info now shown in output

### auto-install.sh

- Created wrapper scripts (lines 301-365):
  - `vps-gui-wrapper-existing` - For display :0 with xhost permissions
  - `vps-gui-wrapper-virtual` - For display :1 with Xvfb/XFCE
- Simplified service files (lines 369-428):
  - Reference wrapper scripts instead of inline bash
  - Use multi-user.target for better compatibility
  - Added journal logging for debugging
  - Proper group/user permissions

## Timeline

- ✅ Code changes: Complete
- ✅ Syntax validation: Passed
- ⏳ User action: Re-run installation
- ⏳ Verification: Check service status

---

**Support:** If you encounter any issues during the fix, run the commands in "If Issues Persist" section and share the output.
