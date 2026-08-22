#!/bin/bash
echo "================================================="
echo " Building MacCam Bridge Windows .exe Installer  "
echo "================================================="

cd "$(dirname "$0")"

npm install
npm run dist

echo ""
echo "[+] Build complete! Check 'dist/' folder for MacCam Bridge Setup.exe"
