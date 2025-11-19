#!/bin/bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN_DIR="/usr/local/bin"
APP_NAME="auto-sidecar"

echo "Building Auto Sidecar with Swift Package Manager..."

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

echo ""
echo "Installation complete!"
echo ""
echo "To run Auto Sidecar:"
echo "  $BIN_DIR/$APP_NAME"
echo ""
echo "The app will appear in your menu bar with an iPad icon."
echo "Logs are available at: $HOME/Library/Logs/auto-sidecar.log"
echo ""
echo "IMPORTANT: You may need to grant Accessibility permissions:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Add: $BIN_DIR/$APP_NAME"
echo ""
echo "To run at login, add '$BIN_DIR/$APP_NAME' to:"
echo "  System Settings > General > Login Items"
echo ""

