#!/bin/bash
# Auto Install XFCE + Xvfb + x11vnc + NoVNC + Systemd Services
# User VPS: getechindonesia
# VNC Password: Qwertieser123!

set -e

USER="getechindonesia"
VNC_PASS="Qwertieser123!"
DISPLAY_NUM=":1"
VNC_PORT="5900"
NOVNC_PORT="6080"

echo "=== Update & Install Packages ==="
sudo apt update && sudo apt upgrade -y
sudo apt install -y xfce4 xfce4-goodies xvfb dbus-x11 x11vnc novnc websockify

echo "=== Set VNC Password ==="
mkdir -p /home/$USER/.vnc
echo $VNC_PASS | x11vnc -storepasswd -f /home/$USER/.vnc/passwd
chown -R $USER:$USER /home/$USER/.vnc
chmod 600 /home/$USER/.vnc/passwd

echo "=== Create XFCE Systemd Service ==="
sudo tee /etc/systemd/system/xfce-vps.service > /dev/null <<EOF
[Unit]
Description=Start XFCE Desktop on virtual display
After=network.target
StartLimitIntervalSec=0

[Service]
Type=forking
User=$USER
Environment=DISPLAY=$DISPLAY_NUM
ExecStartPre=/bin/bash -c 'if pgrep Xvfb; then echo "Xvfb already running"; else Xvfb $DISPLAY_NUM -screen 0 1280x720x24 & sleep 2; fi'
ExecStart=/bin/bash -c 'eval \$(dbus-launch) && startxfce4'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Create x11vnc Service ==="
sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<EOF
[Unit]
Description=x11vnc Server
After=xfce-vps.service network.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=$USER
Environment=DISPLAY=$DISPLAY_NUM
ExecStart=/usr/bin/x11vnc -display $DISPLAY_NUM -rfbauth /home/$USER/.vnc/passwd -forever -shared
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Create NoVNC Service ==="
sudo tee /etc/systemd/system/novnc.service > /dev/null <<EOF
[Unit]
Description=NoVNC WebSocket Proxy
After=network.target x11vnc.service
StartLimitIntervalSec=0

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT --password=$VNC_PASS
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reload systemd & Enable Services ==="
sudo systemctl daemon-reload
sudo systemctl enable xfce-vps.service
sudo systemctl enable x11vnc.service
sudo systemctl enable novnc.service

echo "=== Start Services ==="
sudo systemctl restart xfce-vps.service
sleep 3
sudo systemctl restart x11vnc.service
sudo systemctl restart novnc.service

echo "=== Setup Complete ==="
echo "VNC Server: $VNC_PORT"
echo "NoVNC Web URL: http://<YOUR_VPS_IP>:$NOVNC_PORT"
echo "Password: $VNC_PASS"
