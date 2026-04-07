#!/bin/bash
#===============================================================================
# 🖥️  VPS GUI Auto Installer: XFCE + Xvfb + x11vnc + noVNC + Systemd
# ✅ Support: Ubuntu 22.04/24.04 LTS, Debian 11/12
# ✅ Fitur: Auto-start at boot, user non-root, firewall, redirect index.html
# ✅ Tested: Root & sudo access
#===============================================================================
set -e

# Warna output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_err()  { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Cek hak akses
if [ "$EUID" -ne 0 ]; then
  log_err "Jalankan script ini sebagai root (sudo -i)"
fi

#-------------------------------------------------------------------------------
# 📥 INPUT KONFIGURASI
#-------------------------------------------------------------------------------
echo "============================================================"
echo "🖥️  VPS GUI Auto Installer"
echo "============================================================"

# Input username (default: getechindonesia)
read -p "👤 Masukkan username VPS (default: getechindonesia): " INPUT_USER
VPS_USER="${INPUT_USER:-getechindonesia}"

# Cek user ada/tidak
if ! id "$VPS_USER" &>/dev/null; then
  log_warn "User '$VPS_USER' tidak ditemukan. Membuat user baru..."
  adduser --disabled-password --gecos "" "$VPS_USER"
  echo "$VPS_USER ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$VPS_USER
  chmod 0440 /etc/sudoers.d/$VPS_USER
fi

# Input password VNC
read -p "🔑 Masukkan password VNC (min 6 karakter): " VNC_PASS
if [ ${#VNC_PASS} -lt 6 ]; then
  log_err "Password minimal 6 karakter!"
fi

# Konfigurasi default
DISPLAY_NUM=":1"
VNC_PORT="5900"
NOVNC_PORT="6080"
RESOLUTION="1280x720x24"
HOME_DIR="/home/$VPS_USER"

#-------------------------------------------------------------------------------
# 📦 1. UPDATE & INSTALL PACKAGES
#-------------------------------------------------------------------------------
log_info "Updating system & installing packages..."
apt update -y && apt upgrade -y
apt install -y xfce4 xfce4-goodies xvfb dbus-x11 x11vnc novnc websockify \
  wget curl ufw policykit-1-gnome xdg-utils gnome-icon-theme

#-------------------------------------------------------------------------------
# 🔐 2. SETUP VNC PASSWORD & PERMISSION
#-------------------------------------------------------------------------------
log_info "Setting up VNC password..."
mkdir -p "$HOME_DIR/.vnc"
echo "$VNC_PASS" | x11vnc -storepasswd -f "$HOME_DIR/.vnc/passwd"
chown -R "$VPS_USER:$VPS_USER" "$HOME_DIR/.vnc"
chmod 600 "$HOME_DIR/.vnc/passwd"

# Setup Xauthority
touch "$HOME_DIR/.Xauthority"
chown "$VPS_USER:$VPS_USER" "$HOME_DIR/.Xauthority"

#-------------------------------------------------------------------------------
# ⚙️ 3. CREATE SYSTEMD SERVICES
#-------------------------------------------------------------------------------
log_info "Creating systemd services..."

# ➤ xvfb.service (Virtual Display)
cat > /etc/systemd/system/xvfb.service <<EOF
[Unit]
Description=Xvfb Virtual Display for $VPS_USER
After=network.target

[Service]
User=$VPS_USER
ExecStart=/usr/bin/Xvfb $DISPLAY_NUM -screen 0 $RESOLUTION +extension GLX +render -noreset
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ➤ xfce-desktop.service (Desktop Session)
cat > /etc/systemd/system/xfce-desktop.service <<EOF
[Unit]
Description=XFCE Desktop Session for $VPS_USER
After=xvfb.service
Wants=xvfb.service

[Service]
User=$VPS_USER
Type=simple
Environment=DISPLAY=$DISPLAY_NUM
Environment=XDG_RUNTIME_DIR=/run/user/\$(id -u $VPS_USER)
Environment=XDG_SESSION_TYPE=x11
Environment=XDG_DATA_DIRS=/usr/share/xfce4:/usr/local/share:/usr/share
ExecStartPre=/bin/bash -c 'mkdir -p /run/user/\$(id -u $VPS_USER) && chmod 700 /run/user/\$(id -u $VPS_USER)'
ExecStartPre=/bin/sleep 2
ExecStart=/usr/bin/dbus-launch --exit-with-session /usr/bin/startxfce4
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# ➤ x11vnc.service (VNC Server)
cat > /etc/systemd/system/x11vnc.service <<EOF
[Unit]
Description=x11vnc Server for $VPS_USER
After=xfce-desktop.service
Wants=xfce-desktop.service

[Service]
User=$VPS_USER
Environment=DISPLAY=$DISPLAY_NUM
Environment=XAUTHORITY=$HOME_DIR/.Xauthority
ExecStart=/usr/bin/x11vnc -display $DISPLAY_NUM -rfbauth $HOME_DIR/.vnc/passwd -forever -shared -noxdamage -auth guess -xkb -bg
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

# ➤ novnc.service (Web Interface)
cat > /etc/systemd/system/novnc.service <<EOF
[Unit]
Description=noVNC Web Interface for $VPS_USER
After=x11vnc.service
Wants=x11vnc.service

[Service]
User=$VPS_USER
ExecStart=/usr/bin/websockify --web=/usr/share/novnc $NOVNC_PORT localhost:$VNC_PORT
Restart=on-failure
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

#-------------------------------------------------------------------------------
# 🚀 4. ENABLE & START SERVICES
#-------------------------------------------------------------------------------
log_info "Enabling & starting services..."
systemctl daemon-reload
systemctl enable xvfb.service xfce-desktop.service x11vnc.service novnc.service

# Start berurutan dengan delay
systemctl start xvfb.service
sleep 3
systemctl start xfce-desktop.service
sleep 4
systemctl start x11vnc.service
sleep 2
systemctl start novnc.service

#-------------------------------------------------------------------------------
# 🔥 5. FIREWALL SETUP
#-------------------------------------------------------------------------------
log_info "Configuring firewall..."
if command -v ufw &>/dev/null; then
  ufw --force enable
  ufw allow 22/tcp comment "SSH"
  ufw allow $NOVNC_PORT/tcp comment "noVNC Web"
  log_info "Firewall: Port 22 & $NOVNC_PORT opened"
else
  log_warn "UFW tidak terinstal. Pastikan port $NOVNC_PORT terbuka di provider firewall."
fi

#-------------------------------------------------------------------------------
# 🌐 6. AUTO-REDIRECT INDEX.HTML (Opsional)
#-------------------------------------------------------------------------------
log_info "Creating auto-redirect index.html..."
cat > /usr/share/novnc/index.html <<EOF
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <meta http-equiv="refresh" content="0; url=vnc.html">
  <title>Redirecting to noVNC...</title>
  <style>
    body { font-family: sans-serif; text-align: center; padding: 50px; background: #1a1a2e; color: #eee; }
    a { color: #4cc9f0; text-decoration: none; }
  </style>
</head>
<body>
  <h2>🖥️ VPS GUI Ready!</h2>
  <p>Redirecting to <a href="vnc.html">noVNC</a>...</p>
  <p><small>Jika tidak redirect otomatis, klik <a href="vnc.html">di sini</a></small></p>
</body>
</html>
EOF

#-------------------------------------------------------------------------------
# ✅ 7. VERIFICATION & OUTPUT
#-------------------------------------------------------------------------------
log_info "Verifying services..."
sleep 5

# Cek port
if ss -tlnp | grep -q ":$VNC_PORT "; then
  log_info "✅ x11vnc listening on port $VNC_PORT"
else
  log_warn "⚠️ x11vnc mungkin belum ready. Cek: journalctl -u x11vnc -e"
fi

if ss -tlnp | grep -q ":$NOVNC_PORT "; then
  log_info "✅ noVNC listening on port $NOVNC_PORT"
else
  log_warn "⚠️ noVNC mungkin belum ready. Cek: journalctl -u novnc -e"
fi

# Status service
echo ""
echo "📊 Service Status:"
for svc in xvfb xfce-desktop x11vnc novnc; do
  status=$(systemctl is-active $svc.service 2>/dev/null || echo "inactive")
  echo "  • $svc: $status"
done

#-------------------------------------------------------------------------------
# 🎉 FINAL OUTPUT
#-------------------------------------------------------------------------------
echo ""
echo "============================================================"
echo -e "${GREEN}✅ INSTALLATION COMPLETE!${NC}"
echo "============================================================"
echo "🌐 Akses noVNC via browser:"
echo "   http://<IP_VPS_ANDA>:$NOVNC_PORT"
echo "   (atau langsung: http://<IP_VPS_ANDA>:$NOVNC_PORT/vnc.html)"
echo ""
echo "🔑 VNC Password: $VNC_PASS"
echo "👤 User: $VPS_USER"
echo "🖥️  Display: $DISPLAY_NUM | Resolusi: ${RESOLUTION%*x*}"
echo ""
echo "🔧 Perintah Berguna:"
echo "   • Cek log: journalctl -u xfce-desktop -e --no-pager"
echo "   • Restart GUI: sudo systemctl restart xfce-desktop x11vnc novnc"
echo "   • Ganti password: x11vnc -storepasswd -f $HOME_DIR/.vnc/passwd"
echo "   • Cek port: ss -tlnp | grep -E '$VNC_PORT|$NOVNC_PORT'"
echo ""
echo "⚠️  Tips:"
echo "   • Jika layar hitam, tunggu 10-15 detik lalu refresh browser"
echo "   • Untuk HTTPS, setup reverse proxy Nginx/Caddy + SSL"
echo "   • Services otomatis start saat reboot (auto-run enabled)"
echo "============================================================"
