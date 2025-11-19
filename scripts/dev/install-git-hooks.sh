#!/bin/bash

# Install git hooks for local development
# Run this after cloning the repository

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(git rev-parse --show-toplevel)"
HOOK_DIR="$REPO_ROOT/.git/hooks"

echo "Installing git hooks..."
echo ""

# Create hooks directory if it doesn't exist
mkdir -p "$HOOK_DIR"

# Install pre-push hook
cat > "$HOOK_DIR/pre-push" << 'EOF'
#!/bin/bash

# Pre-push hook - runs local CI/CD validation
# This runs before git push and prevents push if validation fails
# Bypass with: git push --no-verify

echo "Running pre-push validation..."
echo ""

# Get the repo root directory
REPO_ROOT="$(git rev-parse --show-toplevel)"

# Run validation script
if ! "$REPO_ROOT/scripts/dev/validate-local.sh"; then
  echo ""
  echo "❌ Pre-push validation failed!"
  echo ""
  echo "Fix the issues above before pushing."
  echo "Or bypass with: git push --no-verify (not recommended)"
  exit 1
fi

echo ""
echo "✅ Pre-push validation passed - proceeding with push"
echo ""

exit 0
EOF

# Make hook executable
chmod +x "$HOOK_DIR/pre-push"

echo "✅ Pre-push hook installed successfully"
echo ""
echo "The hook will automatically run validation before every push."
echo "To bypass: git push --no-verify (not recommended)"

