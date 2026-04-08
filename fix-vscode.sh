# 1. Backup binary asli
mv /usr/bin/code /usr/bin/code.original

# 2. Buat wrapper script di lokasi yang sama
cat > /usr/bin/code << 'EOF'
#!/usr/bin/env bash
exec /usr/bin/code.original \
    --no-sandbox \
    --user-data-dir="/root/.vscode-root-data" \
    --disable-gpu \
    --disable-dev-shm-usage \
    --force-renderer-accessibility \
    --disable-setuid-sandbox \
    "$@"
EOF

# 3. Beri permission execute
chmod +x /usr/bin/code

# 4. Test
code --version
