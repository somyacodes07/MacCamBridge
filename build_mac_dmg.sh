#!/bin/bash
set -e

echo "================================================="
echo " Building MacCam Bridge macOS .dmg Disk Image   "
echo "================================================="

cd "$(dirname "$0")"

BUILD_DIR="build_dmg"
APP_NAME="MacCamBridge.app"
DMG_NAME="MacCamBridge-macOS.dmg"

rm -rf "$BUILD_DIR" "$DMG_NAME"
mkdir -p "$BUILD_DIR"

APP_PATH=""

# Method 1: Try building with xcodebuild if a full Xcode installation is active
if command -v xcodebuild >/dev/null 2>&1 && [ -d "$(/usr/bin/xcode-select -p 2>/dev/null)" ] && xcodebuild -version >/dev/null 2>&1; then
    echo "[*] Compiling macOS Release App with xcodebuild..."
    if xcodebuild -project MacCamBridge.xcodeproj -scheme MacCamBridge -configuration Release -derivedDataPath "$BUILD_DIR/DerivedData" build 2>/dev/null; then
        APP_PATH=$(find "$BUILD_DIR/DerivedData" -name "$APP_NAME" | head -n 1)
    fi
fi

# Method 2: Direct compilation with swiftc (works with Xcode or Command Line Tools alone)
if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "[*] Compiling native binary with swiftc..."
    BUNDLE_ROOT="$BUILD_DIR/$APP_NAME"
    MACOS_DIR="$BUNDLE_ROOT/Contents/MacOS"
    RESOURCES_DIR="$BUNDLE_ROOT/Contents/Resources"
    mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

    # Compile Swift sources into optimized binary
    swiftc -O -parse-as-library \
        -target arm64-apple-macosx14.0 \
        -o "$MACOS_DIR/MacCamBridge" \
        MacCamBridge/*.swift

    # Create Info.plist
    cat << 'EOF' > "$BUNDLE_ROOT/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>MacCamBridge</string>
    <key>CFBundleIdentifier</key>
    <string>com.somyajeet.MacCamBridge</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>MacCamBridge</string>
    <key>CFBundleDisplayName</key>
    <string>MacCam Bridge</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSCameraUsageDescription</key>
    <string>MacCam Bridge needs access to your camera to stream video to your Windows laptop.</string>
    <key>CFBundleIconFile</key>
    <string>MacCamBridge</string>
</dict>
</plist>
EOF

    # Copy Icons and Assets
    if [ -f "MacCamBridge/MacCamBridge.icns" ]; then
        cp "MacCamBridge/MacCamBridge.icns" "$RESOURCES_DIR/MacCamBridge.icns"
    fi
    if [ -f "MacCamBridge/logo.png" ]; then
        cp "MacCamBridge/logo.png" "$RESOURCES_DIR/logo.png"
    fi

    # Ad-hoc code sign with entitlements
    if command -v codesign >/dev/null 2>&1; then
        echo "[*] Signing application bundle..."
        codesign --force --deep --sign - --entitlements MacCamBridge/MacCamBridge.entitlements "$BUNDLE_ROOT" 2>/dev/null || true
    fi

    APP_PATH="$BUNDLE_ROOT"
fi

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "[!] Error: MacCamBridge.app could not be built!"
    exit 1
fi

echo "[+] App built successfully at: $APP_PATH"
mkdir -p "$BUILD_DIR/dmg_root"
cp -R "$APP_PATH" "$BUILD_DIR/dmg_root/"
ln -s /Applications "$BUILD_DIR/dmg_root/Applications"

echo "[*] Creating macOS .dmg disk image..."
hdiutil create -volname "MacCam Bridge" -srcfolder "$BUILD_DIR/dmg_root" -ov -format UDZO "$DMG_NAME"
rm -rf "$BUILD_DIR"

echo ""
echo "[+] macOS Disk Image built successfully: $DMG_NAME"
