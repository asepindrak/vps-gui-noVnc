#!/bin/bash

USER_NAME="getechindonesia"
DISPLAY_NUM=":1"

export DISPLAY=$DISPLAY_NUM

echo "Menunggu XFCE di $DISPLAY..."

# Tunggu X server ready
while ! xdpyinfo -display $DISPLAY >/dev/null 2>&1; do
    sleep 2
done

echo "XFCE siap, jalankan VS Code sebagai $USER_NAME"

# Jalankan sebagai user (bukan root)
sudo -u $USER_NAME DISPLAY=$DISPLAY code /home/$USER_NAME
