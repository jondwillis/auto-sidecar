#!/bin/bash

echo "Checking Accessibility permissions for auto-sidecar..."
echo ""

# Check if the app is in the accessibility list
if sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db "SELECT service, client FROM access WHERE service='kTCCServiceAccessibility' AND client LIKE '%auto-sidecar%';" 2>/dev/null | grep -q auto-sidecar; then
    echo "✓ auto-sidecar is in the Accessibility list"
else
    echo "✗ auto-sidecar is NOT in the Accessibility list"
    echo ""
    echo "To fix this:"
    echo "1. Open System Settings"
    echo "2. Go to Privacy & Security > Accessibility"
    echo "3. Click the + button"
    echo "4. Navigate to: $HOME/bin/auto-sidecar"
    echo "5. Add it and ensure the checkbox is enabled"
    echo ""
fi

echo ""
echo "You can also check manually:"
echo "  System Settings > Privacy & Security > Accessibility"
echo "  Look for: $HOME/bin/auto-sidecar"

