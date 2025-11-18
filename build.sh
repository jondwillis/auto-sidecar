#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/local/bin"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_NAME="com.jonwillis.autosidecar.plist"
APP_NAME="auto-sidecar"

echo "Building Auto Sidecar daemon with Swift Package Manager..."

cd "$SCRIPT_DIR"

# Build in release mode for optimal performance
echo "Building release binary..."
# Use Xcode's toolchain to match the SDK version
xcrun --toolchain default swift build -c release

if [ $? -ne 0 ]; then
    echo "Error: Build failed"
    exit 1
fi

echo "Build successful!"

# Install binary
echo "Installing binary to $BIN_DIR..."
sudo mkdir -p "$BIN_DIR"
sudo cp ".build/release/$APP_NAME" "$BIN_DIR/$APP_NAME"
sudo chmod +x "$BIN_DIR/$APP_NAME"

# Install LaunchAgent
echo "Installing LaunchAgent..."
mkdir -p "$LAUNCH_AGENTS_DIR"

# Update plist with correct user home path
sed "s|/Users/jon|$HOME|g" "$SCRIPT_DIR/$PLIST_NAME" > "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

# Unload existing agent if running (using modern launchctl syntax)
if launchctl list | grep -q "com.jonwillis.autosidecar"; then
    echo "Stopping existing LaunchAgent..."
    launchctl bootout gui/$(id -u) "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
fi

# Load the LaunchAgent (using modern launchctl syntax)
echo "Loading LaunchAgent..."
launchctl bootstrap gui/$(id -u) "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo ""
echo "Installation complete!"
echo ""
echo "The Auto Sidecar daemon is now running."
echo "Logs are available at: $HOME/Library/Logs/auto-sidecar.log"
echo ""
echo "To stop the daemon:"
echo "  launchctl bootout gui/\$(id -u) $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "To start the daemon:"
echo "  launchctl bootstrap gui/\$(id -u) $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "IMPORTANT: You may need to grant Accessibility permissions:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Add: $BIN_DIR/$APP_NAME"
echo ""

