#!/bin/bash
set -e

# Release script: updates version, commits, tags, and pushes
# Usage: ./scripts/tools/release.sh 1.2.0 [--yes]

VERSION="$1"
SKIP_CONFIRM=false

if [ -z "$VERSION" ]; then
    echo "Usage: $0 <version> [--yes]"
    echo "Example: $0 1.2.0"
    echo "Options:"
    echo "  --yes    Skip confirmation prompt"
    exit 1
fi

if [ "$2" = "--yes" ] || [ "$2" = "-y" ]; then
    SKIP_CONFIRM=true
fi

# Validate version format (semver)
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    echo "Error: Version must be in semver format (e.g., 1.2.0)"
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT"

echo "🔄 Updating version to $VERSION..."

# Update Info.plist
INFO_PLIST="Resources/Info.plist"
if [ -f "$INFO_PLIST" ]; then
    echo "  • Updating $INFO_PLIST"
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$INFO_PLIST"
else
    echo "  ⚠️  Warning: $INFO_PLIST not found"
fi

# Update MenuBarController.swift (About dialog)
MENU_BAR_CONTROLLER="Sources/AutoSidecar/MenuBarController.swift"
if [ -f "$MENU_BAR_CONTROLLER" ]; then
    echo "  • Updating $MENU_BAR_CONTROLLER"
    sed -i '' "s/Version [0-9]*\.[0-9]*\.[0-9]*/Version $VERSION/" "$MENU_BAR_CONTROLLER"
else
    echo "  ⚠️  Warning: $MENU_BAR_CONTROLLER not found"
fi

echo ""
echo "📝 Files updated:"
git diff --stat

if [ "$SKIP_CONFIRM" = false ]; then
    echo ""
    read -p "Commit and tag version $VERSION? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "❌ Aborted. Changes not committed."
        exit 1
    fi
else
    echo ""
    echo "⏩ Skipping confirmation (--yes flag)"
fi

echo ""
echo "💾 Committing changes..."
git add "$INFO_PLIST" "$MENU_BAR_CONTROLLER"
git commit -m "Bump version to $VERSION"

echo ""
echo "🏷️  Creating tag v$VERSION..."
git tag "v$VERSION"

echo ""
echo "📤 Pushing to origin..."
git push origin main
git push origin "v$VERSION"

echo ""
echo "✅ Release $VERSION complete!"
echo ""
echo "GitHub Actions will now:"
echo "  1. Run lint checks"
echo "  2. Build and test"
echo "  3. Create GitHub release with binaries"
echo ""
echo "Monitor progress at: https://github.com/jonwillis/auto-continuity/actions"

