#!/bin/bash
#===============================================================================
# 🧹 VPS GUI Complete Cleanup Script
# ✅ Hapus service, proses, password, lock file, firewall rules
# ✅ Run as: sudo bash cleanup-vps-gui.sh
#===============================================================================
set -e

echo "🧹 Starting VPS GUI Cleanup..."

# 1. STOP & DISABLE SERVICE
echo "[1/6] Stopping & disabling services..."
systemctl stop vps-gui 2>/dev/null || true
systemctl disable vps-gui 2>/dev/null || true

# Juga stop service lama jika ada
for svc in novnc x11vnc xfce-desktop xvfb vps-gui; do
  systemctl stop $svc 2>/dev/null || true
  systemctl disable $svc 2>/dev/null || true
done

# 2. KILL ALL RELATED PROCESSES
echo "[2/6] Killing running processes..."
pkill -9 -f "Xvfb.*:1" 2>/dev/null || true
pkill -9 -f "x11vnc.*:1" 2>/dev/null || true
pkill -9 -f "websockify" 2>/dev/null || true
pkill -9 -f "startxfce4" 2>/dev/null || true
pkill -9 -f "xfce4-session" 2>/dev/null || true
pkill -9 -f "xfce4-panel" 2>/dev/null || true
sleep 2

# 3. REMOVE LOCK FILES & SOCKETS
echo "[3/6] Cleaning lock files & sockets..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/.X11-unix/.X1-lock 2>/dev/null || true
rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true

# 4. REMOVE PASSWORD & CONFIG FILES
echo "[4/6] Removing password & config files..."
# Root-based config
rm -rf /root/.vnc 2>/dev/null || true
rm -f /root/.Xauthority 2>/dev/null || true

# User-based config (jika ada)
for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    rm -rf "$user_home/.vnc" 2>/dev/null || true
    rm -f "$user_home/.Xauthority" 2>/dev/null || true
  fi
done

# Wrapper script jika ada
rm -f /usr/local/bin/start-vps-gui.sh 2>/dev/null || true

# 5. REMOVE SYSTEMD SERVICE FILES
echo "[5/6] Removing systemd service files..."
rm -f /etc/systemd/system/vps-gui.service 2>/dev/null || true
rm -f /etc/systemd/system/novnc.service 2>/dev/null || true
rm -f /etc/systemd/system/x11vnc.service 2>/dev/null || true
rm -f /etc/systemd/system/xfce-desktop.service 2>/dev/null || true
rm -f /etc/systemd/system/xvfb.service 2>/dev/null || true

# Reload systemd agar tidak ada stale reference
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# 6. CLEANUP FIREWALL RULES (Optional)
echo "[6/6] Cleaning firewall rules..."
if command -v ufw &>/dev/null; then
  # Hapus rules spesifik port 6080 & 5900
  ufw delete allow 6080/tcp 2>/dev/null || true
  ufw delete deny 6080/tcp 2>/dev/null || true
  ufw delete allow 5900/tcp 2>/dev/null || true
  ufw delete deny 5900/tcp 2>/dev/null || true
  
  # Atau reset UFW total (HATI-HATI: akan hapus SEMUA rules!)
  # ufw --force reset 2>/dev/null || true
  
  echo "✅ Firewall rules cleaned"
fi

echo ""
echo "======================================="
echo "✅ CLEANUP COMPLETE!"
echo "======================================="
echo "📋 Yang sudah dihapus:"
echo "   • Service: vps-gui, novnc, x11vnc, xfce-desktop, xvfb"
echo "   • Processes: Xvfb, x11vnc, websockify, XFCE"
echo "   • Files: ~/.vnc/, ~/.Xauthority, lock files"
echo "   • Systemd: /etc/systemd/system/*gui*.service"
echo "   • Firewall: rules port 6080/5900"
echo ""
echo "🚀 Sekarang kamu bisa install ulang dengan script lama:"
echo "   sudo bash ./install.sh"
echo "======================================="
