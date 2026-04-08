# 1. Stop service
sudo systemctl stop vps-gui

# 2. Generate password HANYA dengan x11vnc -storepasswd
x11vnc -storepasswd "qwertieser123" /root/.vnc/passwd

# 3. Pastikan permission benar
chmod 600 /root/.vnc/passwd

# 4. Verifikasi ukuran file = 8 byte (format DES x11vnc)
stat -c "%s" /root/.vnc/passwd  # Harus: 8

# 5. Update service: ganti -nopw dengan -rfbauth
sed -i 's|-nopw|-rfbauth /root/.vnc/passwd|g' /etc/systemd/system/vps-gui.service

# 6. Restart service
systemctl daemon-reload
systemctl restart vps-gui
sleep 10

# 7. Test password di browser
# http://<IP>:6080 → Connect → masukkan password
