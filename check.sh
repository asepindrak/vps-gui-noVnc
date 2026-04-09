#!/bin/bash
#===============================================================================
# 🔍 VPS GUI System Health Check
# Complete status checker for XFCE + VNC + noVNC + Nginx
# Displays all services, processes, ports, and configuration
#
# Usage: sudo bash check.sh [username]
# Example: sudo bash check.sh vpsuser
#===============================================================================

# Warna output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Counters
PASS=0
FAIL=0
WARN=0

# Get username
if [ -n "$1" ]; then
    TARGET_USER="$1"
else
    if [ -n "$SUDO_USER" ] && [ "$SUDO_USER" != "root" ]; then
        DETECTED_USER="$SUDO_USER"
        echo -e "${YELLOW}Detected user: $DETECTED_USER${NC}"
        read -p "Use this user? (y/n) [default: y]: " -t 5 -r
        REPLY=${REPLY:-y}
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            TARGET_USER="$DETECTED_USER"
        fi
    fi
    
    if [ -z "$TARGET_USER" ]; then
        read -p "Enter username to check: " TARGET_USER
    fi
fi

if [ -z "$TARGET_USER" ]; then
    echo -e "${RED}❌ Error: Username must not be empty${NC}"
    echo "Usage: sudo bash check.sh [username]"
    exit 1
fi

USER_HOME="/home/$TARGET_USER"
VNC_DIR="$USER_HOME/.vnc"

# Helper functions
check_pass() {
    echo -e "${GREEN}✅ $1${NC}"
    ((PASS++))
}

check_fail() {
    echo -e "${RED}❌ $1${NC}"
    ((FAIL++))
}

check_warn() {
    echo -e "${YELLOW}⚠️  $1${NC}"
    ((WARN++))
}

section() {
    echo ""
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}${BOLD}  $1${NC}"
    echo -e "${CYAN}${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

section "🔍 VPS GUI System Health Check"
echo "Checking user: ${BLUE}$TARGET_USER${NC}"
echo ""

# ============================================================================
# 1. USER & DIRECTORY CHECK
# ============================================================================

section "1️⃣  USER & DIRECTORY STATUS"

if id "$TARGET_USER" &>/dev/null; then
    check_pass "User '$TARGET_USER' exists"
else
    check_fail "User '$TARGET_USER' not found"
fi

if [ -d "$USER_HOME" ]; then
    check_pass "Home directory exists: $USER_HOME"
else
    check_fail "Home directory missing: $USER_HOME"
fi

if [ -d "$VNC_DIR" ]; then
    check_pass "VNC directory exists: $VNC_DIR"
else
    check_warn "VNC directory missing: $VNC_DIR"
fi

# ============================================================================
# 2. SYSTEMD SERVICES CHECK
# ============================================================================

section "2️⃣  SYSTEMD SERVICES STATUS"

# Check vps-gui service
if systemctl list-unit-files | grep -q "vps-gui.service"; then
    if systemctl is-active --quiet vps-gui; then
        check_pass "vps-gui service is RUNNING"
    else
        check_fail "vps-gui service is STOPPED"
    fi
    
    if systemctl is-enabled vps-gui &>/dev/null; then
        check_pass "vps-gui service is ENABLED (auto-start)"
    else
        check_warn "vps-gui service is DISABLED"
    fi
else
    check_fail "vps-gui service not found"
fi

# Check nginx service
if systemctl list-unit-files | grep -q "nginx.service"; then
    if systemctl is-active --quiet nginx; then
        check_pass "nginx service is RUNNING"
    else
        check_warn "nginx service is STOPPED"
    fi
    
    if systemctl is-enabled nginx &>/dev/null; then
        check_pass "nginx service is ENABLED"
    else
        check_warn "nginx service is DISABLED"
    fi
else
    check_warn "nginx service not installed"
fi

# ============================================================================
# 3. PROCESSES CHECK
# ============================================================================

section "3️⃣  RUNNING PROCESSES STATUS"

# Xvfb
if pgrep -f "Xvfb.*:1" > /dev/null; then
    check_pass "Xvfb (Virtual Display :1) is running"
else
    check_fail "Xvfb is NOT running"
fi

# XFCE
if pgrep -f "startxfce4|xfdesktop" > /dev/null; then
    check_pass "XFCE is running"
else
    check_fail "XFCE is NOT running"
fi

# x11vnc
if pgrep -f "x11vnc" > /dev/null; then
    check_pass "x11vnc (VNC Server) is running"
else
    check_fail "x11vnc is NOT running"
fi

# websockify
if pgrep -f "websockify" > /dev/null; then
    check_pass "websockify (WebSocket bridge) is running"
else
    check_fail "websockify is NOT running"
fi

# ============================================================================
# 4. PORTS CHECK
# ============================================================================

section "4️⃣  LISTENING PORTS STATUS"

# Port 6080 (noVNC)
if ss -tlnp 2>/dev/null | grep -q ":6080 "; then
    check_pass "Port 6080 (noVNC) is LISTENING"
else
    check_fail "Port 6080 (noVNC) is NOT listening"
fi

# Port 5900 (VNC)
if ss -tlnp 2>/dev/null | grep -q ":5900 "; then
    check_pass "Port 5900 (VNC Direct) is LISTENING"
else
    check_fail "Port 5900 (VNC Direct) is NOT listening"
fi

# Port 6969 (Nginx Proxy)
if ss -tlnp 2>/dev/null | grep -q ":6969 "; then
    check_pass "Port 6969 (Nginx Proxy) is LISTENING"
elif ss -tlnp 2>/dev/null | grep -q ":80 "; then
    check_warn "Port 6969 not listening, but port 80 (HTTP) found"
else
    check_warn "Port 6969 (Nginx Proxy) is NOT listening"
fi

# ============================================================================
# 5. VNC CONFIGURATION
# ============================================================================

section "5️⃣  VNC CONFIGURATION STATUS"

# VNC xstartup
if [ -f "$VNC_DIR/xstartup" ]; then
    check_pass "VNC xstartup script exists"
else
    check_warn "VNC xstartup script missing"
fi

# VNC passwd
if [ -f "$VNC_DIR/passwd" ]; then
    check_pass "VNC password file exists (password protected)"
else
    check_warn "VNC password file not set (no-password mode)"
fi

# ============================================================================
# 6. DISPLAY CHECK
# ============================================================================

section "6️⃣  DISPLAY SERVER STATUS"

if DISPLAY=:1 xdpyinfo &>/dev/null; then
    check_pass "X Server (:1) is responding"
else
    check_fail "X Server (:1) is NOT responding"
fi

# ============================================================================
# 7. NGINX CONFIGURATION
# ============================================================================

section "7️⃣  NGINX CONFIGURATION STATUS"

NGINX_CONFIG="/etc/nginx/sites-available/vps-gui-proxy"
if [ -f "$NGINX_CONFIG" ]; then
    check_pass "Nginx proxy config exists: $NGINX_CONFIG"
    
    if [ -L "/etc/nginx/sites-enabled/vps-gui-proxy" ]; then
        check_pass "Nginx site is ENABLED"
    else
        check_warn "Nginx site is DISABLED (not symlinked)"
    fi
    
    if nginx -t > /dev/null 2>&1; then
        check_pass "Nginx configuration is VALID"
    else
        check_fail "Nginx configuration has ERRORS"
        nginx -t 2>&1 | grep -v "test is successful" || true
    fi
else
    check_warn "Nginx proxy config not found (not configured)"
fi

# ============================================================================
# 8. XFCE CONFIGURATION
# ============================================================================

section "8️⃣  XFCE CONFIGURATION STATUS"

XFCE_CONFIG="$USER_HOME/.config/xfce4"
if [ -d "$XFCE_CONFIG" ]; then
    check_pass "XFCE config directory exists"
    
    if [ -d "$XFCE_CONFIG/autostart" ]; then
        check_pass "XFCE autostart directory exists"
    else
        check_warn "XFCE autostart directory missing"
    fi
else
    check_warn "XFCE config not initialized"
fi

# ============================================================================
# 9. FINAL SUMMARY
# ============================================================================

section "📊 HEALTH CHECK SUMMARY"

echo ""
echo -e "  ${GREEN}✅ PASS: $PASS${NC}"
echo -e "  ${YELLOW}⚠️  WARN: $WARN${NC}"
echo -e "  ${RED}❌ FAIL: $FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    if [ $WARN -eq 0 ]; then
        echo -e "${GREEN}${BOLD}🎉 SYSTEM IS HEALTHY! All checks passed!${NC}"
    else
        echo -e "${YELLOW}${BOLD}⚠️  SYSTEM IS RUNNING with $WARN warning(s)${NC}"
    fi
else
    echo -e "${RED}${BOLD}⚠️  SYSTEM HAS $FAIL ERROR(S) - Please review above${NC}"
fi

echo ""
echo -e "${CYAN}Quick Access:${NC}"
echo "  Browser: http://localhost:6080"
echo "  VNC:     vnc://localhost:5900"
echo ""
echo -e "${CYAN}Useful commands:${NC}"
echo "  sudo systemctl status vps-gui     # Check service status"
echo "  sudo systemctl restart vps-gui    # Restart service"
echo "  sudo journalctl -u vps-gui -f     # View live logs"
echo ""

exit $FAIL
