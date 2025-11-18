#!/bin/bash

# Diagnostic script to check Sidecar device detection
# Author: Jon Willis

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAUNCHER="$SCRIPT_DIR/SidecarLauncher"

echo "===== Sidecar Device Detection Diagnostics ====="
echo ""

# Check if SidecarLauncher exists
if [ ! -f "$LAUNCHER" ]; then
    echo "❌ ERROR: SidecarLauncher not found at: $LAUNCHER"
    echo ""
    echo "Expected location: $SCRIPT_DIR/SidecarLauncher"
    echo ""
    exit 1
fi

echo "✓ SidecarLauncher found at: $LAUNCHER"
echo ""

# Check if it's executable
if [ ! -x "$LAUNCHER" ]; then
    echo "⚠️  WARNING: SidecarLauncher is not executable"
    echo "Attempting to make it executable..."
    chmod +x "$LAUNCHER"
    if [ -x "$LAUNCHER" ]; then
        echo "✓ Made SidecarLauncher executable"
    else
        echo "❌ Failed to make SidecarLauncher executable"
        exit 1
    fi
fi
echo ""

# Check macOS version
echo "System Information:"
echo "  macOS Version: $(sw_vers -productVersion)"
echo "  Build: $(sw_vers -buildVersion)"
echo ""

# Check if iPad is connected via USB
echo "Checking for connected iOS/iPadOS devices..."
if command -v system_profiler >/dev/null 2>&1; then
    IPAD_INFO=$(system_profiler SPUSBDataType 2>/dev/null | grep -A 10 "iPad" || echo "")
    if [ -n "$IPAD_INFO" ]; then
        echo "✓ iPad detected via USB:"
        echo "$IPAD_INFO" | head -n 5
    else
        echo "⚠️  No iPad detected via USB (system_profiler)"
        echo "   Make sure your iPad is:"
        echo "   1. Connected via USB/USB-C cable"
        echo "   2. Unlocked"
        echo "   3. Trusted this computer (check iPad screen)"
    fi
else
    echo "⚠️  system_profiler command not available"
fi
echo ""

# Check Continuity preferences
echo "Checking Continuity/Sidecar preferences..."
if [ -f "$HOME/Library/Preferences/com.apple.sidecar.plist" ]; then
    echo "✓ Sidecar preferences file exists"
    echo "  Location: ~/Library/Preferences/com.apple.sidecar.plist"
else
    echo "⚠️  Sidecar preferences file not found"
fi
echo ""

# Check WiFi and Bluetooth (required for Sidecar)
echo "Checking connectivity services..."

# Check WiFi
WIFI_POWER=$(networksetup -getairportpower en0 2>/dev/null | grep -o "On\|Off" || echo "Unknown")
echo "  WiFi: $WIFI_POWER"

# Check Bluetooth
if command -v system_profiler >/dev/null 2>&1; then
    BT_INFO=$(system_profiler SPBluetoothDataType 2>/dev/null | grep "State:" || echo "")
    if [ -n "$BT_INFO" ]; then
        echo "  Bluetooth: $BT_INFO"
    else
        echo "  Bluetooth: Unknown"
    fi
fi
echo ""

# Test SidecarLauncher devices command
echo "Testing SidecarLauncher device detection..."
echo "Command: $LAUNCHER devices"
echo ""
echo "--- Output ---"

# Run the command and capture both output and exit code
OUTPUT=$("$LAUNCHER" devices 2>&1) || EXIT_CODE=$?
EXIT_CODE=${EXIT_CODE:-0}

echo "$OUTPUT"
echo "--- End Output ---"
echo ""
echo "Exit Code: $EXIT_CODE"
echo ""

# Interpret exit code
case $EXIT_CODE in
    0)
        echo "✓ SUCCESS: Devices found!"
        echo ""
        echo "Available Sidecar devices:"
        echo "$OUTPUT" | grep -v "^$" | while IFS= read -r line; do
            if [[ ! "$line" =~ ^[[:space:]]*$ ]]; then
                echo "  • $line"
            fi
        done
        ;;
    2)
        echo "❌ ERROR: No reachable Sidecar devices detected (exit code 2)"
        echo ""
        echo "Possible causes:"
        echo "  1. iPad is not connected or not detected by macOS"
        echo "  2. iPad is locked or hasn't trusted this computer"
        echo "  3. WiFi or Bluetooth is disabled (both required for Sidecar)"
        echo "  4. iPad doesn't support Sidecar (requires iPad Pro, iPad Air 3+, iPad mini 5+, iPad 6+)"
        echo "  5. Mac doesn't support Sidecar (requires 2016+ models)"
        echo "  6. Handoff is disabled in System Settings"
        echo ""
        echo "Try:"
        echo "  • Unlock your iPad"
        echo "  • Reconnect the USB cable"
        echo "  • Check System Settings > General > AirDrop & Handoff"
        echo "  • Wait 10-15 seconds after connecting and try again"
        ;;
    4)
        echo "❌ ERROR: SidecarCore private error encountered (exit code 4)"
        echo ""
        echo "This usually indicates a system-level issue with Sidecar."
        echo ""
        echo "Try:"
        echo "  1. Restart your Mac"
        echo "  2. Sign out and back into iCloud"
        echo "  3. Ensure your iPad and Mac are on the same iCloud account"
        echo "  4. Check System Settings > Apple ID > iCloud > Show All"
        echo "  5. Wait 30 seconds and try again"
        ;;
    *)
        echo "❌ ERROR: Unexpected exit code: $EXIT_CODE"
        ;;
esac
echo ""

# Check if already connected
echo "Checking current Sidecar status..."
if pgrep -q "Sidecar"; then
    echo "✓ Sidecar process is running"
else
    echo "  Sidecar process is not running"
fi
echo ""

echo "===== End Diagnostics ====="

