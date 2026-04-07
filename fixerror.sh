# 1. STOP semua service terkait
sudo systemctl stop novnc x11vnc xfce-desktop xvfb

# 2. KILL proses yang masih nyangkut
sudo pkill -9 -f "Xvfb.*:1" 2>/dev/null || true
sudo pkill -9 -f "x11vnc.*:1" 2>/dev/null || true
sudo pkill -9 -f "websockify" 2>/dev/null || true

# 3. HAPUS lock file & socket X11 yang stale (PENTING!)
sudo rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/.X11-unix/.X1-lock

# 4. FIX permission Xauthority
sudo chown getechindonesia:getechindonesia /home/getechindonesia/.Xauthority
sudo chmod 600 /home/getechindonesia/.Xauthority

# 5. PERBAIKI xfce-desktop.service (hapus command substitution yang invalid)
sudo tee /etc/systemd/system/xfce-desktop.service > /dev/null <<'EOF'
[Unit]
Description=XFCE Desktop Session for getechindonesia
After=xvfb.service
Wants=xvfb.service
Before=x11vnc.service

[Service]
User=getechindonesia
Type=simple
Environment=DISPLAY=:1
Environment=XDG_RUNTIME_DIR=/run/user/1000
Environment=XDG_SESSION_TYPE=x11
Environment=XDG_DATA_DIRS=/usr/share/xfce4:/usr/local/share:/usr/share
Environment=XAUTHORITY=/home/getechindonesia/.Xauthority
ExecStartPre=/bin/sleep 3
ExecStart=/usr/bin/dbus-launch --exit-with-session /usr/bin/startxfce4
Restart=on-failure
RestartSec=5
TimeoutStartSec=60

[Install]
WantedBy=multi-user.target
EOF

# 6. PERBAIKI x11vnc.service (gunakan -auth explicit, hapus -auth guess)
sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<'EOF'
[Unit]
Description=x11vnc Server for getechindonesia
After=xfce-desktop.service
Wants=xfce-desktop.service
Before=novnc.service

[Service]
User=getechindonesia
Environment=DISPLAY=:1
Environment=XAUTHORITY=/home/getechindonesia/.Xauthority
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/x11vnc -display :1 -rfbauth /home/getechindonesia/.vnc/passwd -forever -shared -noxdamage -auth /home/getechindonesia/.Xauthority -xkb -bg -repeat -nowf
Restart=on-failure
RestartSec=3
TimeoutStartSec=90

[Install]
WantedBy=multi-user.target
EOF

# 7. PERBAIKI xvfb.service (tambah -auth flag)
sudo tee /etc/systemd/system/xvfb.service > /dev/null <<'EOF'
[Unit]
Description=Xvfb Virtual Display for getechindonesia
After=network.target
Before=xfce-desktop.service

[Service]
User=getechindonesia
ExecStart=/usr/bin/Xvfb :1 -screen 0 1280x720x24 +extension GLX +render -noreset -auth /home/getechindonesia/.Xauthority
Restart=on-failure
RestartSec=3
TimeoutStartSec=30

[Install]
WantedBy=multi-user.target
EOF

# 8. RELOAD systemd & START berurutan
sudo systemctl daemon-reload

sudo systemctl start xvfb
sleep 4
# Verifikasi Xvfb running
pgrep -f "Xvfb.*:1" && echo "✅ Xvfb OK" || { echo "❌ Xvfb failed"; journalctl -u xvfb -n 5; }

sudo systemctl start xfce-desktop
sleep 6
# Verifikasi XFCE panel
pgrep -f "xfce4-panel" && echo "✅ XFCE OK" || echo "⚠️ XFCE panel belum muncul"

sudo systemctl start x11vnc
sleep 4
# Verifikasi port 5900
ss -tlnp | grep :5900 && echo "✅ x11vnc listening" || { echo "❌ x11vnc failed"; journalctl -u x11vnc -n 10; }

sudo systemctl start novnc
sleep 2
ss -tlnp | grep :6080 && echo "✅ noVNC listening" || echo "⚠️ noVNC belum ready"

# 9. FINAL TEST
echo ""
echo "=== Final Connection Test ==="
timeout 2 bash -c "echo > /dev/tcp/localhost/5900" && echo "✅ Port 5900 reachable" || echo "❌ Port 5900 still blocked"
