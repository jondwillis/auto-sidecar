#!/bin/bash

# Disable auto-activation (daemon keeps running but won't activate Sidecar)
DISABLE_FLAG="$HOME/Library/Preferences/.auto-sidecar-disabled"

touch "$DISABLE_FLAG"
echo "✓ Auto Sidecar activation DISABLED"
echo ""
echo "The app is still running but won't activate Sidecar automatically."
echo "You can also toggle this from the menu bar icon."
echo "To re-enable, run: ./enable.sh"

