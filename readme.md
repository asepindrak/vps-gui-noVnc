sudo nano /etc/systemd/system/vscode-gui.service

[Unit]
Description=VSCode GUI (root)
After=network.target

[Service]
Type=simple
Environment=DISPLAY=:1
Environment=HOME=/root
ExecStart=/usr/bin/code --no-sandbox --user-data-dir=/root/.vscode-root-data /home/getechindonesia
Restart=always

[Install]
WantedBy=multi-user.target



sudo systemctl daemon-reload
sudo systemctl enable vscode-gui
sudo systemctl start vscode-gui
