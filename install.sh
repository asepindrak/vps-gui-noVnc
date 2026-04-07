#!/bin/bash
set -e

# Cek hak akses root
if [ "$EUID" -ne 0 ]; then
  echo "❌ Error: Jalankan script ini sebagai root (gunakan: sudo -i)"
  exit 1
fi

echo "==================================================="
echo "🖥️  VPS GUI Setup: XFCE + Xvfb + x11vnc + noVNC"
echo "==================================================="

# 1. Input Password VNC
read -p "🔑 Masukkan password VNC (min 6 karakter): " VNC_PASS
if [ ${#VNC_PASS} -lt 6 ]; then
  echo "❌ Password minimal 6 karakter. Keluar..."
  exit 1
fi

# 2. Update & Install Paket
echo "[1/5] Updating & Installing packages..."
apt update -y
apt install -y xfce4 xfce4-goodies xvfb x11vnc novnc websockify \
  wget curl dbus-x11 xdg-utils ufw policykit-1-gnome

# 3. Setup Password x11vnc
mkdir -p /root/.vnc
x11vnc -storepasswd "$VNC_PASS" /root/.vnc/passwd

# 4. Buat Service Systemd
echo "[2/5] Creating systemd services..."

# Xvfb (Virtual Display)
cat > /etc/systemd/system/xvfb.service <<EOF
[Unit]
Description=Xvfb Virtual Framebuffer
After=network.target

[Service]
ExecStart=/usr/bin/Xvfb :1 -screen 0 1280x720x24 +extension GLX +render -noreset
Restart=always
User=root

[Install]
WantedBy=multi-user.target
EOF

# XFCE Desktop Session
cat > /etc/systemd/system/xfce-desktop.service <<EOF
[Unit]
Description=XFCE Desktop Session on Xvfb
After=xvfb.service
Wants=xvfb.service

[Service]
Type=simple
Environment=DISPLAY=:1
Environment=XDG_RUNTIME_DIR=/run/user/0
Environment=XDG_DATA_DIRS=/usr/share/xfce4:/usr/local/share:/usr/share
ExecStartPre=/bin/bash -c 'mkdir -p /run/user/0 && chmod 700 /run/user/0'
ExecStart=/bin/bash -c 'exec startxfce4'
User=root
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

# x11vnc Server
cat > /etc/systemd/system/x11vnc.service <<EOF
[Unit]
Description=x11vnc Server
After=xfce-desktop.service
Wants=xfce-desktop.service

[Service]
Environment=DISPLAY=:1
ExecStart=/usr/bin/x11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -shared -noxdamage -bg
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# noVNC + Websockify
cat > /etc/systemd/system/novnc.service <<EOF
[Unit]
Description=noVNC Web Interface
After=x11vnc.service
Wants=x11vnc.service

[Service]
ExecStart=/usr/bin/websockify --web /usr/share/novnc 6080 localhost:5900
Restart=on-failure
User=root

[Install]
WantedBy=multi-user.target
EOF

# 5. Enable & Start Services
echo "[3/5] Enabling & Starting services..."
systemctl daemon-reload
systemctl enable xvfb.service xfce-desktop.service x11vnc.service novnc.service

systemctl start xvfb.service
sleep 3
systemctl start xfce-desktop.service
sleep 4
systemctl start x11vnc.service
sleep 2
systemctl start novnc.service

# 6. Firewall Setup
echo "[4/5] Configuring Firewall..."
ufw --force enable
ufw allow 22/tcp
ufw allow 6080/tcp

echo "[5/5] Setup Complete! ✅"
echo "==================================================="
echo "🌐 Akses noVNC via browser:"
echo "http://<IP_VPS_ANDA>:6080"
echo "🔑 Password VNC: $VNC_PASS"
echo "==================================================="
echo "💡 Catatan:"
echo "  - Jika layar hitam/abu-abu, tunggu 10-15 detik & refresh."
echo "  - Services otomatis jalan saat reboot."
echo "  - Ubah password nanti: sudo x11vnc -storepasswd /root/.vnc/passwd"
echo "==================================================="
