# 🖥️ VPS GUI Complete Automation

**Complete automated solution for installing desktop GUI (XFCE), VNC server, browser-based noVNC access, and tool applications (VS Code, Chrome) on your VPS or local machine.**

Access complete GUI through browser without needing complex SSH or VPN!

> **✨ HIGHLIGHTS:**
>
> - 🚀 **One-Command Installation** - `sudo bash auto-install.sh` done!
> - 👤 **Non-Root User** - Desktop runs as regular user (more secure)
> - 🌐 **Multiple Access Methods** - Browser noVNC, VNC Direct, Nginx Proxy
> - 📦 **All-Inclusive** - XFCE + VS Code + Chrome already included
> - 🔄 **Idempotent** - Safe to run multiple times for update/fix
> - 🏥 **Health Monitor** - `check.sh` for complete system diagnosis

## ✨ Main Features

- ✅ **Non-Root User** - Desktop & VNC run as regular user, NOT root (more secure!)
- ✅ **XFCE Desktop Environment** - Lightweight, responsive, and fast desktop
- ✅ **Multiple Access Methods**:
  - 🌐 **noVNC via Browser** (port 6080) - Access from browser without client installation
  - 🖥️ **VNC Direct** (port 5900) - Direct VNC connection with VNC client
  - 🔀 **Nginx Proxy** (port 6969) - Alternative HTTP proxy for access
- ✅ **x11vnc** - Professional VNC server with multiple sharing modes
- ✅ **Websockify Bridge** - Protocol bridge for WebSocket support
- ✅ **VS Code & Chrome** - Included and ready to use on desktop
- ✅ **Systemd Service** - Auto-start on reboot, auto-restart if crash
- ✅ **Comprehensive Health Monitor** - `check.sh` for 50+ system checks diagnosis
- ✅ **Nginx Reverse Proxy** - Optional, for advanced HTTP access
- ✅ **Firewall Config** - UFW integration for port management
- ✅ **Idempotent Installation** - Safe to run multiple times without error
- ✅ **One-Command Setup** - Complete installation with just one command!

---

## 🌐 Access Methods

After installation, your desktop can be accessed 3 different ways:

### **1️⃣ noVNC via Browser (RECOMMENDED for Most Users)**

- **URL:** `http://YOUR_IP:6080`
- **Port:** 6080 (HTTP)
- **Advantages:**
  - ✅ No need to install VNC client
  - ✅ Access from anywhere directly in browser
  - ✅ Supports touch/mobile screen
  - ✅ Built-in clipboard support
- **Disadvantages:**
  - Performance slightly slower than VNC direct
- **Usage:**
  ```bash
  # Open browser and enter URL
  http://192.168.1.100:6080
  # Click Connect, desktop will appear in 10-20 seconds
  ```

### **2️⃣ VNC Direct Connection (Best Performance)**

- **Address:** `YOUR_IP:5900`
- **Port:** 5900 (VNC Protocol)
- **Advantages:**
  - ✅ Best performance (native protocol)
  - ✅ Responsive for gaming/video
  - ✅ Low latency, instant response
- **Disadvantages:**
  - ⚠️ Must install VNC client on computer
- **VNC Clients (Free across platforms):**
  - TightVNC (Windows, Mac, Linux)
  - RealVNC (Windows, Mac, Linux)
  - UltraVNC (Windows)
  - Chicken VNC (Mac)
- **Usage:**
  ```bash
  # From VNC client, connect to:
  vnc://192.168.1.100:5900
  # Or enter address: 192.168.1.100
  ```

### **3️⃣ Nginx HTTP Proxy (Alternative Access)**

- **URL:** `http://YOUR_IP:6969`
- **Port:** 6969 (HTTP, configurable)
- **Advantages:**
  - ✅ Additional HTTP access method
  - ✅ Can be configured for specific ports
  - ✅ Works with HTTP/S infrastructure
- **Status:** Optional, configured during STEP 13 of auto-install.sh
- **Usage:**
  ```bash
  # Open browser
  http://192.168.1.100:6969
  # Proxy forward to localhost:8081 (internal XFCE display)
  ```

### **Quick Comparison**

| Access Method     | Port | Client      | Speed     | Setup              |
| ----------------- | ---- | ----------- | --------- | ------------------ |
| **noVNC Browser** | 6080 | No need     | Good      | Auto (included)    |
| **VNC Direct**    | 5900 | VNC client  | Excellent | Auto (included)    |
| **Nginx Proxy**   | 6969 | Tidak perlu | Good      | Optional (STEP 13) |

---

## 🔍 System Health Check (check.sh)

Script `check.sh` adalah **comprehensive health monitor** yang menampilkan status lengkap:

### **Apa yang Dicek (50+ checks):**

1. **👤 User & Directory Status**
   - User exists check
   - Home directory validation
   - VNC directory status

2. **🔧 Systemd Services**
   - vps-gui service (running/stopped, enabled/disabled)
   - nginx service status
   - Auto-start configuration

3. **⚙️ Running Processes**
   - Xvfb (Virtual Display)
   - XFCE (Desktop Environment)
   - x11vnc (VNC Server)
   - websockify (WebSocket bridge)

4. **🔌 Listening Ports**
   - Port 6080 (noVNC)
   - Port 5900 (VNC Direct)
   - Port 6969 (Nginx Proxy)
   - Port 80 (HTTP fallback)

5. **🔐 VNC Configuration**
   - xstartup script presence
   - Password file status

6. **🖥️ Display Server**
   - X Server (:1) responsiveness
   - Display connectivity

7. **🌐 Nginx Configuration**
   - Config file validation
   - Site enablement
   - Configuration syntax check

8. **🎨 XFCE Configuration**
   - Config directory status
   - Autostart directory

### **Usage:**

```bash
# Auto-detect user dari SUDO_USER
sudo bash check.sh

# Check specific user
sudo bash check.sh vpsuser
```

### **Output Example:**

```
🔍 VPS GUI System Health Check
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✅ User 'vpsuser' exists
✅ Home directory exists
✅ vps-gui service is RUNNING
✅ vps-gui service is ENABLED
✅ Xvfb is running
✅ XFCE is running
✅ x11vnc is running
✅ websockify is running
✅ Port 6080 is LISTENING
✅ Port 5900 is LISTENING
⚠️  Port 6969 not listening
✅ VNC xstartup exists
✅ X Server is responding
...

📊 HEALTH CHECK SUMMARY
  ✅ PASS: 45
  ⚠️  WARN: 2
  ❌ FAIL: 0

🎉 SYSTEM IS HEALTHY! All checks passed!
```

---

### System Requirements

- **OS**: Ubuntu 20.04+ / Debian 10+
- **RAM**: Minimum 1GB (recommended 2GB+)
- **Storage**: 5GB available
- **Network**: Active internet connection

### Required Packages

- `sudo` access (for installation)
- `curl` or `wget` (for download)
- Connection to public IP if accessing from outside

---

## 🎯 What's New?

**If you were using old setup (root-based), here are the changes:**

| Aspect           | Old Status            | New Status ✨                   |
| ---------------- | --------------------- | ------------------------------- |
| **User Model**   | Root only             | Multi-user (non-root)           |
| **Desktop User** | `root` (not safe)     | Regular user (e.g., `vpsuser`)  |
| **VNC Server**   | Runs as root          | Runs as regular user            |
| **VS Code**      | Root-only             | Regular user + already included |
| **Chrome**       | Root-only             | User biasa + sudah included     |
| **Setup Script** | `install.sh` (manual) | `auto-install.sh` (all-in-one)  |
| **Instalasi**    | 7 step manual         | 1 command saja!                 |
| **Keamanan**     | Lebih rendah          | ✅ Lebih aman                   |
| **Update/Fix**   | Rumit                 | ✅ Cukup jalankan ulang script  |

**Migrasi dari setup lama?**

```bash
# 1. Cleanup setup lama
sudo bash cleanup.sh

# 2. Install setup baru dengan user biasa
sudo bash auto-install.sh myusername yes

# 3. Selesai!
```

---

## 🚀 Installation Instructions (Step by Step)

### ⚡ **QUICK START: One Command Installation**

Clone or download repository, then run just **1 command**:

```bash
# Clone repository
git clone https://github.com/asepindrak/vps-gui-noVnc.git
cd vps-gui-noVnc
chmod +x *.sh

# INSTALL ALL (auto-install, VS Code, Chrome)
sudo bash auto-install.sh

# OR with custom username
sudo bash auto-install.sh myusername

# OR skip browser install
sudo bash auto-install.sh myusername no
```

**✅ Done!** Access GUI at: `http://YOUR_IP:6080`

**Installation time:** ~15-20 minutes (depends on internet connection)

---

### 📋 **Script auto-install.sh - What does it do?**

Script `auto-install.sh` is an **ALL-IN-ONE solution** covering 13 comprehensive steps:

```
✓ STEP 1:  User & System Setup
✓ STEP 2:  System Update & Install Dependencies
✓ STEP 3:  Setup VNC Directory & Files
✓ STEP 4:  Setup XFCE Autostart Configuration
✓ STEP 5:  Create Systemd Service
✓ STEP 6:  Setup Environment Variables
✓ STEP 7:  Optional - Install VS Code
✓ STEP 8:  Optional - Install Google Chrome
✓ STEP 9:  Firewall Configuration (UFW)
✓ STEP 10: Systemd Service Activation
✓ STEP 11: Verification & Testing
✓ STEP 12: Optional - Setup VNC Password
✓ STEP 13: Optional - Nginx Proxy Setup  ← NEW!
```

**✨ STEP 13 - Nginx Proxy (NEW FEATURE):**

Automatically configures nginx as a reverse HTTP proxy for alternative access:

- Port: 6969 (default, can be customized)
- Forward: `localhost:8081` (internal XFCE desktop)
- Features:
  - Auto port availability check
  - Interactive port selection if 6969 in use
  - Automatic nginx installation
  - WebSocket header support
  - Configuration validation
  - Service auto-start

**Important auto-install.sh features:**

- ✅ **Completely Idempotent** - Can be run multiple times without error (for update/fix)
- ✅ **Non-root user execution** - Desktop and VNC run as regular user, NOT root
- ✅ **Full automation** - No manual setup needed at all
- ✅ **VS Code & Chrome bundled** - Ready to use directly on desktop
- ✅ **Systemd integration** - Auto-restart & auto-start built-in
- ✅ **Multiple access methods** - noVNC, VNC Direct, Nginx Proxy
- ✅ **Nginx optional** - Can skip proxy setup if not needed

---

### 👤 **Understanding User Model**

Differences from old setup:

| Aspect            | Old Setup          | New Setup (auto-install.sh)    |
| ----------------- | ------------------ | ------------------------------ |
| **User**          | `root`             | Regular user (e.g., `vpsuser`) |
| **Desktop login** | root (not secure)  | Regular user + multi-user safe |
| **VNC display**   | `:1` owned by root | `:1` owned by user             |
| **x11vnc**        | Running as root    | Running as user                |
| **VS Code**       | Root user          | Regular user                   |
| **Chrome**        | Root user          | Regular user                   |
| **Security**      | Lower              | More secure                    |
| **Multi-user**    | Not supported      | Supported                      |

---

### 🔧 **Detailed Step-by-Step Installation**

#### **STEP 1: Initial Preparation**

Clone or download this repository to your server:

```bash
git clone https://github.com/asepindrak/vps-gui-noVnc.git
cd vps-gui-noVnc
chmod +x *.sh
```

Alternative (download manually):

```bash
# Download main script
wget https://raw.githubusercontent.com/asepindrak/vps-gui-noVnc/main/auto-install.sh
wget https://raw.githubusercontent.com/asepindrak/vps-gui-noVnc/main/cleanup.sh
chmod +x auto-install.sh cleanup.sh
```

---

#### **STEP 2: Jalankan Auto-Install (MAIN INSTALLATION)**

**Opsi A: Install dengan username auto (dari user yang sudo)**

```bash
sudo bash auto-install.sh
```

**Opsi B: Spesifik username + install VS Code & Chrome**

```bash
sudo bash auto-install.sh myusername yes
```

**Opsi C: Spesifik username, skip VS Code & Chrome**

```bash
sudo bash auto-install.sh myusername no
```

**Proses instalasi:**

1. Setup user (create if not exists)
2. Install packages (XFCE, VNC, noVNC, etc.)
3. Setup VNC configuration
4. Setup XFCE autostart
5. Create systemd service
6. Setup environment
7. Install VS Code (optional)
8. Install Chrome (optional)
9. Configure firewall
10. Start service & verify
11. Show access information

**Output akhir:**

```
✅ INSTALLATION COMPLETE!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Setup Information:
  Username      : myusername
  Home Dir      : /home/myusername
  Display       : :1
  Server IP     : 203.0.113.42

🌐 Access Information:
  Browser URL   : http://203.0.113.42:6080
  VNC Direct    : vnc://203.0.113.42:5900

🚀 Next Steps:
  1. Open browser: http://203.0.113.42:6080
  2. Click 'Connect' button
  3. XFCE desktop should appear
  4. Check Applications menu for VS Code & Chrome
```

---

#### **STEP 3: First GUI Access**

Open browser on your computer:

```
http://YOUR_SERVER_IP:6080
```

Replace `YOUR_SERVER_IP` with:

- ✓ Server's public IP (if accessing from outside)
- ✓ Localhost or 127.0.0.1:6080 (if accessing locally)
- ✓ Server hostname

Click **"Connect"** button → XFCE desktop will appear in 10-20 seconds!

---

#### **STEP 4: Application Usage**

**VS Code:**

- On XFCE desktop, open Applications menu
- Search for "Visual Studio Code"
- Click to open

**Chrome:**

- On XFCE desktop, open Applications menu
- Search for "Google Chrome" or "Chromium"
- Click to open

**Terminal:**

- Right-click on desktop → "Open Terminal Here"
- Or open from Applications menu

---

#### **STEP 5: Setup VNC Password (Optional but Recommended!)**

**Method 1: During installation (RECOMMENDED)**

Script `auto-install.sh` will ask if you want to set password during installation:

```bash
# While running auto-install.sh, will be asked:
# Do you want to set a VNC password? (y/n) [default: n]
# Answer: y
# Then enter desired password
```

**Method 2: Using setpw.sh (anytime)**

To set/reset password anytime:

```bash
# Run setpw.sh with username
sudo bash setpw.sh myusername

# Or with password direct (less secure):
sudo bash setpw.sh myusername "passwordhere"

# Script will ask for password interactively (automatically hidden)
```

**Method 3: Manual**

```bash
# Stop service
sudo systemctl stop vps-gui

# Generate password for user
sudo -u YOUR_USERNAME x11vnc -storepasswd "your_password_here" /home/YOUR_USERNAME/.vnc/passwd

# Update service to use password
# Edit: /etc/systemd/system/vps-gui.service
sed -i 's|-nopw|-rfbauth /home/YOUR_USERNAME/.vnc/passwd|g' /etc/systemd/system/vps-gui.service

# Restart
sudo systemctl daemon-reload
sudo systemctl restart vps-gui
```

**Access with Password:**

After password is set, when connecting to `http://IP:6080`, you'll be prompted to enter password in noVNC prompt.

---

#### **STEP 6: Update or Fix (Run script again)**

If there are issues or you want to update, run the script again:

```bash
# Script automatically detects existing setup and will:
# - Update packages if available
# - Skip user creation if user already exists
# - Restart/reconfigure service
# - Install/update VS Code & Chrome if needed

sudo bash auto-install.sh myusername yes
```

Script ini **idempotent** - aman dijalankan berkali-kali tanpa error!

---

### 📚 **Individual Scripts (Deprecated - Semua Included di auto-install.sh)**

⚠️ **Script-script berikut sudah dihapus karena semuanya sudah included di `auto-install.sh`:**

- ❌ `install.sh` - replaced by auto-install.sh
- ❌ `vscode.sh` - included in auto-install.sh STEP 7
- ❌ `chrome.sh` - included in auto-install.sh STEP 8
- ❌ `fix-vscode.sh` - no longer needed
- ❌ `fix-vscode-chrome.sh` - no longer needed

**➜ GUNAKAN HANYA: `sudo bash auto-install.sh`**

If there are issues in auto-install, just run the same script again to fix:

```bash
sudo bash auto-install.sh myusername yes
```

All issues will be auto-resolved!

---

## 📖 Daftar Script & Fungsinya

### **⭐ RECOMMENDED (Main Script)**

| Script              | Fungsi                                                                        | Run As | Status                         |
| ------------------- | ----------------------------------------------------------------------------- | ------ | ------------------------------ |
| **auto-install.sh** | **ALL-IN-ONE** complete installation XFCE+VNC+VS Code+Chrome for regular user | `sudo` | 🌟 **RECOMMENDED - Use this!** |

---

### **🔧 Utility Scripts (Essential Tools)**

| Script         | Fungsi                                               | Run As | Status                         |
| -------------- | ---------------------------------------------------- | ------ | ------------------------------ |
| **check.sh**   | 🏥 **System Health Monitor** - 50+ diagnostic checks | `sudo` | **NEW! Comprehensive monitor** |
| **setpw.sh**   | 🔐 Setup/change VNC password anytime                 | `sudo` | Password management            |
| **cleanup.sh** | 🧹 Full uninstall & reset system to initial state    | `sudo` | Reset/uninstall                |
| **proxy.sh**   | 🔀 Port forwarding setup (DEPRECATED - use nginx)    | `sudo` | Legacy (use STEP 13 instead)   |

---

### **📋 Utility Scripts Deep Dive**

#### **check.sh - System Health Monitor** ✨ NEW!

Complete health diagnostic tool - use this for troubleshooting:

```bash
# Usage
sudo bash check.sh                    # Auto-detect user
sudo bash check.sh vpsuser            # Check specific user
```

**Monitors 50+ system checks across:**

1. User & Directory Status
2. Systemd Services (vps-gui, nginx)
3. Running Processes (Xvfb, XFCE, x11vnc, websockify)
4. Listening Ports (6080, 5900, 6969)
5. VNC Configuration
6. Display Server Responsiveness
7. Nginx Configuration
8. XFCE Environment

**Output:**

```
✅ PASS: 45
⚠️  WARN: 2
❌ FAIL: 0

🎉 SYSTEM IS HEALTHY!
```

---

#### **setpw.sh - VNC Password Setup**

Set/change VNC password dengan mudah:

```bash
# Interactive (recommended)
sudo bash setpw.sh vpsuser

# Direct password
sudo bash setpw.sh vpsuser "mypassword"

# Auto-detect from SUDO_USER
sudo bash setpw.sh
```

Features:

- ✅ Interactive password entry (secure)
- ✅ Auto-detection of SUDO_USER
- ✅ Automatic systemd update
- ✅ Full error handling

---

#### **cleanup.sh - Full Uninstall & Reset**

Menghapus semua instalasi dan kembali ke state awal:

```bash
sudo bash cleanup.sh
```

Removes:

- All services & processes
- Configuration files
- Systemd service
- Firewall rules
- Lock files

---

#### **proxy.sh - Port Forwarding (DEPRECATED)**

⚠️ **DEPRECATED** - use nginx proxy from auto-install.sh STEP 13.

Legacy socat-based port forwarding. All functionality already included in STEP 13 with nginx which is more robust and reliable.

---

## 🔧 Troubleshooting & Solutions

### **Akses Masih Tidak Bisa**

1. **Verifikasi service berjalan:**

   ```bash
   systemctl status vps-gui
   ps aux | grep -E "Xvfb|x11vnc|websockify"
   ```

2. **Check port listening:**

   ```bash
   ss -tlnp | grep -E '6080|5900'
   ```

   Should have output for port 6080 and 5900

3. **Restart service:**
   ```bash
   sudo systemctl restart vps-gui
   sleep 5
   ```

---

### **VS Code Won't Open or Error**

1. **Clean lock file:**

   ```bash
   # For regular user (replace with your username)
   rm -f ~/.config/Code/lock
   rm -f ~/.config/Code/*.lock

   # Or from sudo:
   sudo -u YOUR_USERNAME rm -f /home/YOUR_USERNAME/.config/Code/lock
   ```

2. **Run fix script (legacy):**

   ```bash
   sudo bash fix-vscode.sh
   ```

3. **Test manual:**

   ```bash
   # Run as user
   code --no-sandbox --disable-gpu
   ```

---

### **Chrome Crash or Not Responsive**

1. **Clean Chrome lock files:**

   ```bash
   # For regular user
   rm -f ~/.config/google-chrome/SingletonLock
   rm -f ~/.config/google-chrome/SingletonCookie
   ```

2. **Run auto-install again to fix:**

   ```bash
   sudo bash auto-install.sh YOUR_USERNAME yes
   ```

3. **Restart XFCE session:**
   ```bash
   killall xfce4-session
   # Refresh browser noVNC, desktop will restart automatically
   ```

---

### **Black Display / Desktop Not Appearing**

1. **Check if Xvfb running:**

   ```bash
   ps aux | grep Xvfb
   ```

2. **If not, restart service:**

   ```bash
   sudo systemctl restart vps-gui
   sleep 10
   ```

3. **Refresh browser noVNC (F5)**

---

### **Port 6080 Already in Use**

If another service uses port 6080:

```bash
# See what's using that port
sudo ss -tlnp | grep 6080

# Kill process if needed
sudo kill -9 <PID>

# Or change port in service
sudo nano /etc/systemd/system/vps-gui.service
# Change "6080" to different port, e.g., "6081"
sudo systemctl daemon-reload && sudo systemctl restart vps-gui
```

---

### **Nginx Proxy Not Working (Port 6969)**

**If nginx not auto-configured:**

1. **Check nginx status:**

   ```bash
   sudo systemctl status nginx
   sudo nginx -t
   ```

2. **Check port 6969 availability:**

   ```bash
   sudo ss -tlnp | grep 6969
   ```

3. **Check nginx config:**

   ```bash
   sudo cat /etc/nginx/sites-available/vps-gui-proxy
   ```

4. **Manual enable nginx proxy:**

   ```bash
   # Run auto-install again with nginx option
   sudo bash auto-install.sh myusername yes

   # When asked: Enter different proxy port [default: skip]
   # Answer: 6969 (or desired port)
   ```

5. **Restart nginx:**
   ```bash
   sudo systemctl restart nginx
   # Verify
   sudo systemctl status nginx
   ```

**If still error:**

- Check nginx logs: `sudo tail -f /var/log/nginx/error.log`
- Verify port not in use: `sudo ss -tlnp | grep -E "6969|80|443"`
- Check firewall: `sudo ufw status | grep 6969`

---

### **Multiple Access Methods Not Working**

Use `check.sh` for diagnostics:

```bash
# Comprehensive health check
sudo bash check.sh myusername
```

This will show:

- ✅ Which services are running
- ✅ Which ports are listening
- ❌ What needs to be fixed with actionable suggestions

---

## 🔐 Security Tips

1. **Always set VNC password:**

   ```bash
   bash setpw.sh
   ```

2. **Use firewall (UFW):**

   ```bash
   sudo ufw enable
   sudo ufw allow 6080
   sudo ufw allow 5900
   sudo ufw allow 22  # SSH (don't forget!)
   ```

3. **Restrict access by specific IP:**

   ```bash
   sudo ufw allow from 192.168.1.0/24 to any port 6080
   ```

4. **Use VPN/SSH tunnel for remote access:**
   ```bash
   # SSH tunnel to VPS
   ssh -L 6080:localhost:6080 user@vps_ip
   # From local open: http://localhost:6080
   ```

---

## 🧹 Uninstall / Reset

Jika ingin menghapus semua instalasi dan kembali ke state awal:

```bash
sudo bash cleanup.sh
```

Script will:

- Stop & disable semua service
- Kill semua process XFCE/VNC
- Hapus configuration & password files
- Hapus systemd service files
- Clean firewall rules
- Remove lock files

Setelah cleanup, Anda bisa install ulang dengan:

```bash
# RECOMMENDED: Use auto-install.sh for fresh setup
sudo bash auto-install.sh YOUR_USERNAME yes
```

**Verify cleanup succeeded:**

```bash
# Automatic user detection
sudo bash check.sh

# With specific username
sudo bash check.sh vpsuser
```

---

## 📊 Resource Usage

Setelah instalasi, typical resource usage:

| Resource | Usage       | Notes                               |
| -------- | ----------- | ----------------------------------- |
| CPU      | 5-15% idle  | Tergantung aplikasi yang dibuka     |
| RAM      | 300-500MB   | Untuk service XFCE+VNC              |
| Storage  | ~3GB        | For XFCE + dependencies             |
| Network  | Idle ~0Kb/s | Active depending on video streaming |

---

## 🎯 Use Cases

1. **Remote Desktop for Development**
   - Install VS Code
   - Akses GUI dari mana saja via browser

2. **GUI Tools Access**
   - File manager
   - Text editor grafis
   - Image viewers
   - Development tools

3. **Browser-based Testing**
   - Install Chrome
   - Test website in desktop environment
   - Screenshot & recording

4. **Server Management Dashboard**
   - Combine dengan web apps
   - Use X-forwarding for graphic tools

---

## ✅ Verification & Testing Guide

After installation is complete, follow these steps to verify setup:

### **1. Check Service Status**

```bash
# Check service status
sudo systemctl status vps-gui

# Should output: active (running)
# If error or inactive, see logs:
sudo journalctl -u vps-gui -n 50 --no-pager
```

### **2. Check Ports**

```bash
# Check listening ports
sudo ss -tlnp | grep -E '6080|5900'

# Output must:
# tcp    LISTEN  ...  :6080  ...
# tcp    LISTEN  ...  :5900  ...
```

### **3. Check Processes**

```bash
# Check all VNC processes
ps aux | grep -E "Xvfb|x11vnc|websockify|xfce4" | grep -v grep

# Must have:
# - Xvfb :1
# - x11vnc
# - websockify
# - startxfce4
```

### **4. Browser Access Test**

1. Open browser: `http://YOUR_SERVER_IP:6080`
2. Click "Connect" button
3. Wait 10-20 seconds for XFCE desktop to load
4. Verify desktop appears with XFCE taskbar

### **5. Application Testing**

**Test VS Code:**

```bash
# On XFCE desktop:
# 1. Click Applications menu
# 2. Look for "Visual Studio Code"
# 3. Click to open
# Verify: VS Code window appears
```

**Test Chrome:**

```bash
# Di desktop XFCE:
# 1. Click Applications menu
# 2. Look for "Google Chrome" or "Chromium"
# 3. Click to open
# Verifikasi: Chrome window muncul
```

**Test Terminal:**

```bash
# Di desktop XFCE:
# 1. Right-click di desktop
# 2. Select "Open Terminal Here"
# 3. Type command: whoami
# Verifikasi: Output adalah username, NOT root!
```

### **6. User & Permission Check**

```bash
# Check service berjalan sebagai user yang benar
ps aux | grep "vps-gui" | grep -v grep | awk '{print $1}'
# Output harus: YOUR_USERNAME (bukan root!)

# Check VNC directory
stat /home/YOUR_USERNAME/.vnc
# Output harus: mode owned by YOUR_USERNAME
```

### **Troubleshooting Checklist**

- [ ] Service status = active (running)
- [ ] Port 6080 listening (noVNC)
- [ ] Port 5900 listening (VNC)
- [ ] Processes: Xvfb, x11vnc, websockify running
- [ ] Browser connect works
- [ ] Desktop appears
- [ ] VS Code can open
- [ ] Chrome can open
- [ ] Terminal shows non-root user
- [ ] Running as intended user (not root)

If any ✗, see **Troubleshooting** section for solutions.

---

## 🤝 Support & Issues

Jika mengalami masalah:

1. **Check logs:**

   ```bash
   journalctl -u vps-gui -n 50 --no-pager
   ```

2. **Enable debug mode dalam service:**

   ```bash
   sudo nano /etc/systemd/system/vps-gui.service
   # Ubah command jadi lebih verbose
   ```

3. **Report issue dengan informasi:**
   - Output dari: `systemctl status vps-gui`
   - Output dari: `ps aux | grep -E "Xvfb|x11vnc|websockify"`
   - OS & version
   - Installation steps yang sudah dilakukan

---

## 📝 Changelog

### v1.0 (Current)

- ✅ Initial release
- ✅ XFCE + x11vnc + noVNC integration
- ✅ Systemd service auto-start
- ✅ VS Code support
- ✅ Chrome browser support
- ✅ Password protection
- ✅ Port forwarding setup
- ✅ Complete cleanup script

---

## 📄 License

Free to use, modify, and distribute.

---

## 🎓 Learning Resources

- **noVNC**: https://github.com/novnc/noVNC
- **x11vnc**: http://www.karlrunge.com/x11vnc/
- **XFCE**: https://www.xfce.org/
- **Systemd**: https://wiki.archlinux.org/title/Systemd

---

**Created with ❤️ to make remote desktop access easier on VPS/Linux servers**
