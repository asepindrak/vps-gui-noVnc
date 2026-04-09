#!/usr/bin/env bash
#===============================================================================
# 🚀 VPS GUI Automation Script - Flexible Display Support (IMPROVED)
# Works with: Headless VPS, Ubuntu Desktop, POP OS, Debian with/without GUI
# Remote Desktop + noVNC + VS Code + Chrome automation
# Can be run for fresh install OR update/fixing
# Uses regular user (not root)
#
# Usage: sudo bash auto-install.sh [username] [install_code_browser]
# Example: sudo bash auto-install.sh myuser yes
# Example: sudo bash auto-install.sh  (default: current user, install YES)
# Auto-detects existing display server on :0 and uses it
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
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════${NC}"
    echo ""
}

# ============================================================================
# PARAMETER & VALIDATION
# ============================================================================
if [ "$EUID" -ne 0 ]; then
    log_error "Script MUST be run with sudo"
    echo "Usage: sudo bash $0 [username] [install_code_browser]"
    exit 1
fi

TARGET_USER="${1:-$SUDO_USER}"
if [ -z "$TARGET_USER" ]; then
    TARGET_USER="vpsuser"
    log_warn "No username provided, will use: $TARGET_USER"
fi

INSTALL_CODE="${2:-yes}"
INSTALL_CODE="${INSTALL_CODE,,}"

USER_HOME="/home/$TARGET_USER"
VNC_DIR="$USER_HOME/.vnc"
XFCE_CONFIG="$USER_HOME/.config/xfce4"
WRAPPER_DIR="/usr/local/bin"

# ============================================================================
# OS DETECTION
# ============================================================================
detect_os() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        OS_NAME="$NAME"
        OS_ID="$ID"
        OS_VERSION="$VERSION_ID"
    elif [ -f /etc/debian_version ]; then
        OS_NAME="Debian"
        OS_ID="debian"
        OS_VERSION=$(cat /etc/debian_version)
    elif [ -f /etc/redhat-release ]; then
        OS_NAME="RHEL-based"
        OS_ID="rhel"
    else
        OS_NAME="Unknown"
        OS_ID="unknown"
    fi
    log_info "Detected OS: $OS_NAME ($OS_ID) version $OS_VERSION"
}

# ============================================================================
# DISPLAY DETECTION (Improved)
# ============================================================================
detect_display() {
    # 1. Try to get DISPLAY from target user's session via loginctl (Most reliable for existing desktop)
    if [ -n "$TARGET_USER" ]; then
        USER_SESSIONS=$(loginctl list-sessions --no-legend | awk '{print $1}') 2>/dev/null
        for SESSION_ID in $USER_SESSIONS; do
            SESSION_USER=$(loginctl show-session $SESSION_ID -p User --value)
            if [ "$SESSION_USER" = "$TARGET_USER" ]; then
                SESSION_DISPLAY=$(loginctl show-session $SESSION_ID -p Display --value)
                if [ -n "$SESSION_DISPLAY" ]; then
                    DISPLAY_NUM="$SESSION_DISPLAY"
                    USE_EXISTING_DISPLAY=true
                    log_warn "Detected existing X server from user session ($TARGET_USER) on $DISPLAY_NUM - Using EXISTING DISPLAY mode"
                    return 0
                fi
            fi
        done
    fi

    # 2. Check /tmp/.X11-unix/ for sockets (Sorted reverse to pick user session over login screen)
    # Most desktop users are on :1, login screen is on :0
    for socket in $(ls /tmp/.X11-unix/X* 2>/dev/null | sort -r); do
        if [ -S "$socket" ]; then
            num="${socket#/tmp/.X11-unix/X}"
            DISPLAY_NUM=":$num"
            # Quick check if this display responds to xauth (means it's likely the right one)
            if DISPLAY=$DISPLAY_NUM xauth list &>/dev/null || DISPLAY=$DISPLAY_NUM xauth info &>/dev/null; then
                 USE_EXISTING_DISPLAY=true
                 log_warn "Detected existing X server socket on $DISPLAY_NUM - Using EXISTING DISPLAY mode"
                 return 0
            fi
        fi
    done

    # 3. Try to get DISPLAY from environment (Only if not :0)
    if [ -n "$DISPLAY" ] && [ "$DISPLAY" != ":0" ]; then
        DISPLAY_NUM="$DISPLAY"
        USE_EXISTING_DISPLAY=true
        log_warn "Detected existing X server from environment on $DISPLAY_NUM - Using EXISTING DISPLAY mode"
        return 0
    fi

    # 4. Final fallback for :0 if socket exists but xauth failed (might need manual xhost)
    if [ -S /tmp/.X11-unix/X0 ]; then
         DISPLAY_NUM=":0"
         USE_EXISTING_DISPLAY=true
         log_warn "Detected :0 socket - Using EXISTING DISPLAY mode (fallback)"
         return 0
    fi
    
    # Default to virtual display for headless
    DISPLAY_NUM=":1"
    USE_EXISTING_DISPLAY=false
    log_info "No existing display detected - Using VIRTUAL DISPLAY mode (Headless Server)"
    return 0
}

# Improved XAUTHORITY detection
detect_xauthority() {
    if [ "$USE_EXISTING_DISPLAY" = false ]; then
        XAUTH_FILE="/home/$TARGET_USER/.Xauthority"
        return 0
    fi

    # Search common locations
    XAUTH_LOCATIONS=(
        "/home/$TARGET_USER/.Xauthority"
        "/run/user/$(id -u $TARGET_USER 2>/dev/null || echo 1000)/gdm/Xauthority"
        "/run/user/$(id -u $TARGET_USER 2>/dev/null || echo 1000)/xauth_*"
    )

    for loc in "${XAUTH_LOCATIONS[@]}"; do
        # Use expansion for globs like xauth_*
        for f in $loc; do
            if [ -f "$f" ]; then
                XAUTH_FILE="$f"
                log_info "Detected Xauthority at: $XAUTH_FILE"
                return 0
            fi
        done
    done

    # Fallback
    XAUTH_FILE="/home/$TARGET_USER/.Xauthority"
    log_warn "Could not find valid Xauthority, using default: $XAUTH_FILE"
}


detect_os
detect_display
detect_xauthority

log_info "Target user: $TARGET_USER"
log_info "Home directory: $USER_HOME"
log_info "Display number: $DISPLAY_NUM"
log_info "Xauthority file: $XAUTH_FILE"
log_info "Using existing display: ${USE_EXISTING_DISPLAY:-false}"
log_info "Install VS Code & Chrome: $INSTALL_CODE"

# ============================================================================
# STEP 1: CREATE USER IF NOT EXISTS
# ============================================================================
log_section "STEP 1: User & System Setup"
if id "$TARGET_USER" &>/dev/null; then
    log_success "User '$TARGET_USER' already exists"
else
    log_info "Creating user '$TARGET_USER'..."
    useradd -m -s /bin/bash -G sudo,video,audio,input "$TARGET_USER"
    log_success "User '$TARGET_USER' successfully created"
    log_info "Set password for user (or Enter to skip):"
    passwd "$TARGET_USER" || true
fi

usermod -a -G sudo,video,audio,input,render "$TARGET_USER" 2>/dev/null || true

if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME"
    chmod 700 "$USER_HOME"
    log_success "Home directory created: $USER_HOME"
fi

# ============================================================================
# STEP 2: SYSTEM UPDATE & PACKAGES (Multi-OS)
# ============================================================================
log_section "STEP 2: Update & Install Dependencies"

# Detect package manager
if command -v apt &>/dev/null; then
    PKG_MANAGER="apt"
    log_info "Using apt package manager"
elif command -v dnf &>/dev/null; then
    PKG_MANAGER="dnf"
    log_info "Using dnf package manager"
elif command -v yum &>/dev/null; then
    PKG_MANAGER="yum"
    log_info "Using yum package manager"
else
    log_error "No supported package manager found"
    exit 1
fi

log_info "Updating package list..."
if [ "$PKG_MANAGER" = "apt" ]; then
    apt update -y && apt upgrade -y
elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    $PKG_MANAGER update -y
fi

log_info "Installing base dependencies..."
if [ "$PKG_MANAGER" = "apt" ]; then
    PACKAGES=(
        # GUI & Display
        "xfce4" "xfce4-goodies" "xfce4-terminal" "xfce4-taskmanager"
        # VNC & Virtual Display
        "xvfb" "x11vnc" "websockify" "novnc"
        # Tools
        "net-tools" "curl" "wget" "git" "nano" "vim" "htop" "build-essential"
        # X11 utilities
        "xauth" "xdpyinfo" "xset" "wmctrl" "xorg"
        # Sound
        "pulseaudio" "pavucontrol"
        # Fonts
        "fonts-ubuntu" "fonts-dejavu"
    )
    apt install -y "${PACKAGES[@]}" || true
    
elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
    # RHEL-based packages (simplified mapping)
    $PKG_MANAGER install -y epel-release || true
    $PKG_MANAGER install -y \
        xfce4 xfce4-goodies xfce4-terminal \
        xorg-x11-server-Xvfb x11vnc websockify \
        curl wget git nano vim htop \
        xorg-x11-xauth xorg-x11-utils \
        pulseaudio pavucontrol \
        dejavu-sans-fonts dejavu-serif-fonts || true
fi

log_success "Dependencies installed"

# ============================================================================
# STEP 3: SETUP VNC DIRECTORY & FILES
# ============================================================================
log_section "STEP 3: Setup VNC Configuration"
mkdir -p "$VNC_DIR"
chown -R "$TARGET_USER:$TARGET_USER" "$VNC_DIR"
chmod 700 "$VNC_DIR"

# Create xstartup script
cat > "$VNC_DIR/xstartup" << 'EOF'
#!/bin/bash
export SSH_ASKPASS=""
export SSH_ASKPASS_REQUIRE=never
export GNOME_KEYRING_CONTROL=""
xrdb $HOME/.Xresources 2>/dev/null || true
startxfce4 &
EOF
chmod +x "$VNC_DIR/xstartup"
chown "$TARGET_USER:$TARGET_USER" "$VNC_DIR/xstartup"
log_success "xstartup script created"

# ============================================================================
# STEP 4: SETUP XFCE AUTOSTART
# ============================================================================
log_section "STEP 4: Setup XFCE Autostart Configuration"
mkdir -p "$XFCE_CONFIG/autostart"
chown -R "$TARGET_USER:$TARGET_USER" "$XFCE_CONFIG"

# x11vnc autostart (only for virtual display mode)
if [ "$USE_EXISTING_DISPLAY" = false ]; then
cat > "$XFCE_CONFIG/autostart/x11vnc.desktop" << EOF
[Desktop Entry]
Type=Application
Name=x11vnc
Exec=x11vnc -display :1 -forever -shared -nopw -rfbport 5900
NoDisplay=true
X-XFCE-Autostart-Override=true
StartupNotify=false
Hidden=false
EOF
fi

# Disable keyring prompts
cat > "$XFCE_CONFIG/autostart/xfce4-notifyd.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Notification Daemon
Exec=xfce4-notifyd
Hidden=true
NoDisplay=true
EOF

cat > "$XFCE_CONFIG/autostart/gnome-keyring.desktop" << EOF
[Desktop Entry]
Type=Application
Name=GNOME Keyring
Exec=gnome-keyring-daemon
Hidden=true
NoDisplay=true
X-XFCE-Autostart=false
EOF

# VS Code autostart
if [[ "$INSTALL_CODE" == "yes" ]] || [[ "$INSTALL_CODE" == "y" ]]; then
cat > "$XFCE_CONFIG/autostart/vscode.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Visual Studio Code
Exec=bash -c 'sleep 8 && $USER_HOME/.local/bin/vscode-vnc --autostart'
Icon=code
Categories=Development;IDE;
NoDisplay=false
StartupNotify=false
X-XFCE-Autostart-Override=true
Terminal=false
Hidden=false
EOF
fi
chown -R "$TARGET_USER:$TARGET_USER" "$XFCE_CONFIG/autostart"
log_success "XFCE autostart configured"

# ============================================================================
# PRE-FLIGHT: Existing Display Validation
# ============================================================================
if [ "$USE_EXISTING_DISPLAY" = true ]; then
log_section "PRE-FLIGHT: Validating Existing Display ($DISPLAY_NUM)"

# Try to grant X11 access
if [ -S /tmp/.X11-unix/X${DISPLAY_NUM#:} ]; then
    log_info "Granting X11 permissions for $TARGET_USER..."
    xhost +SI:localuser:$TARGET_USER 2>/dev/null || true
    xhost +SI:localuser:root 2>/dev/null || true
    xhost +local: 2>/dev/null || true
fi

# Verify access
if sudo -u "$TARGET_USER" DISPLAY=$DISPLAY_NUM xdpyinfo &>/dev/null 2>&1; then
    log_success "X11 access verified for $TARGET_USER"
else
    log_warn "X11 access test failed - service may need manual xhost setup"
fi
fi

# ============================================================================
# STEP 5: CREATE WRAPPER SCRIPTS & SYSTEMD SERVICE
# ============================================================================
log_section "STEP 5: Create Systemd Service & Wrappers"

# Cleanup old service
if [ -f /etc/systemd/system/vps-gui.service ]; then
    log_info "Removing old service file..."
    systemctl stop vps-gui 2>/dev/null || true
    systemctl disable vps-gui 2>/dev/null || true
    rm -f /etc/systemd/system/vps-gui.service
    systemctl daemon-reload
fi

# ============================================================================
# Wrapper for EXISTING DISPLAY mode ($DISPLAY_NUM) - IMPROVED
# ============================================================================
if [ "$USE_EXISTING_DISPLAY" = true ]; then
log_info "Creating wrapper script for existing display mode ($DISPLAY_NUM)..."
cat > "$WRAPPER_DIR/vps-gui-wrapper-existing" << WRAPPER_SCRIPT
#!/bin/bash
# VPS GUI Wrapper for Existing Display Mode ($DISPLAY_NUM)
# Compatible with POP OS, Ubuntu Desktop, Debian with GUI

set -e
export DISPLAY=$DISPLAY_NUM
export XAUTHORITY="$XAUTH_FILE"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export SSH_ASKPASS=
export SSH_ASKPASS_REQUIRE=never
export GNOME_KEYRING_CONTROL=

# Wait for X server to be ready
log_wait() { echo "[\$(date '+%H:%M:%S')] \$1"; }
for i in {1..15}; do
    if xdpyinfo -display $DISPLAY_NUM &>/dev/null; then
        log_wait "X server $DISPLAY_NUM is ready"
        break
    fi
    log_wait "Waiting for X server... (\$i/15)"
    sleep 2
done

# Grant X11 access (multiple methods for compatibility)
XAUTH_DIR="/run/user/$(id -u $TARGET_USER 2>/dev/null || echo 1000)"
if [ -d "$XAUTH_DIR" ]; then
    export XAUTHORITY=$(find "$XAUTH_DIR" -maxdepth 3 -name "Xauthority" -o -name "xauth_*" 2>/dev/null | head -n 1)
    [ -n "$XAUTHORITY" ] && log_wait "Using dynamic Xauthority: $XAUTHORITY"
fi

# Try granting permissions (very aggressive)
xhost +SI:localuser:$TARGET_USER 2>/dev/null || true
xhost +local: 2>/dev/null || true

# Detect binary dynamically
X11VNC_BIN=\$(command -v x11vnc || echo "/usr/bin/x11vnc")
WEBSOCKIFY_BIN=\$(command -v websockify || echo "/usr/bin/websockify")

# Start x11vnc with robust options for existing display
# -auth $XAUTHORITY: Use the detected authority file
# -noxrecord -noxfixes: Required for some GNOME sessions
# -noxdamage: Fixes refresh issues
# -noxshm: IMPORTANT! Fixing BadMatch (invalid parameter attributes) on X_GetImage
# -noxinerama: For single/multiple display compatibility
# -solid: Improve GNOME desktop compatibility
log_wait "Starting x11vnc using \$X11VNC_BIN..."
\$X11VNC_BIN -display $DISPLAY_NUM \\
    -auth "\${XAUTHORITY:-guess}" \\
    -forever \\
    -shared \\
    -nopw \\
    -rfbport 5900 \\
    -allow localhost \\
    -xkb \\
    -noxshm \\
    -noxdamage \\
    -noxrecord \\
    -noxfixes \\
    -noxinerama \\
    -solid \\
    -nowf \\
    -logfile /tmp/x11vnc-existing.log &

X11VNC_PID=\$!
log_wait "x11vnc started with PID: \$X11VNC_PID"

# Verify x11vnc is running
sleep 3
if ! kill -0 \$X11VNC_PID 2>/dev/null; then
    echo "[ERROR] x11vnc failed to start" >&2
    cat /tmp/x11vnc-existing.log 2>/dev/null >&2 || true
    exit 1
fi

# Start websockify (stays in foreground to keep service alive)
log_wait "Starting websockify using \$WEBSOCKIFY_BIN on port 6080..."
exec \$WEBSOCKIFY_BIN --web=/usr/share/novnc/ 6080 localhost:5900
WRAPPER_SCRIPT
chmod +x "$WRAPPER_DIR/vps-gui-wrapper-existing"
chown root:root "$WRAPPER_DIR/vps-gui-wrapper-existing"
log_success "Wrapper created: $WRAPPER_DIR/vps-gui-wrapper-existing"
fi

# ============================================================================
# Wrapper for VIRTUAL DISPLAY mode (:1)
# ============================================================================
if [ "$USE_EXISTING_DISPLAY" = false ]; then
log_info "Creating wrapper script for virtual display mode..."
cat > "$WRAPPER_DIR/vps-gui-wrapper-virtual" << WRAPPER_SCRIPT
#!/bin/bash
# VPS GUI Wrapper for Virtual Display Mode (:1)
# For headless VPS without existing GUI

set -e
export DISPLAY=:1
export XAUTHORITY="$XAUTH_FILE"
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export SSH_ASKPASS=
export SSH_ASKPASS_REQUIRE=never
export GNOME_KEYRING_CONTROL=

# Cleanup old display locks
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true
rm -f "$XAUTHORITY" 2>/dev/null || true

# Start Xvfb (virtual framebuffer)
Xvfb :1 -screen 0 1280x720x24 +extension RANDR &
XVFB_PID=$!
sleep 2

# Start XFCE desktop
startxfce4 &
sleep 5

# Start x11vnc
x11vnc -display :1 -forever -shared -nopw -rfbport 5900 -allow localhost &
X11VNC_PID=$!
sleep 2

# Verify processes
for pid in $XVFB_PID $X11VNC_PID; do
    if ! kill -0 $pid 2>/dev/null; then
        echo "[ERROR] Process $pid failed to start" >&2
        exit 1
    fi
done

# Start websockify (foreground)
exec websockify --web=/usr/share/novnc/ 6080 localhost:5900
WRAPPER_SCRIPT
chmod +x "$WRAPPER_DIR/vps-gui-wrapper-virtual"
chown root:root "$WRAPPER_DIR/vps-gui-wrapper-virtual"
log_success "Wrapper created: $WRAPPER_DIR/vps-gui-wrapper-virtual"
fi

# ============================================================================
# Create systemd service based on display mode
# ============================================================================
if [ "$USE_EXISTING_DISPLAY" = true ]; then
log_info "Creating service for existing display mode ($DISPLAY_NUM)..."
cat > /etc/systemd/system/vps-gui.service << EOL
[Unit]
Description=Remote Desktop Service (x11vnc + noVNC) - Existing Display Mode
After=network.target graphical.target display-manager.service
Requires=graphical.target
Wants=network.target

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_USER

# Critical environment variables for X11 access
Environment="DISPLAY=$DISPLAY_NUM"
Environment="XAUTHORITY=$XAUTH_FILE"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="SSH_ASKPASS="
Environment="SSH_ASKPASS_REQUIRE=never"
Environment="GNOME_KEYRING_CONTROL="
Environment="XDG_SESSION_TYPE=x11"
Environment="XDG_RUNTIME_DIR=/run/user/$(id -u $TARGET_USER 2>/dev/null || echo 1000)"

WorkingDirectory=$USER_HOME

# Pre-start checks (Removed xdpyinfo check because wrapper handles waiting)
ExecStartPre=/bin/sleep 3

ExecStart=$WRAPPER_DIR/vps-gui-wrapper-existing

Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vps-gui

# Resource limits
MemoryMax=512M
MemoryHigh=256M

# Relaxed security for existing display mode (needs X11 access)
NoNewPrivileges=false
PrivateTmp=false
ProtectHome=false

[Install]
WantedBy=multi-user.target
EOL

else
# Virtual display mode service
log_info "Creating service for virtual display mode (:1)..."
cat > /etc/systemd/system/vps-gui.service << EOL
[Unit]
Description=Remote Desktop Service (Xvfb + XFCE + x11vnc + noVNC) - Virtual Display Mode
After=network.target

[Service]
Type=simple
User=$TARGET_USER
Group=$TARGET_USER

Environment="DISPLAY=:1"
Environment="XAUTHORITY=$XAUTH_FILE"
Environment="PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
Environment="SSH_ASKPASS="
Environment="SSH_ASKPASS_REQUIRE=never"
Environment="GNOME_KEYRING_CONTROL="

WorkingDirectory=$USER_HOME

ExecStart=$WRAPPER_DIR/vps-gui-wrapper-virtual

Restart=on-failure
RestartSec=10
StandardOutput=journal
StandardError=journal
SyslogIdentifier=vps-gui

MemoryMax=512M
MemoryHigh=256M
NoNewPrivileges=true
PrivateTmp=true

[Install]
WantedBy=multi-user.target
EOL
fi

log_success "Systemd service created: /etc/systemd/system/vps-gui.service"

# ============================================================================
# STEP 6: SETUP ENVIRONMENT VARIABLES
# ============================================================================
log_section "STEP 6: Setup Environment Variables"
for profile_file in "$USER_HOME/.bash_profile" "$USER_HOME/.bashrc" "$USER_HOME/.profile"; do
    if [ -f "$profile_file" ] || [ "$USE_EXISTING_DISPLAY" = true ]; then
        if ! grep -q "export DISPLAY=$DISPLAY_NUM" "$profile_file" 2>/dev/null; then
            echo "export DISPLAY=$DISPLAY_NUM" >> "$profile_file" 2>/dev/null || true
            chown "$TARGET_USER:$TARGET_USER" "$profile_file" 2>/dev/null || true
        fi
    fi
done
log_success "Environment variables configured"

# ============================================================================
# STEP 7: INSTALL VS CODE (Optional)
# ============================================================================
if [[ "$INSTALL_CODE" == "yes" ]] || [[ "$INSTALL_CODE" == "y" ]]; then
log_section "STEP 7: Installing VS Code"
if command -v code &>/dev/null; then
    log_success "VS Code already installed"
else
    log_info "Downloading & installing VS Code..."
    cd /tmp
    if wget -q https://aka.ms/download-vscode-stable -O vscode.deb 2>/dev/null || \
       curl -fL https://aka.ms/download-vscode-stable -o vscode.deb 2>/dev/null; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            apt install -y ./vscode.deb 2>/dev/null || true
        else
            dpkg -i vscode.deb 2>/dev/null || apt install -f -y 2>/dev/null || true
        fi
        rm -f vscode.deb
        log_success "VS Code installed"
    else
        log_warn "Failed to download VS Code, skipping..."
    fi
fi

# VS Code wrapper
mkdir -p "$USER_HOME/.local/bin"
cat > "$USER_HOME/.local/bin/vscode-vnc" << 'WRAPPER'
#!/usr/bin/env bash
export DISPLAY="${DISPLAY:-:1}"
rm -f ~/.config/Code/lock ~/.config/Code/*.lock ~/.config/Code/Crashpad/lock 2>/dev/null
if [ "$1" == "--autostart" ]; then
    nohup /usr/bin/code --no-sandbox --disable-gpu --disable-dev-shm-usage --force-renderer-accessibility "$@" &>/dev/null &
else
    exec /usr/bin/code --no-sandbox --disable-gpu --disable-dev-shm-usage --force-renderer-accessibility "$@"
fi
WRAPPER
chmod +x "$USER_HOME/.local/bin/vscode-vnc"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.local/bin/vscode-vnc"

# Update desktop launcher
if [ -f "/usr/share/applications/code.desktop" ]; then
    sed -i "s|^Exec=.*|Exec=$USER_HOME/.local/bin/vscode-vnc|" /usr/share/applications/code.desktop
fi
log_success "VS Code launcher configured"
else
log_warn "STEP 7: Skipping VS Code installation"
fi

# ============================================================================
# STEP 8: INSTALL CHROME (Optional)
# ============================================================================
if [[ "$INSTALL_CODE" == "yes" ]] || [[ "$INSTALL_CODE" == "y" ]]; then
log_section "STEP 8: Installing Google Chrome"
if command -v google-chrome-stable &>/dev/null; then
    log_success "Google Chrome already installed"
else
    log_info "Downloading & installing Google Chrome..."
    cd /tmp
    if curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o chrome.deb 2>/dev/null || \
       wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb 2>/dev/null; then
        if [ "$PKG_MANAGER" = "apt" ]; then
            apt install -y ./chrome.deb 2>/dev/null || true
        else
            dpkg -i chrome.deb 2>/dev/null || apt install -f -y 2>/dev/null || true
        fi
        rm -f chrome.deb
        log_success "Google Chrome installed"
    else
        log_warn "Failed to download Chrome, skipping..."
    fi
fi

# Chrome wrapper
cat > "$USER_HOME/.local/bin/chrome-vnc" << 'WRAPPER'
#!/usr/bin/env bash
rm -f ~/.config/google-chrome/SingletonLock ~/.config/google-chrome/SingletonCookie 2>/dev/null
exec /usr/bin/google-chrome-stable --no-sandbox --disable-gpu --disable-dev-shm-usage "$@"
WRAPPER
chmod +x "$USER_HOME/.local/bin/chrome-vnc"
chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.local/bin/chrome-vnc"

for desktop_file in /usr/share/applications/google-chrome*.desktop; do
    [ -f "$desktop_file" ] && sed -i "s|^Exec=.*|Exec=$USER_HOME/.local/bin/chrome-vnc|" "$desktop_file"
done
log_success "Chrome launcher configured"
else
log_warn "STEP 8: Skipping Google Chrome installation"
fi

# ============================================================================
# STEP 9: FIREWALL CONFIGURATION
# ============================================================================
log_section "STEP 9: Firewall Configuration"
if command -v ufw &>/dev/null; then
    if sudo ufw status | grep -q "Status: inactive"; then
        log_info "UFW inactive - enabling basic rules"
        ufw --force enable 2>/dev/null || true
    fi
    ufw allow 6080/tcp 2>/dev/null || true
    ufw allow 5900/tcp 2>/dev/null || true
    ufw allow 22/tcp 2>/dev/null || true
    log_success "Firewall rules configured"
else
    log_warn "UFW not installed, skipping firewall setup"
fi

# ============================================================================
# STEP 10: SYSTEMD SERVICE ACTIVATION
# ============================================================================
log_section "STEP 10: Systemd Service Activation"
systemctl daemon-reload
log_success "Systemd reloaded"

systemctl stop vps-gui 2>/dev/null || true
sleep 2

if ! systemctl is-enabled vps-gui &>/dev/null; then
    systemctl enable vps-gui
    log_success "Service enabled for auto-start"
fi

log_info "Starting service..."
systemctl start vps-gui

# Wait and verify
sleep 5
for i in {1..5}; do
    if systemctl is-active --quiet vps-gui 2>/dev/null; then
        log_success "✅ Service started successfully!"
        break
    fi
    log_info "Waiting for service... ($i/5)"
    sleep 2
done

if ! systemctl is-active --quiet vps-gui 2>/dev/null; then
    log_error "❌ Service failed to start"
    journalctl -u vps-gui -n 20 --no-pager || true
    if [ "$USE_EXISTING_DISPLAY" = true ]; then
        log_info "💡 For existing display mode, try:"
        echo "  1. Log out and log back in to refresh X session"
        echo "  2. Run: xhost +SI:localuser:$TARGET_USER"
        echo "  3. Then: sudo systemctl restart vps-gui"
    fi
fi

# ============================================================================
# STEP 11: VERIFICATION
# ============================================================================
log_section "STEP 11: Verification & Testing"

# Check X server
if DISPLAY="$DISPLAY_NUM" xdpyinfo &>/dev/null 2>&1; then
    log_success "X server responding on $DISPLAY_NUM"
else
    log_warn "X server not responding yet (may need user session)"
fi

# Check ports
log_info "Checking ports..."
if ss -tlnp 2>/dev/null | grep -q ":6080 "; then
    log_success "Port 6080 (noVNC) listening"
else
    log_warn "Port 6080 not listening yet"
fi
if ss -tlnp 2>/dev/null | grep -q ":5900 "; then
    log_success "Port 5900 (VNC) listening"
else
    log_warn "Port 5900 not listening yet"
fi

# Get IP
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}' || echo "localhost")

# ============================================================================
# STEP 12: VNC PASSWORD SETUP (Optional)
# ============================================================================
log_section "STEP 12: Optional - Setup VNC Password"
log_info "Set VNC password? (y/n) [default: n]"
read -r -t 10 setup_password || setup_password="n"

if [[ "$setup_password" == "y" || "$setup_password" == "Y" ]]; then
    log_info "Setting VNC password..."
    systemctl stop vps-gui 2>/dev/null || true
    sleep 2
    
    echo "Enter VNC password (hidden):"
    read -s -r vnc_password
    echo ""
    echo "Confirm password:"
    read -s -r vnc_confirm
    echo ""
    
    if [ "$vnc_password" = "$vnc_confirm" ] && [ -n "$vnc_password" ]; then
        if sudo -u "$TARGET_USER" x11vnc -storepasswd "$vnc_password" "$VNC_DIR/passwd" 2>/dev/null; then
            chmod 600 "$VNC_DIR/passwd"
            chown "$TARGET_USER:$TARGET_USER" "$VNC_DIR/passwd"
            sed -i 's/-nopw/-rfbauth '"$VNC_DIR"'\/passwd/g' /etc/systemd/system/vps-gui.service
            systemctl daemon-reload
            systemctl start vps-gui
            log_success "VNC password set successfully!"
        else
            log_error "Failed to set password"
            systemctl start vps-gui
        fi
    else
        log_error "Passwords don't match or empty"
        systemctl start vps-gui
    fi
else
    log_warn "Using no-password mode (set later with: sudo bash setpw.sh)"
fi

# ============================================================================
# STEP 13: NGINX PROXY (Optional)
# ============================================================================
log_section "STEP 13: Optional - Nginx Proxy Setup"
PORT_PROXY=6969
PORT_LOCAL=8081

if ! ss -tlnp 2>/dev/null | grep -q ":$PORT_PROXY "; then
    if ! command -v nginx &>/dev/null; then
        log_info "Installing nginx..."
        if [ "$PKG_MANAGER" = "apt" ]; then
            apt install -y nginx 2>/dev/null || true
        elif [ "$PKG_MANAGER" = "dnf" ] || [ "$PKG_MANAGER" = "yum" ]; then
            $PKG_MANAGER install -y nginx 2>/dev/null || true
        fi
    fi
    
    if command -v nginx &>/dev/null; then
        log_info "Configuring nginx proxy..."
        NGINX_CONFIG="/etc/nginx/sites-available/vps-gui-proxy"
        
        cat > "$NGINX_CONFIG" << NGINX_EOF
server {
    listen $PORT_PROXY default_server;
    listen [::]:$PORT_PROXY default_server;
    server_name _;
    
    location / {
        proxy_pass http://127.0.0.1:$PORT_LOCAL;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}
NGINX_EOF
        
        [ ! -L "/etc/nginx/sites-enabled/vps-gui-proxy" ] && \
            ln -sf "$NGINX_CONFIG" "/etc/nginx/sites-enabled/vps-gui-proxy"
        rm -f /etc/nginx/sites-enabled/default 2>/dev/null || true
        
        if nginx -t &>/dev/null; then
            systemctl enable nginx --now &>/dev/null || true
            systemctl restart nginx &>/dev/null || true
            if systemctl is-active --quiet nginx 2>/dev/null; then
                log_success "Nginx proxy configured on port $PORT_PROXY"
                NGINX_CONFIGURED=1
            fi
        else
            log_warn "Nginx config invalid, skipping"
        fi
    fi
else
    log_warn "Port $PORT_PROXY in use, skipping nginx setup"
fi
NGINX_CONFIGURED=${NGINX_CONFIGURED:-0}

# ============================================================================
# FINAL SUMMARY
# ============================================================================
log_section "✅ INSTALLATION COMPLETE!"
echo -e "${GREEN}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🎉 VPS GUI Automation Setup Finished Successfully!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo -e "${CYAN}📋 Setup Information:${NC}"
echo "  Username      : $TARGET_USER"
echo "  Home Dir      : $USER_HOME"
echo "  Display       : $DISPLAY_NUM"
echo "  Mode          : $(if [ "$USE_EXISTING_DISPLAY" = true ]; then echo "EXISTING (Desktop GUI)"; else echo "VIRTUAL (Headless Server)"; fi)"
echo "  OS            : $OS_NAME ($OS_ID)"
echo "  Server IP     : $SERVER_IP"
echo ""
echo -e "${CYAN}🌐 Access Information:${NC}"
echo "  Browser URL   : ${GREEN}http://$SERVER_IP:6080${NC}"
echo "  VNC Direct    : ${GREEN}vnc://$SERVER_IP:5900${NC}"
[ "$NGINX_CONFIGURED" -eq 1 ] && echo "  Nginx Proxy   : ${GREEN}http://$SERVER_IP:$PORT_PROXY${NC}"
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "  1. Open browser: http://$SERVER_IP:6080"
echo "  2. Click 'Connect' button"
echo "  3. XFCE desktop should appear in 10-20 seconds"
echo ""
echo -e "${CYAN}📖 Useful Commands:${NC}"
echo "  sudo systemctl status vps-gui        # Check service"
echo "  sudo journalctl -u vps-gui -f        # View logs"
echo "  sudo systemctl restart vps-gui       # Restart service"
echo "  sudo bash check.sh $TARGET_USER      # Health check"
echo "  sudo bash setpw.sh $TARGET_USER      # Set VNC password"
echo ""
if [ "$USE_EXISTING_DISPLAY" = true ]; then
    echo -e "${YELLOW}💡 EXISTING DISPLAY MODE TIPS:${NC}"
    echo "  • Changes visible on your local monitor"
    echo "  • If X11 access fails, run: xhost +SI:localuser:$TARGET_USER"
    echo "  • Then: sudo systemctl restart vps-gui"
else
    echo -e "${YELLOW}💡 VIRTUAL DISPLAY MODE TIPS:${NC}"
    echo "  • Desktop runs in virtual framebuffer :1"
    echo "  • Use Ctrl+Alt+F2 for terminal in XFCE"
fi
echo ""
echo -e "${NC}"