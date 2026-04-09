#!/usr/bin/env bash
set -euo pipefail

# Warna output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     VS Code Installer for Root + noVNC/XFCE         ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════╝${NC}"

# 🔒 Cek apakah dijalankan sebagai root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED} Script ini HARUS dijalankan sebagai root${NC}"
    echo -e "   Gunakan: sudo $0"
    exit 1
fi

# 📦 1. Instal VS Code jika belum ada
echo -e "\n${YELLOW}[1/5] Memeriksa instalasi VS Code...${NC}"
if command -v code &> /dev/null; then
    echo -e "${GREEN}✅ VS Code sudah terinstal: $(code --version | head -n1)${NC}"
else
    echo -e "${YELLOW}📦 Mengunduh & menginstal VS Code...${NC}"
    
    # Install dependencies
    apt update -y
    apt install -y wget gpg libxkbcommon0 libxcomposite1 libxcursor1 \
        libxdamage1 libxrandr2 libgbm1 libxss1 libasound2 \
        libatk-bridge2.0-0 libgtk-3-0 libnss3
    
    # Download dan install VS Code
    cd /tmp
    wget -q https://aka.ms/download-vscode-stable -O vscode.deb
    
    if [ -f vscode.deb ]; then
        apt install -y ./vscode.deb
        rm -f vscode.deb
        echo -e "${GREEN}✅ VS Code berhasil diinstal${NC}"
    else
        echo -e "${RED}❌ Gagal mengunduh VS Code${NC}"
        exit 1
    fi
fi

# 🖥️ 2. Set DISPLAY permanen
echo -e "\n${YELLOW}[2/5] Mengatur DISPLAY environment...${NC}"
for file in /root/.xprofile /root/.profile /root/.bashrc; do
    if ! grep -q "export DISPLAY=:1" "$file" 2>/dev/null; then
        echo "export DISPLAY=:1" >> "$file"
        echo -e "${GREEN}✅ DISPLAY=:1 ditambahkan ke $file${NC}"
    fi
done

# 🛠️ 3. Buat wrapper script
echo -e "\n${YELLOW}[3/5] Membuat wrapper VS Code untuk root + VNC...${NC}"
WRAPPER_DIR="/root/.local/bin"
mkdir -p "$WRAPPER_DIR"
WRAPPER_PATH="$WRAPPER_DIR/vscode-vnc"

cat > "$WRAPPER_PATH" << 'WRAPPER_EOF'
#!/usr/bin/env bash
# VS Code Wrapper untuk Root + noVNC/XFCE
# Membersihkan lock file yang tersisa
rm -f /root/.config/Code/lock 2>/dev/null
rm -f /root/.config/Code/*.lock 2>/dev/null
rm -f /root/.config/Code/Crashpad/lock 2>/dev/null

# Jalankan VS Code dengan flag yang kompatibel untuk root + VNC
exec /usr/bin/code \
    --no-sandbox \
    --user-data-dir="/root/.vscode-root-data" \
    --disable-gpu \
    --disable-dev-shm-usage \
    --force-renderer-accessibility \
    --disable-setuid-sandbox \
    "$@"
WRAPPER_EOF

chmod +x "$WRAPPER_PATH"
echo -e "${GREEN}✅ Wrapper dibuat: $WRAPPER_PATH${NC}"

# 🖱️ 4. Update file .desktop
echo -e "\n${YELLOW}[4/5] Memperbarui shortcut desktop...${NC}"
DESKTOP_FILES=()

# Cari semua file desktop VS Code
while IFS= read -r -d '' file; do
    DESKTOP_FILES+=("$file")
done < <(find /usr/share/applications /root/.local/share/applications -name "*code*.desktop" -print0 2>/dev/null)

if [ ${#DESKTOP_FILES[@]} -gt 0 ]; then
    for df in "${DESKTOP_FILES[@]}"; do
        if [ -f "$df" ]; then
            cp "$df" "${df}.bak"
            # Ganti baris Exec
            sed -i "s|^Exec=.*|Exec=${WRAPPER_PATH} %F|" "$df"
            # Hapus actions yang tidak perlu
            sed -i "s|^Actions=.*|Actions=|" "$df"
            # Hapus section Desktop Action
            sed -i '/^\[Desktop Action .*\]/,/^$/d' "$df"
            echo -e "${GREEN}✅ Diperbarui: $df${NC}"
        fi
    done
else
    echo -e "${YELLOW}⚠️  Tidak ditemukan file .desktop VS Code${NC}"
    echo -e "   Membuat manual..."
    
    cat > /usr/share/applications/vscode.desktop << 'DESKTOP_EOF'
[Desktop Entry]
Name=Visual Studio Code
Comment=Code Editing. Redefined.
GenericName=Text Editor
Exec=/root/.local/bin/vscode-vnc %F
Icon=visual-studio-code
Type=Application
StartupNotify=false
StartupWMClass=Code
Categories=Development;IDE;TextEditor;
Keywords=vscode;editor;ide;
MimeType=text/plain;inode/directory;
DesktopEOF
    
    chmod +x /usr/share/applications/vscode.desktop
    echo -e "${GREEN}✅ Shortcut desktop dibuat${NC}"
fi

# 🔄 5. Refresh cache desktop
echo -e "\n${YELLOW}[5/5] Refreshing desktop cache...${NC}"
update-desktop-database /usr/share/applications/ 2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true

# ✅ Selesai
echo -e "\n${GREEN}╔══════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              INSTALASI VS CODE SELESAI!              ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════╝${NC}"

echo -e "\n${BLUE}📌 LANGKAH SELANJUTNYA:${NC}"
echo -e "1. 🔴 ${YELLOW}LOGOUT dari sesi noVNC/XFCE, lalu LOGIN ULANG${NC}"
echo -e "   (Wajib agar environment variables terbaca)"
echo -e "\n2. ️ Buka VS Code via:"
echo -e "   Menu XFCE → Programming → Visual Studio Code"
echo -e "   atau"
echo -e "   Desktop → Klik kanan → Run → code"
echo -e "\n3. ⚠️  ${RED}PENTING:${NC}"
echo -e "   • Jangan tutup VS Code via Ctrl+C di terminal"
echo -e "   • Selalu tutup via tombol [X] di jendela"
echo -e "   • Jika macet: pkill -f code && rm -f /root/.config/Code/lock"
echo -e "\n${YELLOW}🔒 SECURITY WARNING:${NC}"
echo -e "   Menjalankan VS Code sebagai root TIDAK AMAN untuk production!"
echo -e "   Gunakan hanya untuk development/testing di server terisolasi."

echo -e "\n${BLUE}🔍 Troubleshooting:${NC}"
echo -e "   Jika masih error, jalankan di terminal noVNC:"
echo -e "   ${YELLOW}$WRAPPER_PATH${NC}"
echo -e ""
