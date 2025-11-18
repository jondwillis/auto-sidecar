#!/bin/bash

echo "Auto Sidecar Status"
echo "==================="
echo ""

# Check if app is running
if pgrep -x "auto-sidecar" > /dev/null; then
    PID=$(pgrep -x "auto-sidecar")
    echo "✓ Auto Sidecar is RUNNING (PID: $PID)"
    echo "  (Check your menu bar for the iPad icon)"
else
    echo "✗ Auto Sidecar is NOT RUNNING"
    echo "  To start: /usr/local/bin/auto-sidecar"
fi

# Check if auto-activation is enabled
DISABLE_FLAG="$HOME/Library/Preferences/.auto-sidecar-disabled"
if [ -f "$DISABLE_FLAG" ]; then
    echo "✗ Auto-activation is DISABLED"
else
    echo "✓ Auto-activation is ENABLED"
fi

echo ""
echo "Recent Log Entries:"
echo "-------------------"
tail -10 ~/Library/Logs/auto-sidecar.log 2>/dev/null || echo "No log file found"

echo ""
echo "Commands:"
echo "  /usr/local/bin/auto-sidecar - Start the app"
echo "  ./disable.sh - Disable auto-activation"
echo "  ./enable.sh  - Enable auto-activation"
echo "  ./status.sh  - Show this status"
echo "  tail -f ~/Library/Logs/auto-sidecar.log - Watch logs"

