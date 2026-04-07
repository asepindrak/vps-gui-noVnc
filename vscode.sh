#!/bin/bash
# Script install VSCode terbaru, Chrome terbaru, dan auto-start VSCode
# User VPS: getechindonesia

set -e

USER="getechindonesia"

echo "=== Update & Upgrade System ==="
sudo apt update && sudo apt upgrade -y

# -------------------------------------------------
# 1️⃣ Install dependencies
sudo apt install -y wget gpg apt-transport-https software-properties-common

# -------------------------------------------------
# 2️⃣ Install VSCode terbaru
echo "=== Installing VSCode ==="
wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor > packages.microsoft.gpg
sudo install -o root -g root -m 644 packages.microsoft.gpg /usr/share/keyrings/
sudo sh -c 'echo "deb [arch=amd64 signed-by=/usr/share/keyrings/packages.microsoft.gpg] https://packages.microsoft.com/repos/code stable main" > /etc/apt/sources.list.d/vscode.list'
sudo apt update
sudo apt install -y code

# -------------------------------------------------
# 3️⃣ Install Google Chrome terbaru
echo "=== Installing Google Chrome ==="
wget https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -O /tmp/google-chrome.deb
sudo apt install -y /tmp/google-chrome.deb
rm /tmp/google-chrome.deb

# -------------------------------------------------
# 4️⃣ Create systemd service to auto-start VSCode
echo "=== Creating systemd service for auto-start VSCode ==="
sudo tee /etc/systemd/system/vscode.service > /dev/null <<EOF
[Unit]
Description=Auto Start VSCode
After=graphical.target

[Service]
Type=simple
User=$USER
ExecStart=/usr/bin/code --no-sandbox --unity-launch
Restart=on-failure

[Install]
WantedBy=graphical.target
EOF

# Reload systemd and enable VSCode service
sudo systemctl daemon-reload
sudo systemctl enable vscode.service
sudo systemctl start vscode.service

echo "=== Installation Complete ==="
echo "VSCode and Google Chrome installed."
echo "VSCode will auto-start on reboot."
