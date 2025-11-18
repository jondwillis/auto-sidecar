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
swift build -c release

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

# Unload existing agent if running
if launchctl list | grep -q "$PLIST_NAME"; then
    echo "Unloading existing LaunchAgent..."
    launchctl unload "$LAUNCH_AGENTS_DIR/$PLIST_NAME" 2>/dev/null || true
fi

# Load the LaunchAgent
echo "Loading LaunchAgent..."
launchctl load "$LAUNCH_AGENTS_DIR/$PLIST_NAME"

echo ""
echo "Installation complete!"
echo ""
echo "The Auto Sidecar daemon is now running."
echo "Logs are available at: $HOME/Library/Logs/auto-sidecar.log"
echo ""
echo "To stop the daemon:"
echo "  launchctl unload $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "To start the daemon:"
echo "  launchctl load $LAUNCH_AGENTS_DIR/$PLIST_NAME"
echo ""
echo "IMPORTANT: You may need to grant Accessibility permissions:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Add: $BIN_DIR/$APP_NAME"
echo ""

