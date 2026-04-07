#!/bin/bash
# VPS GUI + XFCE + Xvfb + x11vnc + noVNC
# User VPS: getechindonesia
# VNC Password: Qwertieser123!

set -e

USER="getechindonesia"
VNC_PASS="Qwertieser123!"
DISPLAY_NUM=":1"
VNC_PORT="5900"
NOVNC_PORT="6080"

echo "=== Update & Upgrade System ==="
sudo apt update && sudo apt upgrade -y

echo "=== Install XFCE Desktop + Dependencies ==="
sudo apt install -y xfce4 xfce4-goodies dbus-x11 x11vnc novnc websockify xvfb

echo "=== Set VNC Password ==="
mkdir -p /home/$USER/.vnc
echo $VNC_PASS | x11vnc -storepasswd -f /home/$USER/.vnc/passwd
chown -R $USER:$USER /home/$USER/.vnc
chmod 600 /home/$USER/.vnc/passwd

echo "=== Create systemd service for XFCE + Xvfb ==="
sudo tee /etc/systemd/system/xfce-vps.service > /dev/null <<EOF
[Unit]
Description=Start XFCE Desktop on virtual display
After=network.target
StartLimitIntervalSec=0

[Service]
Type=forking
User=$USER
Environment=DISPLAY=$DISPLAY_NUM
ExecStartPre=/usr/bin/Xvfb $DISPLAY_NUM -screen 0 1280x720x24
ExecStart=/usr/bin/dbus-launch startxfce4
Restart=always

[Install]
WantedBy=multi-user.target
EOF

echo "=== Create systemd service for x11vnc ==="
sudo tee /etc/systemd/system/x11vnc.service > /dev/null <<EOF
[Unit]
Description=x11vnc Server
After=xfce-vps.service network.target
Requires=xfce-vps.service

[Service]
Type=simple
User=$USER
Environment=DISPLAY=$DISPLAY_NUM
ExecStartPre=/bin/sleep 5
ExecStart=/usr/bin/x11vnc -display $DISPLAY_NUM -rfbauth /home/$USER/.vnc/passwd -forever -shared -bg -o /home/$USER/x11vnc.log
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== Create systemd service for NoVNC ==="
sudo tee /etc/systemd/system/novnc.service > /dev/null <<EOF
[Unit]
Description=NoVNC WebSocket Proxy
After=network.target x11vnc.service
Requires=x11vnc.service

[Service]
Type=simple
User=$USER
Environment=DISPLAY=$DISPLAY_NUM
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ $NOVNC_PORT localhost:$VNC_PORT --password=$VNC_PASS
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo "=== Reload systemd daemon & enable services ==="
sudo systemctl daemon-reload
sudo systemctl enable xfce-vps.service
sudo systemctl enable x11vnc.service
sudo systemctl enable novnc.service

echo "=== Start Services ==="
sudo systemctl start xfce-vps.service
sleep 5
sudo systemctl start x11vnc.service
sudo systemctl start novnc.service

echo "=== Setup Complete ==="
echo "VNC Server: $VNC_PORT"
echo "NoVNC Web URL: http://<YOUR_VPS_IP>:$NOVNC_PORT"
echo "Password: $VNC_PASS"
