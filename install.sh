#!/bin/bash

set -e

echo "=== UPDATE SYSTEM ==="
apt update -y && apt upgrade -y

echo "=== INSTALL XFCE GUI ==="
apt install -y xfce4 xfce4-goodies

echo "=== INSTALL DEPENDENCIES ==="
apt install -y xvfb x11vnc novnc websockify net-tools

echo "=== CREATE USER SESSION SCRIPT ==="
mkdir -p /root/.vnc

cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF

chmod +x /root/.vnc/xstartup

echo "=== CREATE SYSTEMD SERVICE ==="

cat > /etc/systemd/system/vps-gui.service << 'EOF'
[Unit]
Description=VPS GUI Service (Xvfb + XFCE + x11vnc + noVNC)
After=network.target

[Service]
Type=simple
User=root

ExecStart=/bin/bash -c "\
Xvfb :1 -screen 0 1280x720x24 & \
export DISPLAY=:1 && \
startxfce4 & \
sleep 5 && \
x11vnc -display :1 -nopw -forever -shared -rfbport 5900 & \
websockify --web=/usr/share/novnc/ 6080 localhost:5900\
"

Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== RELOAD SYSTEMD ==="
systemctl daemon-reexec
systemctl daemon-reload

echo "=== ENABLE & START SERVICE ==="
systemctl enable vps-gui
systemctl start vps-gui

echo "=== OPEN FIREWALL (if UFW exists) ==="
ufw allow 6080 || true
ufw allow 5900 || true

IP=$(curl -s ifconfig.me)

echo ""
echo "======================================="
echo "✅ INSTALL SELESAI!"
echo "Akses GUI via browser:"
echo "👉 http://$IP:6080"
echo "======================================="
