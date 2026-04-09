#!/usr/bin/env bash
#===============================================================================
# 🚀 VPS GUI Automation Script - Flexible Display Support
# Works with existing GUI (POP OS, Ubuntu Desktop) or creates virtual display
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

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
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
# PARAMETER & VALIDATION
# ============================================================================

# Check root
if [ "$EUID" -ne 0 ]; then
    log_error "Script MUST be run with sudo"
    echo "Usage: sudo bash $0 [username] [install_code_browser]"
    exit 1
fi

# Username (from parameter or user who run sudo)
TARGET_USER="${1:-$SUDO_USER}"
if [ -z "$TARGET_USER" ]; then
    TARGET_USER="vpsuser"
    log_warn "No username provided, will use: $TARGET_USER"
fi

# Install VS Code & Chrome?
INSTALL_CODE="${2:-yes}"
INSTALL_CODE="${INSTALL_CODE,,}"  # lowercase

# Auto-detect existing display or use new one
if ps aux | grep -q '[X]org' || ps aux | grep -q '[w]ayland'; then
    # Detected running X server or Wayland on :0
    DISPLAY_NUM=":0"
    USE_EXISTING_DISPLAY=true
    log_warn "Detected existing display server - will use :0 (POP OS/Ubuntu Desktop mode)"
else
    # Create virtual display for headless servers
    DISPLAY_NUM=":1"
    USE_EXISTING_DISPLAY=false
    log_info "No existing display detected - will create virtual display :1 (Server mode)"
fi

USER_HOME="/home/$TARGET_USER"
VNC_DIR="$USER_HOME/.vnc"
XFCE_CONFIG="$USER_HOME/.config/xfce4"

log_info "Target user: $TARGET_USER"
log_info "Home directory: $USER_HOME"
log_info "Display number: $DISPLAY_NUM"
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
    
    # Set password if not already set
    log_info "Set password for user (or Enter to skip):"
    passwd "$TARGET_USER" || true
fi

# Ensure user is in correct groups
usermod -a -G sudo,video,audio,input,render "$TARGET_USER" 2>/dev/null || true

# Ensure home directory exists
if [ ! -d "$USER_HOME" ]; then
    mkdir -p "$USER_HOME"
    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME"
    chmod 700 "$USER_HOME"
    log_success "Home directory created: $USER_HOME"
fi

# ============================================================================
# STEP 2: SYSTEM UPDATE & PACKAGES
# ============================================================================

log_section "STEP 2: Update & Install Dependencies"

log_info "Updating package list..."
apt update -y

log_info "Upgrading packages..."
apt upgrade -y

log_info "Installing base dependencies..."
PACKAGES=(
    # GUI & Display
    "xfce4"
    "xfce4-goodies"
    "xfce4-terminal"
    "xfce4-taskmanager"
    
    # VNC & Virtual Display
    "xvfb"
    "x11vnc"
    "websockify"
    "novnc"
    
    # Tools & Utilities
    "net-tools"
    "curl"
    "wget"
    "git"
    "nano"
    "vim"
    "htop"
    "build-essential"
    
    # X11 utilities
    "xauth"
    "xdpyinfo"
    "xset"
    "wmctrl"
    
    # Sound & Multimedia
    "pulseaudio"
    "pavucontrol"
    
    # Font & Rendering
    "fonts-ubuntu"
    "fonts-dejavu"
)

apt install -y "${PACKAGES[@]}" || true
log_success "Dependencies installed"

# ============================================================================
# STEP 3: SETUP VNC DIRECTORY & FILES
# ============================================================================

log_section "STEP 3: Setup VNC Configuration"

mkdir -p "$VNC_DIR"
chown "$TARGET_USER:$TARGET_USER" "$VNC_DIR"
chmod 700 "$VNC_DIR"

# Create xstartup script for user
cat > "$VNC_DIR/xstartup" << 'EOF'
#!/bin/bash
# Disable XFCE/GNOME Keyring to avoid automation interruptions
export SSH_ASKPASS=""
export SSH_ASKPASS_REQUIRE=never

xrdb $HOME/.Xresources
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

# Autostart x11vnc
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

chown "$TARGET_USER:$TARGET_USER" "$XFCE_CONFIG/autostart/x11vnc.desktop"

# Disable XFCE Keyring daemon to avoid password prompts during automation
cat > "$XFCE_CONFIG/autostart/xfce4-notifyd.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Notification Daemon
Exec=xfce4-notifyd
Hidden=true
NoDisplay=true
EOF

chown "$TARGET_USER:$TARGET_USER" "$XFCE_CONFIG/autostart/xfce4-notifyd.desktop"

# Disable GNOME Keyring from autostart (prevents internet keyring prompts)
cat > "$XFCE_CONFIG/autostart/gnome-keyring.desktop" << EOF
[Desktop Entry]
Type=Application
Name=GNOME Keyring
Exec=gnome-keyring-daemon
Hidden=true
NoDisplay=true
X-XFCE-Autostart=false
EOF

chown "$TARGET_USER:$TARGET_USER" "$XFCE_CONFIG/autostart/gnome-keyring.desktop"

# Also disable it with .hidden file method
touch "$XFCE_CONFIG/autostart/gnome-keyring-ssh.desktop.hidden" 2>/dev/null || true
touch "$XFCE_CONFIG/autostart/gnome-keyring-gpg.desktop.hidden" 2>/dev/null || true
touch "$XFCE_CONFIG/autostart/gnome-keyring-pkcs11.desktop.hidden" 2>/dev/null || true

log_success "XFCE autostart configured + keyring disabled for automation"

# Auto-start VS Code when XFCE starts (if installed)
if [[ "$INSTALL_CODE" == "yes" ]] || [[ "$INSTALL_CODE" == "y" ]]; then
    cat > "$XFCE_CONFIG/autostart/vscode.desktop" << EOF
[Desktop Entry]
Type=Application
Name=Visual Studio Code
# Delay 8 seconds to ensure XFCE is fully initialized
Exec=bash -c 'sleep 8 && $USER_HOME/.local/bin/vscode-vnc --autostart'
Icon=code
Categories=Development;IDE;
NoDisplay=false
StartupNotify=false
X-XFCE-Autostart-Override=true
Terminal=false
MimeType=text/plain;
Hidden=false
Comment=Code Editor - Launches automatically with XFCE
EOF

    chown "$TARGET_USER:$TARGET_USER" "$XFCE_CONFIG/autostart/vscode.desktop"
    log_success "VS Code autostart configured - will launch automatically when XFCE starts"
else
    log_info "VS Code autostart skipped (INSTALL_CODE=no)"
fi

# ============================================================================
# STEP 5: CREATE SYSTEMD SERVICE
# ============================================================================

log_section "STEP 5: Create Systemd Service"

# Remove old service file if exists (cleanup from previous installations)
if [ -f /etc/systemd/system/vps-gui.service ]; then
    log_info "Removing old service file..."
    systemctl stop vps-gui 2>/dev/null || true
    systemctl disable vps-gui 2>/dev/null || true
    rm -f /etc/systemd/system/vps-gui.service
    systemctl daemon-reload
fi

# Create appropriate systemd service based on display mode
if [ "$USE_EXISTING_DISPLAY" = true ]; then
    # Simple service for existing display
    log_info "Creating service for existing display mode (:0)..."
    cat > /etc/systemd/system/vps-gui.service << EOL
[Unit]
Description=Remote Desktop Service (x11vnc + noVNC) - Existing Display Mode
After=network.target
PartOf=graphical-session.target
Wants=graphical-session.target

[Service]
Type=simple
User=$TARGET_USER
Environment="DISPLAY=:0"
Environment="XAUTHORITY=$USER_HOME/.Xauthority"
Environment="SSH_ASKPASS="
Environment="SSH_ASKPASS_REQUIRE=never"
Environment="GNOME_KEYRING_CONTROL="
WorkingDirectory=$USER_HOME

# Wait for X server to be fully ready, then start x11vnc
ExecStartPre=/bin/sleep 3
ExecStart=/bin/bash -c 'x11vnc -display :0 -forever -shared -nopw -rfbport 5900 & sleep 2 && websockify --web=/usr/share/novnc/ 6080 localhost:5900'

Restart=on-failure
RestartSec=10
MemoryMax=512M
MemoryHigh=256M

[Install]
WantedBy=graphical-session.target
EOL
else
    # Full service for virtual display with Xvfb + XFCE
    log_info "Creating service for virtual display mode (:1)..."
    cat > /etc/systemd/system/vps-gui.service << EOL
[Unit]
Description=Remote Desktop Service (Xvfb + XFCE + x11vnc + noVNC) - Virtual Display Mode
After=network.target

[Service]
Type=simple
User=$TARGET_USER
Environment="DISPLAY=$DISPLAY_NUM"
Environment="XAUTHORITY=$USER_HOME/.Xauthority"
Environment="SSH_ASKPASS="
Environment="SSH_ASKPASS_REQUIRE=never"
Environment="GNOME_KEYRING_CONTROL="
WorkingDirectory=$USER_HOME

ExecStartPre=/bin/bash -c 'rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 2>/dev/null || true'
ExecStartPre=/bin/bash -c 'rm -f $USER_HOME/.Xauthority 2>/dev/null || true'

ExecStart=/bin/bash -c 'Xvfb $DISPLAY_NUM -screen 0 1280x720x24 & sleep 2 && export DISPLAY=$DISPLAY_NUM && export XAUTHORITY=$USER_HOME/.Xauthority && startxfce4 & sleep 5 && x11vnc -display $DISPLAY_NUM -forever -shared -nopw -rfbport 5900 & websockify --web=/usr/share/novnc/ 6080 localhost:5900'

Restart=on-failure
RestartSec=10
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
# STEP 6: SETUP XFCE DISPLAY ENVIRONMENT
# ============================================================================

log_section "STEP 6: Setup Environment Variables"

# Set DISPLAY permanent in user profile
for profile_file in "$USER_HOME/.bash_profile" "$USER_HOME/.bashrc" "$USER_HOME/.profile"; do
    if ! grep -q "export DISPLAY=$DISPLAY_NUM" "$profile_file" 2>/dev/null; then
        echo "export DISPLAY=$DISPLAY_NUM" >> "$profile_file"
        chown "$TARGET_USER:$TARGET_USER" "$profile_file"
    fi
done

log_success "Environment variables configured"

# ============================================================================
# STEP 7: OPTIONAL - INSTALL VS CODE
# ============================================================================

if [[ "$INSTALL_CODE" == "yes" ]] || [[ "$INSTALL_CODE" == "y" ]]; then
    log_section "STEP 7: Installing VS Code"
    
    if command -v code &>/dev/null; then
        log_success "VS Code already installed"
    else
        log_info "Downloading & installing VS Code..."
        
        cd /tmp
        wget -q https://aka.ms/download-vscode-stable -O vscode.deb || \
        curl -fL https://aka.ms/download-vscode-stable -o vscode.deb
        
        if [ -f vscode.deb ]; then
            apt install -y ./vscode.deb
            rm -f vscode.deb
            log_success "VS Code successfully installed"
        else
            log_warn "Failed to download VS Code, skip..."
        fi
    fi
    
    # Setup VS Code for user
    mkdir -p "$USER_HOME/.local/bin"
    
    cat > "$USER_HOME/.local/bin/vscode-vnc" << 'WRAPPER'
#!/usr/bin/env bash
# VS Code Wrapper for noVNC/XFCE compatibility
# Handles both manual launch and autostart scenarios

# Wait for display to be ready if called from autostart
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:1
    # Give XFCE a moment to fully initialize
    sleep 3
fi

# Clean up any stale lock files
rm -f ~/.config/Code/lock 2>/dev/null
rm -f ~/.config/Code/*.lock 2>/dev/null
rm -f ~/.config/Code/Crashpad/lock 2>/dev/null

# Run VS Code in background if launched from autostart (no terminal)
if [ "$1" == "--autostart" ]; then
    nohup /usr/bin/code \
        --no-sandbox \
        --disable-gpu \
        --disable-dev-shm-usage \
        --force-renderer-accessibility \
        --disable-setuid-sandbox \
        "$@" &>/dev/null &
else
    # Normal execution for manual launch
    exec /usr/bin/code \
        --no-sandbox \
        --disable-gpu \
        --disable-dev-shm-usage \
        --force-renderer-accessibility \
        --disable-setuid-sandbox \
        "$@"
fi
WRAPPER
    
    chmod +x "$USER_HOME/.local/bin/vscode-vnc"
    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.local/bin/vscode-vnc"
    
    # Update desktop launcher
    if [ -f "/usr/share/applications/code.desktop" ]; then
        sed -i "s|^Exec=.*|Exec=$USER_HOME/.local/bin/vscode-vnc|" /usr/share/applications/code.desktop
        log_success "VS Code launcher updated"
    fi
    
else
    log_warn "STEP 7: Skipping VS Code installation"
fi

# ============================================================================
# STEP 8: OPTIONAL - INSTALL CHROME
# ============================================================================

if [[ "$INSTALL_CODE" == "yes" ]] || [[ "$INSTALL_CODE" == "y" ]]; then
    log_section "STEP 8: Installing Google Chrome"
    
    if command -v google-chrome-stable &>/dev/null; then
        log_success "Google Chrome already installed"
    else
        log_info "Downloading & installing Google Chrome..."
        
        cd /tmp
        curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o chrome.deb || \
        wget -q https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O chrome.deb
        
        if [ -f chrome.deb ]; then
            apt install -y ./chrome.deb
            rm -f chrome.deb
            log_success "Google Chrome successfully installed"
        else
            log_warn "Failed to download Chrome, skip..."
        fi
    fi
    
    # Setup Chrome wrapper
    mkdir -p "$USER_HOME/.local/bin"
    
    cat > "$USER_HOME/.local/bin/chrome-vnc" << 'WRAPPER'
#!/usr/bin/env bash
# Chrome Wrapper for noVNC compatibility
rm -f ~/.config/google-chrome/SingletonLock 2>/dev/null
rm -f ~/.config/google-chrome/SingletonCookie 2>/dev/null
exec /usr/bin/google-chrome-stable --no-sandbox --disable-gpu --disable-dev-shm-usage "$@"
WRAPPER
    
    chmod +x "$USER_HOME/.local/bin/chrome-vnc"
    chown "$TARGET_USER:$TARGET_USER" "$USER_HOME/.local/bin/chrome-vnc"
    
    # Update Chrome desktop launcher
    for desktop_file in /usr/share/applications/google-chrome*.desktop; do
        if [ -f "$desktop_file" ]; then
            sed -i "s|^Exec=.*|Exec=$USER_HOME/.local/bin/chrome-vnc|" "$desktop_file"
        fi
    done
    log_success "Chrome launcher updated"
    
else
    log_warn "STEP 8: Skipping Google Chrome installation"
fi

# ============================================================================
# STEP 9: FIREWALL CONFIGURATION
# ============================================================================

log_section "STEP 9: Firewall Configuration"

if command -v ufw &>/dev/null; then
    if sudo ufw status | grep -q "Status: inactive"; then
        log_info "UFW inactive, enable it? (y/n)"
        read -r -t 5 enable_ufw || enable_ufw="y"
        if [[ "$enable_ufw" == "y" ]]; then
            ufw --force enable
            log_success "UFW enabled"
        fi
    fi
    
    # Add rules
    ufw allow 6080/tcp 2>/dev/null || true
    ufw allow 5900/tcp 2>/dev/null || true
    ufw allow 22/tcp 2>/dev/null || true
    
    log_success "Firewall rules configured"
else
    log_warn "UFW not installed, firewall skip"
fi

# ============================================================================
# STEP 10: SYSTEMD SERVICE ACTIVATION
# ============================================================================

log_section "STEP 10: Systemd Service Activation"

systemctl daemon-reload
log_success "Systemd reloaded"

if systemctl is-enabled vps-gui &>/dev/null; then
    log_info "Service already enabled, restarting..."
    systemctl restart vps-gui
else
    log_info "Enabling service for auto-start..."
    systemctl enable vps-gui
    log_success "Service enabled"
fi

log_info "Starting service..."
systemctl start vps-gui
sleep 3

log_info "Checking service status..."
if systemctl is-active --quiet vps-gui; then
    log_success "Service is running!"
else
    log_error "Service failed to start"
    systemctl status vps-gui --no-pager || true
fi

# ============================================================================
# STEP 11: VERIFICATION & TESTING
# ============================================================================

log_section "STEP 11: Verification & Testing"

# Check X server
if xdpyinfo -display "$DISPLAY_NUM" &>/dev/null; then
    log_success "X server running on $DISPLAY_NUM"
else
    log_warn "X server not responding yet, wait..."
    sleep 5
    if xdpyinfo -display "$DISPLAY_NUM" &>/dev/null; then
        log_success "X server running on $DISPLAY_NUM"
    fi
fi

# Check ports
log_info "Checking ports..."
if ss -tlnp 2>/dev/null | grep -q :6080; then
    log_success "Port 6080 (noVNC) listening"
else
    log_warn "Port 6080 not responding yet"
fi

if ss -tlnp 2>/dev/null | grep -q :5900; then
    log_success "Port 5900 (VNC) listening"
else
    log_warn "Port 5900 not responding yet"
fi

# Get IP address
SERVER_IP=$(curl -s ifconfig.me 2>/dev/null || hostname -I | awk '{print $1}')

# ============================================================================
# STEP 12: OPTIONAL - SETUP VNC PASSWORD
# ============================================================================

log_section "STEP 12: Optional - Setup VNC Password"

log_info "VNC Password Setup (Optional - Recommended for security)"
log_info "Do you want to set a VNC password? (y/n) [default: n]"

read -r -t 10 setup_password || setup_password="n"

if [[ "$setup_password" == "y" || "$setup_password" == "Y" ]]; then
    log_info "Setting VNC password..."
    
    # Stop service
    systemctl stop vps-gui
    sleep 2
    
    # Prompt for password
    echo "Enter VNC password (will be hidden):"
    read -s -r vnc_password
    echo ""
    echo "Confirm password (will be hidden):"
    read -s -r vnc_password_confirm
    echo ""
    
    if [ "$vnc_password" != "$vnc_password_confirm" ]; then
        log_error "Passwords do not match! Skipping password setup"
    else
        # Generate password file for the user
        if sudo -u "$TARGET_USER" x11vnc -storepasswd "$vnc_password" "$VNC_DIR/passwd" 2>/dev/null; then
            chmod 600 "$VNC_DIR/passwd"
            chown "$TARGET_USER:$TARGET_USER" "$VNC_DIR/passwd"
            
            # Update service to use password authentication
            sed -i 's/-nopw/-rfbauth '"$VNC_DIR"'\/passwd/g' /etc/systemd/system/vps-gui.service
            
            # Reload and restart
            systemctl daemon-reload
            systemctl start vps-gui
            sleep 3
            
            log_success "VNC password set successfully!"
            log_info "Password file: $VNC_DIR/passwd"
        else
            log_error "Failed to set password, using no-password mode"
            systemctl start vps-gui
        fi
    fi
else
    log_warn "STEP 12: Skipping password setup (using no-password mode)"
    log_warn "To set password later, run: sudo bash setpw.sh"
fi

# ============================================================================
# STEP 13: OPTIONAL - NGINX PROXY SETUP
# ============================================================================

log_section "STEP 13: Optional - Nginx Proxy Setup"

# Check if port 6969 is available
PORT_PROXY=6969
PORT_LOCAL=8081

if ss -tlnp 2>/dev/null | grep -q ":$PORT_PROXY "; then
    log_warn "Port $PORT_PROXY is already in use"
    read -p "Enter different proxy port [default: skip]: " -t 10 -r PROXY_PORT_INPUT
    
    if [ -n "$PROXY_PORT_INPUT" ]; then
        # Validate port
        if [[ "$PROXY_PORT_INPUT" =~ ^[0-9]+$ ]] && [ "$PROXY_PORT_INPUT" -ge 1 ] && [ "$PROXY_PORT_INPUT" -le 65535 ]; then
            PORT_PROXY="$PROXY_PORT_INPUT"
            log_info "Using custom proxy port: $PORT_PROXY"
        else
            log_error "Invalid port number, skipping nginx setup"
            PORT_PROXY=""
        fi
    else
        log_warn "Skipping nginx proxy setup (port $PORT_PROXY already in use)"
        PORT_PROXY=""
    fi
fi

if [ -n "$PORT_PROXY" ]; then
    # Check if port is still available after user input
    if ss -tlnp 2>/dev/null | grep -q ":$PORT_PROXY "; then
        log_error "Port $PORT_PROXY is also in use, skipping nginx setup"
    else
        # Install nginx if not already installed
        if ! command -v nginx &> /dev/null; then
            log_info "Installing nginx..."
            sudo apt-get update > /dev/null 2>&1
            sudo apt-get install -y nginx > /dev/null 2>&1
            log_success "nginx installed"
        else
            log_info "nginx already installed"
        fi
        
        # Create nginx proxy configuration
        log_info "Configuring nginx proxy..."
        
        NGINX_CONFIG="/etc/nginx/sites-available/vps-gui-proxy"
        
        sudo tee "$NGINX_CONFIG" > /dev/null <<'NGINX_EOF'
server {
    listen PORT_PROXY default_server;
    listen [::]:PORT_PROXY default_server;

    root /var/www/html;
    index index.html index.htm index.nginx-debian.html;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:PORT_LOCAL;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
NGINX_EOF
        
        # Replace placeholders
        sudo sed -i "s/PORT_PROXY/$PORT_PROXY/g" "$NGINX_CONFIG"
        sudo sed -i "s/PORT_LOCAL/$PORT_LOCAL/g" "$NGINX_CONFIG"
        
        # Enable site
        if [ ! -L "/etc/nginx/sites-enabled/vps-gui-proxy" ]; then
            sudo ln -s "$NGINX_CONFIG" "/etc/nginx/sites-enabled/vps-gui-proxy"
            log_info "Enabled nginx site"
        fi
        
        # Disable default site if needed
        if [ -L "/etc/nginx/sites-enabled/default" ]; then
            sudo rm "/etc/nginx/sites-enabled/default"
        fi
        
        # Test nginx configuration
        if sudo nginx -t > /dev/null 2>&1; then
            log_success "nginx configuration valid"
            
            # Enable and start nginx
            sudo systemctl enable nginx > /dev/null 2>&1
            sudo systemctl restart nginx > /dev/null 2>&1
            log_success "nginx started"
            
            # Verify service
            if sudo systemctl is-active --quiet nginx; then
                log_success "Nginx proxy setup complete!"
                log_info "Access via: http://$SERVER_IP:$PORT_PROXY"
                NGINX_CONFIGURED=1
            else
                log_error "nginx failed to start"
                NGINX_CONFIGURED=0
            fi
        else
            log_error "nginx configuration invalid, skipping"
            NGINX_CONFIGURED=0
        fi
    fi
else
    log_warn "STEP 13: Skipping nginx proxy setup"
    NGINX_CONFIGURED=0
fi

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
echo "  Server IP     : $SERVER_IP"
echo ""
echo -e "${CYAN}🌐 Access Information:${NC}"
echo "  Browser URL   : ${GREEN}http://$SERVER_IP:6080${NC}"
echo "  VNC Direct    : ${GREEN}vnc://$SERVER_IP:5900${NC}"
if [ "${NGINX_CONFIGURED:-0}" -eq 1 ]; then
    echo "  Nginx Proxy   : ${GREEN}http://$SERVER_IP:$PORT_PROXY${NC}${YELLOW} (Alternative access)${NC}"
fi
echo ""
echo -e "${CYAN}🚀 Next Steps:${NC}"
echo "  1. Open browser: http://$SERVER_IP:6080"
echo "  2. Click 'Connect' button"
echo "  3. XFCE desktop should appear in 10-20 seconds"
echo "  4. Check Applications menu for VS Code & Chrome"
echo ""
echo -e "${CYAN}📖 Useful Commands:${NC}"
echo "  # Check service status"
echo "  sudo systemctl status vps-gui"
echo ""
echo "  # View logs"
echo "  sudo journalctl -u vps-gui -n 50 -f"
echo ""
echo "  # Restart service"
echo "  sudo systemctl restart vps-gui"
echo ""
echo "  # Full cleanup & reset"
echo "  sudo bash cleanup.sh"
echo ""
echo "  # Nginx proxy management (if configured)"
echo "  sudo systemctl status nginx"
echo "  sudo systemctl restart nginx"
echo ""
echo "  # Run this script again for updates/fixes"
echo "  sudo bash auto-install.sh $TARGET_USER yes"
echo ""
echo "  # Repository:"
echo "  https://github.com/asepindrak/vps-gui-noVnc"
echo ""
echo ""
echo -e "${YELLOW}💡 TIPS:${NC}"
echo "  • Wait 10-20 seconds after first connect"
echo "  • If desktop not showing, refresh browser (F5)"
if [ "$USE_EXISTING_DISPLAY" = true ]; then
    echo "  • Changes are visible on your local monitor (POP OS/Ubuntu Desktop mode)"
    echo "  • You can also access remotely via: http://SERVER_IP:6080"
else
    echo "  • Use Ctrl+Alt+F2 to open terminal in XFCE"
    echo "  • Desktop will auto-restart if you close it"
fi
echo "  • Password was set during installation (or use: sudo bash setpw.sh)"
echo ""
echo -e "${NC}"
