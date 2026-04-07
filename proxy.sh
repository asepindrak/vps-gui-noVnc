#!/bin/bash
# Simple port forwarding 8080 -> 127.0.0.1:8080
# User VPS: getechindonesia

set -e

USER="getechindonesia"
PORT_LOCAL=8080
PORT_PUBLIC=8080

# Install socat jika belum ada
sudo apt update
sudo apt install -y socat

# Buat systemd service
sudo tee /etc/systemd/system/port8080-forward.service > /dev/null <<EOF
[Unit]
Description=Forward localhost:8080 to public 0.0.0.0:8080
After=network.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/socat TCP-LISTEN:$PORT_PUBLIC,fork TCP:127.0.0.1:$PORT_LOCAL
Restart=always

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd dan enable service
sudo systemctl daemon-reload
sudo systemctl enable port8080-forward.service
sudo systemctl start port8080-forward.service

echo "Port 8080 forwarding aktif!"
echo "Sekarang localhost:8080 di VPS bisa diakses dari luar via http://<VPS_IP>:8080"
