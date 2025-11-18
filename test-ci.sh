#!/bin/bash

set -e

echo "Testing GitHub Actions Locally with Act"
echo "========================================"
echo ""

# Check if act is installed
if ! command -v act &> /dev/null; then
    echo "❌ act is not installed"
    echo ""
    echo "Install with Homebrew:"
    echo "  brew install act"
    echo ""
    echo "Or download from: https://github.com/nektos/act"
    exit 1
fi

echo "✓ act is installed"
echo ""

# List available workflows
echo "Available workflows:"
echo "-------------------"
act -l

echo ""
echo "Testing Options:"
echo "---------------"
echo "1. Test build workflow:     act -j build"
echo "2. Test lint workflow:      act -j swiftlint"
echo "3. Test shellcheck:         act -j shellcheck"
echo "4. Dry run (list jobs):     act -n"
echo "5. Test with specific event: act push"
echo ""

# Note: macOS workflows won't work in Docker
echo "⚠️  NOTE: macOS-specific workflows (Swift builds) cannot run in act/Docker"
echo "    These workflows require actual macOS runners or native execution"
echo ""
echo "    You can still test:"
echo "    - Workflow syntax validation"
echo "    - Job dependencies and structure"
echo "    - ShellCheck (Linux-based)"
echo ""

read -p "Run dry-run to list all jobs? (y/N) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo "Running dry-run..."
    act -n
fi

echo ""
echo "To test ShellCheck (works in Docker):"
echo "  act -j shellcheck"
echo ""
echo "To validate workflow syntax:"
echo "  act -n"

