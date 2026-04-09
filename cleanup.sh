#!/bin/bash
#===============================================================================
# 🧹 VPS GUI Complete Cleanup Script
# ✅ Remove service, processes, password, lock files, firewall rules, nginx proxy config
# ✅ Run as: sudo bash cleanup.sh
# 📈 NOTE: Nginx package remains in system (only proxy config is removed)
#===============================================================================
set -e

echo "🧹 Starting VPS GUI Cleanup..."

# 1. STOP & DISABLE SERVICE
echo "[1/7] Stopping & disabling services..."
systemctl stop vps-gui 2>/dev/null || true
systemctl disable vps-gui 2>/dev/null || true

# Also stop old service if any
for svc in novnc x11vnc xfce-desktop xvfb vps-gui; do
  systemctl stop $svc 2>/dev/null || true
  systemctl disable $svc 2>/dev/null || true
done

# 2. KILL ALL RELATED PROCESSES
echo "[2/7] Killing running processes..."
pkill -9 -f "Xvfb.*:1" 2>/dev/null || true
pkill -9 -f "x11vnc.*:1" 2>/dev/null || true
pkill -9 -f "websockify" 2>/dev/null || true
pkill -9 -f "startxfce4" 2>/dev/null || true
pkill -9 -f "xfce4-session" 2>/dev/null || true
pkill -9 -f "xfce4-panel" 2>/dev/null || true
# Also remove VS Code & Chrome if still running
pkill -9 -f "code.*--user-data-dir" 2>/dev/null || true
pkill -9 -f "google-chrome" 2>/dev/null || true
pkill -9 -f "chromium" 2>/dev/null || true
sleep 2

# 3. REMOVE LOCK FILES & SOCKETS
echo "[3/7] Cleaning lock files & sockets..."
rm -f /tmp/.X1-lock /tmp/.X11-unix/X1 /tmp/.X11-unix/.X1-lock 2>/dev/null || true
rm -f /tmp/.X*-lock /tmp/.X11-unix/X* 2>/dev/null || true
rm -f /tmp/.X0-lock /tmp/.X11-unix/X0 2>/dev/null || true

# 4. REMOVE PASSWORD & CONFIG FILES
echo "[4/7] Removing password & config files..."
# Root-based config
rm -rf /root/.vnc 2>/dev/null || true
rm -f /root/.Xauthority 2>/dev/null || true
rm -rf /root/.config/xfce4 2>/dev/null || true
rm -rf /root/.local/share/xfce4 2>/dev/null || true

# User-based config (if any)
for user_home in /home/*; do
  if [ -d "$user_home" ]; then
    rm -rf "$user_home/.vnc" 2>/dev/null || true
    rm -f "$user_home/.Xauthority" 2>/dev/null || true
    rm -rf "$user_home/.config/xfce4" 2>/dev/null || true
    rm -rf "$user_home/.local/share/xfce4" 2>/dev/null || true
  fi
done

# Wrapper script if any
rm -f /usr/local/bin/start-vps-gui.sh 2>/dev/null || true

# 5. REMOVE SYSTEMD SERVICE FILES
echo "[5/7] Removing systemd service files..."
rm -f /etc/systemd/system/vps-gui.service 2>/dev/null || true
rm -f /etc/systemd/system/novnc.service 2>/dev/null || true
rm -f /etc/systemd/system/x11vnc.service 2>/dev/null || true
rm -f /etc/systemd/system/xfce-desktop.service 2>/dev/null || true
rm -f /etc/systemd/system/xvfb.service 2>/dev/null || true

# Reload systemd to avoid stale references
systemctl daemon-reload
systemctl reset-failed 2>/dev/null || true

# 6. CLEANUP FIREWALL RULES (Optional)
echo "[6/7] Cleaning firewall rules..."
if command -v ufw &>/dev/null; then
  # Delete rules for specific ports 6080, 5900, 6969 (VNC & nginx proxy)
  ufw delete allow 6080/tcp 2>/dev/null || true
  ufw delete deny 6080/tcp 2>/dev/null || true
  ufw delete allow 5900/tcp 2>/dev/null || true
  ufw delete deny 5900/tcp 2>/dev/null || true
  ufw delete allow 6969/tcp 2>/dev/null || true
  ufw delete deny 6969/tcp 2>/dev/null || true
  
  echo "✅ Firewall rules cleaned (port 6080, 5900, 6969)"
else
  echo "⚠️  UFW not installed, skip firewall cleanup"
fi

# 7. CLEANUP NGINX PROXY CONFIG (but don't remove nginx itself)
echo "[7/7] Cleaning nginx proxy configuration..."
if command -v nginx &>/dev/null; then
  # Disable proxy site if active
  if [ -f /etc/nginx/sites-enabled/vps-gui-proxy ]; then
    rm -f /etc/nginx/sites-enabled/vps-gui-proxy 2>/dev/null || true
    echo "   ✅ Disabled nginx proxy site"
  fi
  
  # Delete proxy config file
  if [ -f /etc/nginx/sites-available/vps-gui-proxy ]; then
    rm -f /etc/nginx/sites-available/vps-gui-proxy 2>/dev/null || true
    echo "   ✅ Removed nginx proxy config"
  fi
  
  # Reload nginx (if still active)
  if systemctl is-active --quiet nginx; then
    nginx -t 2>/dev/null && systemctl reload nginx 2>/dev/null || true
    echo "   ✅ Nginx reloaded"
  fi
else
  echo "   ⚠️  Nginx not installed, skip nginx cleanup"
fi

echo ""
echo "======================================="
echo "✅ CLEANUP COMPLETE!"
echo "======================================="
echo "📋 What was removed:"
echo "   • Service: vps-gui, novnc, x11vnc, xfce-desktop, xvfb"
echo "   • Processes: Xvfb, x11vnc, websockify, XFCE, VS Code, Chrome"
echo "   • Config: ~/.vnc/, ~/.Xauthority, ~/.config/xfce4, lock files"
echo "   • Systemd: /etc/systemd/system/*gui*.service"
echo "   • Firewall: rules port 6080/5900/6969"
echo "   • Nginx proxy: /etc/nginx/sites-available/vps-gui-proxy config only"
echo ""
echo "📈 NOTE:"
echo "   ✅ Nginx package remains in system (safe!)"
echo "   ✅ Systemd daemon already reloaded"
echo ""
echo "🚀 Now you can reinstall with:"
echo "   sudo bash ./install.sh"
echo "======================================="
