#!/bin/bash

set -e

BIN_DIR="/usr/local/bin"
APP_NAME="auto-sidecar"
LOG_FILE="$HOME/Library/Logs/auto-sidecar.log"
DISABLE_FLAG="$HOME/Library/Preferences/.auto-sidecar-disabled"

echo "Auto Sidecar Uninstaller"
echo "========================"
echo ""

# Check if app is running and kill it
if pgrep -x "auto-sidecar" > /dev/null; then
    echo "Stopping Auto Sidecar..."
    killall auto-sidecar 2>/dev/null || {
        echo "Note: App was not running or already stopped"
    }
    sleep 1
    echo "✓ App stopped"
else
    echo "App is not running"
fi

# Remove binary
if [ -f "$BIN_DIR/$APP_NAME" ]; then
    echo "Removing binary from $BIN_DIR..."
    if sudo rm "$BIN_DIR/$APP_NAME"; then
        echo "✓ Binary removed"
    else
        echo "✗ Failed to remove binary (may need manual removal)"
    fi
else
    echo "Binary not found at $BIN_DIR/$APP_NAME (already removed?)"
fi

# Remove disable flag
if [ -f "$DISABLE_FLAG" ]; then
    rm "$DISABLE_FLAG"
    echo "✓ Settings removed"
fi

# Ask about logs
if [ -f "$LOG_FILE" ]; then
    read -p "Remove log file? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm "$LOG_FILE"
        echo "✓ Log file removed"
    else
        echo "Log file kept at: $LOG_FILE"
    fi
fi

echo ""
echo "================================================"
echo "Auto Sidecar has been uninstalled successfully!"
echo "================================================"
echo ""
echo "If you added it to Login Items, remove it from:"
echo "  System Settings > General > Login Items"
echo ""
echo "To reinstall, run: ./build.sh"
echo ""


