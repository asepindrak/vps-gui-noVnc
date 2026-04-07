#!/bin/bash
# Script Auto Install GUI + x11vnc + NoVNC + Systemd Service
# User VPS: getechindonesia
# VNC Password: Qwertieser123!@

set -e

USER="getechindonesia"
VNC_PASS="Qwertieser123!"
DISPLAY_NUM=":0"
VNC_PORT="5900"
NOVNC_PORT="6080"

echo "=== Update & Upgrade System ==="
sudo apt update && sudo apt upgrade -y

echo "=== Install XFCE Desktop ==="
sudo apt install -y xfce4 xfce4-goodies

echo "=== Install x11vnc & NoVNC ==="
sudo apt install -y x11vnc novnc websockify

echo "=== Set VNC Password ==="
mkdir -p /home/$USER/.vnc
echo $VNC_PASS | x11vnc -storepasswd -f /home/$USER/.vnc/passwd
chown -R $USER:$USER /home/$USER/.vnc
chmod 600 /home/$USER/.vnc/passwd

echo "=== Create systemd service for x11vnc ==="
sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<EOF
[Unit]
Description=x11vnc Server
After=graphical.target network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/x11vnc -usepw -forever -display $DISPLAY_NUM -rfbport $VNC_PORT
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== Create systemd service for NoVNC ==="
sudo tee /etc/systemd/system/novnc.service > /dev/null <<EOF
[Unit]
Description=NoVNC WebSocket Proxy
After=network.target x11vnc.service

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT --password=$VNC_PASS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reload systemd daemon & enable services ==="
sudo systemctl daemon-reload
sudo systemctl enable x11vnc.service
sudo systemctl enable novnc.service

echo "=== Start Services ==="
sudo systemctl start x11vnc.service
sudo systemctl start novnc.service

echo "=== Setup Complete ==="
echo "VNC Server: $VNC_PORT"
echo "NoVNC Web URL: http://<YOUR_VPS_IP>:$NOVNC_PORT"
echo "Password: $VNC_PASS"
