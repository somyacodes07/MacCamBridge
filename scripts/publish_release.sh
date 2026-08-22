#!/bin/bash
set -e
echo "================================================="
echo " Verifying & Triggering Official GitHub Release  "
echo "================================================="

VERSION=${1:-"v1.0.0"}

echo "[*] Checking local release artifacts..."
if [ ! -f "MacCamBridge-macOS.dmg" ]; then
    echo "[!] MacCamBridge-macOS.dmg missing. Building now..."
    ./build_mac_dmg.sh
fi

if [ ! -f "WindowsReceiver/dist/MacCam-Bridge-Setup-Windows-x64-1.0.0.exe" ]; then
    echo "[!] Windows executables missing. Building now..."
    (cd WindowsReceiver && ./build_windows_exe.sh)
fi

echo "[+] Local Release Artifact Verification:"
ls -lh MacCamBridge-macOS.dmg WindowsReceiver/dist/MacCam-Bridge-Setup-Windows-*.exe WindowsReceiver/dist/MacCam-Bridge-Portable-Windows-*.exe

echo ""
echo "[*] Tagging release $VERSION and pushing to GitHub..."
git tag -a "$VERSION" -m "MacCam Bridge Release $VERSION" || true
git push origin "$VERSION"

echo ""
echo "[+] Release tag $VERSION pushed to GitHub!"
echo "[+] GitHub Actions CI/CD will automatically compile and attach .dmg and .exe files to GitHub Releases!"
