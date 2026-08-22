#!/bin/bash
echo "================================================="
echo " Building MacCam Bridge Windows .exe Installer  "
echo "================================================="

cd "$(dirname "$0")"

if [ ! -d "node_modules" ]; then
    echo "[*] Installing dependencies with npm..."
    npm install
fi

echo "[*] Packaging Windows Executables & Installers with electron-builder..."
npx electron-builder --win --config.win.target=portable

echo ""
echo "[+] Windows Executable Build Complete!"
echo "[+] Output artifacts generated in 'dist/' folder."
