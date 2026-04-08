#!/usr/bin/env bash
set -euo pipefail

echo "🔧 Patching VS Code untuk GitHub login..."

# Backup
if [ ! -f /usr/bin/code.original ]; then
    mv /usr/bin/code /usr/bin/code.original
fi

# Buat wrapper lengkap
cat > /usr/bin/code << 'WRAPPER'
#!/usr/bin/env bash

# Set environment variables untuk browser
export BROWSER=/usr/bin/google-chrome-stable
export CHROME_BIN=/usr/bin/google-chrome-stable

# Jalankan VS Code dengan semua flag
exec /usr/bin/code.original \
    --no-sandbox \
    --user-data-dir="/root/.vscode-root-data" \
    --disable-gpu \
    --disable-dev-shm-usage \
    --force-renderer-accessibility \
    --disable-setuid-sandbox \
    "$@"
WRAPPER

chmod +x /usr/bin/code

# Set di profile user
for file in ~/.bashrc ~/.profile ~/.xprofile; do
    if ! grep -q "export BROWSER=/usr/bin/google-chrome-stable" "$file" 2>/dev/null; then
        echo "export BROWSER=/usr/bin/google-chrome-stable" >> "$file"
        echo "export CHROME_BIN=/usr/bin/google-chrome-stable" >> "$file"
    fi
done

echo "✅ VS Code sudah di-patch"
echo " RESTART VS Code sepenuhnya (File → Exit), lalu buka lagi"
