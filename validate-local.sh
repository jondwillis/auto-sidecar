#!/bin/bash

# Local validation script - runs checks that would run in CI
# This can be run without act/Docker

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "Local Validation Checks"
echo "======================="
echo ""

# Track failures
FAILURES=0

# 1. Shell script syntax
echo "1. Validating shell scripts..."
echo "   ---------------------------"
for script in *.sh; do
  if [ -f "$script" ]; then
    if bash -n "$script" 2>&1; then
      echo "   ✓ $script"
    else
      echo "   ✗ $script - SYNTAX ERROR"
      ((FAILURES++))
    fi
  fi
done
echo ""

# 2. Check permissions
echo "2. Checking file permissions..."
echo "   ----------------------------"
for script in build.sh uninstall.sh enable.sh disable.sh status.sh test-ci.sh validate-local.sh; do
  if [ -f "$script" ]; then
    if [ -x "$script" ]; then
      echo "   ✓ $script is executable"
    else
      echo "   ✗ $script is NOT executable"
      ((FAILURES++))
    fi
  fi
done
echo ""

# 3. Validate plist
echo "3. Validating plist..."
echo "   ------------------"
if plutil -lint com.jonwillis.autosidecar.plist 2>&1 | grep -q "OK"; then
  echo "   ✓ plist is valid"
else
  echo "   ✗ plist is INVALID"
  ((FAILURES++))
fi
echo ""

# 4. Check Swift syntax (basic)
echo "4. Checking Swift files..."
echo "   ----------------------"
for swift_file in Sources/AutoSidecar/*.swift; do
  if [ -f "$swift_file" ]; then
    # Basic check - just verify file is not empty and has some Swift keywords
    if grep -q "import\|class\|struct\|func" "$swift_file"; then
      echo "   ✓ $(basename $swift_file)"
    else
      echo "   ✗ $(basename $swift_file) - appears invalid"
      ((FAILURES++))
    fi
  fi
done
echo ""

# 5. Check for hardcoded paths
echo "5. Checking for hardcoded paths..."
echo "   --------------------------------"
if grep -r "/Users/jon" Sources/ --exclude-dir=.build 2>/dev/null | grep -v "// "; then
  echo "   ⚠️  Found hardcoded paths (should use HOME or NSHomeDirectory())"
  # Don't fail, just warn
else
  echo "   ✓ No obvious hardcoded paths"
fi
echo ""

# 6. Check required files
echo "6. Verifying required files..."
echo "   ---------------------------"
required_files=(
  "Package.swift"
  "README.md"
  "LICENSE"
  "build.sh"
  "uninstall.sh"
  "com.jonwillis.autosidecar.plist"
  "Sources/AutoSidecar/main.swift"
  "Sources/AutoSidecar/USBMonitor.swift"
  "Sources/AutoSidecar/SidecarController.swift"
  "Sources/AutoSidecar/Logger.swift"
)

for file in "${required_files[@]}"; do
  if [ -f "$file" ]; then
    echo "   ✓ $file"
  else
    echo "   ✗ MISSING: $file"
    ((FAILURES++))
  fi
done
echo ""

# 7. Try building (if requested)
if [ "$1" == "--build" ]; then
  echo "7. Testing build..."
  echo "   ---------------"
  if xcrun --toolchain default swift build 2>&1 | tail -5; then
    echo "   ✓ Build succeeded"
  else
    echo "   ✗ Build FAILED"
    ((FAILURES++))
  fi
  echo ""
fi

# Summary
echo "========================================"
if [ $FAILURES -eq 0 ]; then
  echo "✓ All checks passed!"
  echo ""
  echo "Optional: Run with --build to test compilation"
  exit 0
else
  echo "✗ $FAILURES check(s) failed"
  exit 1
fi

