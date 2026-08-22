#!/bin/bash
echo "================================================="
echo " Building MacCam Bridge macOS .dmg Disk Image   "
echo "================================================="

cd "$(dirname "$0")"

BUILD_DIR="build_dmg"
APP_NAME="MacCamBridge.app"
DMG_NAME="MacCamBridge-macOS.dmg"

rm -rf "$BUILD_DIR" "$DMG_NAME"
mkdir -p "$BUILD_DIR"

echo "[*] Compiling macOS Release App with xcodebuild..."
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project MacCamBridge.xcodeproj \
  -scheme MacCamBridge \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR/DerivedData" \
  build

APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME" | head -n 1)

if [ -z "$APP_PATH" ]; then
    echo "[!] Error: MacCamBridge.app build output not found!"
    exit 1
fi

echo "[+] App built successfully at: $APP_PATH"
mkdir -p "$BUILD_DIR/dmg_root"
cp -R "$APP_PATH" "$BUILD_DIR/dmg_root/"
ln -s /Applications "$BUILD_DIR/dmg_root/Applications"

echo "[*] Creating macOS .dmg disk image..."
hdiutil create -volname "MacCam Bridge" -srcfolder "$BUILD_DIR/dmg_root" -ov -format UDZO "$DMG_NAME"

echo ""
echo "[+] macOS Disk Image built successfully: $DMG_NAME"
