#!/usr/bin/env bash
set -euo pipefail

# 🔒 Cek user biasa
if [ "$EUID" -eq 0 ]; then
    echo -e "❌ JANGAN jalankan sebagai root. Gunakan user biasa (contoh: $USER)"
    exit 1
fi

echo -e "🚀 Memulai setup Chrome + VNC/XFCE fix..."

# 1️⃣ Instal Chrome jika belum ada
if ! command -v google-chrome-stable &> /dev/null; then
    echo "📦 Mengunduh & menginstal Google Chrome..."
    cd /tmp
    curl -fsSL https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb -o chrome.deb
    sudo apt update -y
    sudo apt install -y ./chrome.deb
    rm -f chrome.deb
else
    echo -e "✅ Google Chrome sudah terinstal: $(google-chrome-stable --version)"
fi

# 2️⃣ Set DISPLAY permanen untuk sesi GUI
echo "🖥️ Mengatur DISPLAY=:1 secara permanen..."
for file in ~/.xprofile ~/.profile ~/.bashrc; do
    if ! grep -q "export DISPLAY=:1" "$file" 2>/dev/null; then
        echo "export DISPLAY=:1" >> "$file"
    fi
done
echo "✅ DISPLAY ditambahkan ke profile user."

# 3️⃣ Buat wrapper launcher (hapus lock file nyangkut + flag VNC)
echo "🛡️ Membuat launcher wrapper anti-crash..."
mkdir -p ~/.local/bin
cat > ~/.local/bin/chrome-vnc << 'WRAPPER'
#!/usr/bin/env bash
# Bersihkan lock file yang tersisa dari crash / Ctrl+C / close terminal
rm -f ~/.config/google-chrome/SingletonLock ~/.config/google-chrome/SingletonCookie 2>/dev/null
# Jalankan Chrome dengan flag stabil untuk lingkungan VNC/noVNC
exec /usr/bin/google-chrome-stable --no-sandbox --disable-gpu --disable-dev-shm-usage "$@"
WRAPPER
chmod +x ~/.local/bin/chrome-vnc

# 4️⃣ Update file .desktop agar pakai wrapper (pakai absolute path agar pasti kebaca XFCE)
DESKTOP_FILE="/usr/share/applications/google-chrome.desktop"
WRAPPER_PATH="$HOME/.local/bin/chrome-vnc"

if [ -f "$DESKTOP_FILE" ]; then
    sudo cp "$DESKTOP_FILE" "${DESKTOP_FILE}.bak"
    # Ganti baris Exec & Actions lama
    sudo sed -i "s|^Exec=/usr/bin/google-chrome-stable.*|Exec=${WRAPPER_PATH}|" "$DESKTOP_FILE"
    sudo sed -i "s|^Actions=.*|Actions=|" "$DESKTOP_FILE"
    sudo sed -i '/^\[Desktop Action .*\]/,/^$/d' "$DESKTOP_FILE"
    echo "✅ Shortcut desktop diarahkan ke wrapper."
else
    echo "⚠️  File desktop tidak ditemukan di $DESKTOP_FILE"
fi

# 5️⃣ Refresh cache desktop
sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
gtk-update-icon-cache -f /usr/share/icons/hicolor/ 2>/dev/null || true

echo -e "\n✅ KONFIGURASI SELESAI!"
echo -e "📌 LANGKAH WAJIB:"
echo -e "1. 🔴 LOGOUT dari sesi VNC/noVNC, lalu LOGIN ULANG."
echo -e "   (Agar ~/.xprofile & wrapper terbaca penuh oleh XFCE)"
echo -e "2. Buka Chrome via Menu XFCE → Internet → Google Chrome"
echo -e "3. ⚠️  JANGAN matikan Chrome via Ctrl+C di terminal."
echo -e "   Tutup selalu via tombol [X] di jendela Chrome agar lock file bersih otomatis."
echo -e "\n🔍 Jika masih blank setelah klik icon:"
echo -e "   pkill -f chrome && rm -f ~/.config/google-chrome/SingletonLock"
