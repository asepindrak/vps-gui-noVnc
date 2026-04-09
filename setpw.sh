#!/bin/bash
#===============================================================================
# 🔐 VNC Password Setup Script
# Set VNC password for non-root user
# Usage: sudo bash setpw.sh [username] [password]
# Example: sudo bash setpw.sh myuser mypassword123
#===============================================================================

set -e

# ============================================================================
# COLOR & FORMATTING
# ============================================================================
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# PARAMETER VALIDATION
# ============================================================================

if [ "$EUID" -ne 0 ]; then
    log_error "Script MUST be run with sudo"
    echo "Usage: sudo bash $0 [username] [password]"
    exit 1
fi

# Get username (from parameter or current sudo user)
TARGET_USER="${1:-$SUDO_USER}"
if [ -z "$TARGET_USER" ]; then
    log_error "Unable to determine username"
    echo "Usage: sudo bash $0 [username] [password]"
    exit 1
fi

# Verify user exists
if ! id "$TARGET_USER" &>/dev/null; then
    log_error "User '$TARGET_USER' does not exist"
    exit 1
fi

USER_HOME="/home/$TARGET_USER"
VNC_DIR="$USER_HOME/.vnc"

if [ ! -d "$VNC_DIR" ]; then
    log_error "VNC directory not found: $VNC_DIR"
    log_info "Perhaps auto-install.sh has not been run yet?"
    exit 1
fi

log_section "🔐 VNC Password Setup"

# ============================================================================
# STEP 1: STOP SERVICE
# ============================================================================

log_info "Stopping vps-gui service..."
sudo systemctl stop vps-gui || true
sleep 2

# ============================================================================
# STEP 2: GET PASSWORD
# ============================================================================

PASSWORD="${2:-}"

if [ -z "$PASSWORD" ]; then
    log_info "Enter VNC Password (will be hidden):"
    read -s -r PASSWORD
    echo ""
    
    log_info "Confirm Password (will be hidden):"
    read -s -r PASSWORD_CONFIRM
    echo ""
    
    if [ "$PASSWORD" != "$PASSWORD_CONFIRM" ]; then
        log_error "Passwords do not match!"
        exit 1
    fi
fi

# ============================================================================
# STEP 3: GENERATE PASSWORD FILE
# ============================================================================

log_info "Generating VNC password file..."

if sudo -u "$TARGET_USER" x11vnc -storepasswd "$PASSWORD" "$VNC_DIR/passwd" 2>/dev/null; then
    chmod 600 "$VNC_DIR/passwd"
    chown "$TARGET_USER:$TARGET_USER" "$VNC_DIR/passwd"
    log_success "Password file created: $VNC_DIR/passwd"
else
    log_error "Failed to generate password file"
    exit 1
fi

# ============================================================================
# STEP 4: VERIFY PASSWORD FILE
# ============================================================================

FILE_SIZE=$(stat -c "%s" "$VNC_DIR/passwd" 2>/dev/null || stat -f "%z" "$VNC_DIR/passwd" 2>/dev/null || echo "0")

if [ "$FILE_SIZE" -gt 0 ]; then
    log_success "Password file verified (size: $FILE_SIZE bytes)"
else
    log_error "Password file verification failed"
    exit 1
fi

# ============================================================================
# STEP 5: UPDATE SYSTEMD SERVICE
# ============================================================================

log_info "Updating systemd service configuration..."
SERVICE_FILE="/etc/systemd/system/vps-gui.service"

if grep -q "\-nopw" "$SERVICE_FILE"; then
    # Replace -nopw with -rfbauth
    sed -i "s|-nopw|-rfbauth $VNC_DIR/passwd|g" "$SERVICE_FILE"
    log_success "Service updated to use password authentication"
else
    log_info "Service already configured for password (or already has -rfbauth)"
fi

# ============================================================================
# STEP 6: RELOAD & RESTART SERVICE
# ============================================================================

log_info "Reloading systemd..."
systemctl daemon-reload

log_info "Starting vps-gui service..."
systemctl start vps-gui

sleep 5

# ============================================================================
# STEP 7: VERIFY
# ============================================================================

log_info "Verifying service status..."
if systemctl is-active --quiet vps-gui; then
    log_success "Service is running!"
else
    log_error "Service failed to start"
    systemctl status vps-gui --no-pager || true
    exit 1
fi

# ============================================================================
# FINAL SUMMARY
# ============================================================================

log_section "✅ PASSWORD SETUP COMPLETE!"

echo -e "${GREEN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ VNC Password successfully set!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📋 Password Information:${NC}"
echo "  User        : $TARGET_USER"
echo "  Password    : ••••••••• (hidden)"
echo "  Config File : $VNC_DIR/passwd"
echo ""
echo -e "${CYAN}🌐 How to Use:${NC}"
echo "  1. Open: http://YOUR_IP:6080"
echo "  2. Click 'Connect'"
echo "  3. Enter password at prompt (if requested)"
echo ""
echo -e "${CYAN}🔄 Troubleshooting:${NC}"
echo "  # Check service"
echo "  sudo systemctl status vps-gui"
echo ""
echo "  # View logs"
echo "  sudo journalctl -u vps-gui -n 50"
echo ""
echo "  # Restart service"
echo "  sudo systemctl restart vps-gui"
echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${YELLOW}💡 TIPS:${NC}"
echo "  • Password disimpan dalam format terenkripsi"
echo "  • To reset password, run this script again"
echo "  • To return to no-password mode, edit service:"
echo "    sudo nano /etc/systemd/system/vps-gui.service"
echo "    Change -rfbauth to -nopw"
echo ""
echo -e "${NC}"

