#!/bin/bash
# VPS GUI + XFCE + x11vnc + NoVNC Auto Install (Headless)
# User VPS: getechindonesia
# VNC Password: Qwertieser123!@

set -e

USER="getechindonesia"
VNC_PASS="Qwertieser123!@"
DISPLAY_NUM=":1"
VNC_PORT="5900"
NOVNC_PORT="6080"

echo "=== Update & Upgrade System ==="
sudo apt update && sudo apt upgrade -y

echo "=== Install XFCE Desktop + Xvfb + x11vnc + NoVNC ==="
sudo apt install -y xfce4 xfce4-goodies xvfb x11vnc novnc websockify

echo "=== Set VNC Password ==="
mkdir -p /home/$USER/.vnc
x11vnc -storepasswd $VNC_PASS /home/$USER/.vnc/passwd
chown -R $USER:$USER /home/$USER/.vnc
chmod 600 /home/$USER/.vnc/passwd

echo "=== Create systemd service for Xvfb + XFCE ==="
sudo tee /etc/systemd/system/xfce-vps.service > /dev/null <<EOF
[Unit]
Description=Start XFCE Desktop on virtual display
After=network.target

[Service]
Type=simple
User=$USER
Environment=DISPLAY=$DISPLAY_NUM
ExecStart=/usr/bin/startxfce4
Restart=on-failure

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
ExecStart=/usr/bin/x11vnc -display $DISPLAY_NUM -rfbauth /home/$USER/.vnc/passwd -forever -shared -nopw -bg
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
ExecStart=/usr/bin/websockify --web=/usr/share/novnc/ $NOVNC_PORT 0.0.0.0:$VNC_PORT --password=$VNC_PASS
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
sleep 5
sudo systemctl start novnc.service

echo "=== Setup Complete ==="
echo "VNC Server: $VNC_PORT"
echo "NoVNC Web URL: http://$(curl -s ifconfig.me):$NOVNC_PORT"
echo "Password: $VNC_PASS"
