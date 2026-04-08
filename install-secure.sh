#!/bin/bash

set -e

echo "======================================="
echo "   VPS GUI AUTO INSTALL (SECURE MODE)  "
echo "======================================="

# INPUT PASSWORD
while true; do
    read -s -p "Masukkan password VNC: " PASS1
    echo ""
    read -s -p "Konfirmasi password: " PASS2
    echo ""

    if [ "$PASS1" == "$PASS2" ]; then
        break
    else
        echo "❌ Password tidak sama, ulangi!"
    fi
done

echo "✅ Password dikonfirmasi"

echo "=== UPDATE SYSTEM ==="
apt update -y && apt upgrade -y

echo "=== INSTALL XFCE GUI ==="
apt install -y xfce4 xfce4-goodies

echo "=== INSTALL DEPENDENCIES ==="
apt install -y xvfb x11vnc novnc websockify net-tools curl

echo "=== SETUP VNC PASSWORD ==="
mkdir -p /root/.vnc
echo "$PASS1" | x11vnc -storepasswd - /root/.vnc/passwd
chmod 600 /root/.vnc/passwd

echo "=== CREATE XFCE STARTUP ==="
cat > /root/.vnc/xstartup << 'EOF'
#!/bin/bash
xrdb $HOME/.Xresources
startxfce4 &
EOF

chmod +x /root/.vnc/xstartup

echo "=== CREATE SYSTEMD SERVICE ==="
cat > /etc/systemd/system/vps-gui.service << 'EOF'
[Unit]
Description=VPS GUI Service (Secure)
After=network.target

[Service]
Type=simple
User=root

ExecStart=/bin/bash -c "\
Xvfb :1 -screen 0 1280x720x24 & \
export DISPLAY=:1 && \
startxfce4 & \
sleep 5 && \
x11vnc -display :1 -rfbauth /root/.vnc/passwd -forever -shared -rfbport 5900 & \
websockify --web=/usr/share/novnc/ 6080 localhost:5900\
"

Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== ENABLE SERVICE ==="
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable vps-gui
systemctl start vps-gui

echo "=== OPEN FIREWALL ==="
ufw allow 6080 2>/dev/null || true
ufw allow 5900 2>/dev/null || true

IP=$(curl -s ifconfig.me)

echo ""
echo "======================================="
echo "✅ INSTALL SELESAI (SECURE)"
echo "🌐 Akses: http://$IP:6080"
echo "🔐 Gunakan password yang tadi dibuat"
echo "======================================="
