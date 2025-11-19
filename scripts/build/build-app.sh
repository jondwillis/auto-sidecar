#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
APP_NAME="Auto Sidecar"
EXECUTABLE_NAME="AutoSidecar"
BUILD_DIR="$SCRIPT_DIR/.build/release"
APP_BUNDLE="$SCRIPT_DIR/$APP_NAME.app"

echo "Building Auto Sidecar.app..."

# Clean previous build
if [ -d "$APP_BUNDLE" ]; then
    echo "Removing previous app bundle..."
    rm -rf "$APP_BUNDLE"
fi

cd "$SCRIPT_DIR"

# Build in release mode
echo "Building release binary..."
xcrun --toolchain default swift build -c release --product auto-sidecar

if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

echo "Build successful!"

# Create app bundle structure
echo "Creating app bundle structure..."
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
echo "Copying executable..."
cp "$BUILD_DIR/auto-sidecar" "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Info.plist
echo "Copying Info.plist..."
cp "$SCRIPT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"

# Copy SidecarLauncher if it exists
if [ -f "$SCRIPT_DIR/SidecarLauncher" ]; then
    echo "Copying SidecarLauncher..."
    cp "$SCRIPT_DIR/SidecarLauncher" "$APP_BUNDLE/Contents/Resources/SidecarLauncher"
    chmod +x "$APP_BUNDLE/Contents/Resources/SidecarLauncher"
else
    echo "Warning: SidecarLauncher not found at $SCRIPT_DIR/SidecarLauncher"
    echo "         The app may not be able to control Sidecar"
fi

# Set bundle identifier
echo "Setting bundle attributes..."
/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier com.jonwillis.autosidecar" "$APP_BUNDLE/Contents/Info.plist" 2>/dev/null || true

echo ""
echo "=========================================="
echo "Auto Sidecar.app created successfully!"
echo "=========================================="
echo ""
echo "Location: $APP_BUNDLE"
echo ""
echo "To install:"
echo "  1. Drag 'Auto Sidecar.app' to your /Applications folder"
echo "  2. Double-click to launch"
echo "  3. Grant Accessibility permissions when prompted"
echo "  4. The app will appear in your menu bar"
echo ""
echo "To create a distributable DMG (optional):"
echo "  hdiutil create -volname 'Auto Sidecar' -srcfolder '$APP_BUNDLE' -ov -format UDZO 'Auto Sidecar.dmg'"
echo ""

