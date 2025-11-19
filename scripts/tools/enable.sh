#!/bin/bash

# Enable auto-activation
DISABLE_FLAG="$HOME/Library/Preferences/.auto-sidecar-disabled"

rm -f "$DISABLE_FLAG"
echo "✓ Auto Sidecar activation ENABLED"
echo ""
echo "Sidecar will now activate automatically when iPad is connected via USB."
echo "You can also toggle this from the menu bar icon."
echo "To disable, run: swift package dev-tools disable"

