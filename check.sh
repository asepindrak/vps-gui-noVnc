# 1. Cek service tidak ada
systemctl list-unit-files | grep -E "vps-gui|novnc|x11vnc"  # Harus: kosong

# 2. Cek proses tidak running
ps aux | grep -E "Xvfb|x11vnc|websockify|xfce4" | grep -v grep  # Harus: kosong

# 3. Cek port tidak listening
ss -tlnp | grep -E '6080|5900'  # Harus: kosong

# 4. Cek file password tidak ada
ls -la /root/.vnc/passwd 2>/dev/null || echo "✅ /root/.vnc/passwd sudah terhapus"
ls -la /home/getechindonesia/.vnc/passwd 2>/dev/null || echo "✅ User .vnc/passwd sudah terhapus"

# 5. Cek lock files bersih
ls -la /tmp/.X1* 2>/dev/null || echo "✅ Lock files sudah terhapus"
