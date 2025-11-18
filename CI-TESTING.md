# CI/CD Testing Guide

## Local Testing Options

### 1. Quick Validation (Recommended)

Run all checks locally without Docker:

```bash
./validate-local.sh
```

This validates:
- ✅ Shell script syntax
- ✅ File permissions
- ✅ Plist format
- ✅ Swift files exist and have basic structure
- ✅ No obvious hardcoded paths
- ✅ Required files present

**With build test:**
```bash
./validate-local.sh --build
```

### 2. Using `act` (Requires Docker)

`act` simulates GitHub Actions locally using Docker containers.

**Prerequisites:**
```bash
brew install act
# Start Docker Desktop
```

**List all workflows:**
```bash
act -l
```

**Test specific job:**
```bash
# ShellCheck (works in Docker)
act -j shellcheck

# Dry run (no Docker needed)
act -n
```

**Limitations:**
- ❌ macOS workflows (Swift builds) don't work in Linux containers
- ❌ Xcode-specific tasks require actual macOS runner
- ✅ ShellCheck and validation tasks work fine

### 3. Test Helper Script

```bash
./test-ci.sh
```

Interactive script that:
- Checks if `act` is installed
- Lists available workflows
- Provides command examples
- Runs dry-run validation

## GitHub Actions Workflows

### Build & Test (`build.yml`)
- **Runs on:** Push to main/develop, Pull Requests
- **Platform:** macOS-latest
- **Actions:**
  - Checkout code
  - Select Xcode
  - Build release binary
  - Run tests
  - Upload artifacts

**Trigger manually:**
```bash
# Push to trigger
git push origin main

# Or use GitHub CLI
gh workflow run build.yml
```

### Lint (`lint.yml`)
- **Runs on:** Push to main/develop, Pull Requests
- **Jobs:**
  - **SwiftLint:** Code style checks (macOS)
  - **ShellCheck:** Shell script validation (Linux)

**Test locally:**
```bash
# ShellCheck only (works with act)
act -j shellcheck

# SwiftLint (requires macOS)
brew install swiftlint
swiftlint lint --strict
```

### Release (`release.yml`)
- **Runs on:** Git tags (v*)
- **Platform:** macOS-latest
- **Actions:**
  - Build release binary
  - Package with install scripts
  - Generate SHA256 checksum
  - Create GitHub Release

**Test locally:**
```bash
# Simulate release build
xcrun --toolchain default swift build -c release
tar -czf auto-sidecar-test.tar.gz \
  .build/release/auto-sidecar \
  build.sh uninstall.sh README.md LICENSE
```

**Create release:**
```bash
git tag -a v1.1.0 -m "Release v1.1.0"
git push origin v1.1.0
```

### Local Validation (`local-validate.yml`)
- **Runs on:** Push, workflow_dispatch
- **Platform:** Ubuntu (fast)
- **Checks:**
  - Shell script syntax
  - File permissions
  - Plist validation
  - Required files present

**Trigger manually:**
```bash
gh workflow run local-validate.yml
```

## Pre-commit Checklist

Before pushing code, run:

```bash
# 1. Local validation
./validate-local.sh --build

# 2. Format code (if SwiftLint configured)
swiftlint --fix

# 3. Test build
xcrun --toolchain default swift build -c release

# 4. Check for hardcoded paths
grep -r "/Users/jon" Sources/

# 5. Verify scripts are executable
ls -l *.sh
```

## Debugging CI Failures

### Build Failures

**Check locally:**
```bash
xcrun --toolchain default swift build -c release 2>&1 | tee build.log
```

**Common issues:**
- Toolchain mismatch (use Xcode's toolchain)
- Missing dependencies
- Syntax errors

### ShellCheck Failures

**Run locally:**
```bash
shellcheck build.sh uninstall.sh enable.sh disable.sh status.sh
```

**Fix issues:**
- Add `shellcheck disable=SC####` for false positives
- Quote variables: `"$var"` instead of `$var`
- Use `[[ ]]` instead of `[ ]` for tests

### Workflow Syntax Errors

**Validate YAML:**
```bash
# With act
act -n

# With GitHub CLI
gh workflow validate .github/workflows/build.yml

# Or manually
yamllint .github/workflows/*.yml
```

## CI Status Badges

Add to README.md:

```markdown
![Build](https://github.com/yourusername/auto-continuity/workflows/Build%20and%20Test/badge.svg)
![Lint](https://github.com/yourusername/auto-continuity/workflows/Lint/badge.svg)
```

## Continuous Improvement

### TODO:
- [ ] Add unit tests
- [ ] Code coverage reporting
- [ ] Automated releases on tag push
- [ ] Homebrew formula auto-update
- [ ] DMG generation in CI
- [ ] Code signing automation (requires secrets)

### Testing New Workflows

1. Create feature branch
2. Add new workflow to `.github/workflows/`
3. Test with `act -n` (dry run)
4. Push to feature branch
5. Check Actions tab on GitHub
6. Merge when green ✅

## Resources

- **act Documentation:** https://github.com/nektos/act
- **GitHub Actions Docs:** https://docs.github.com/en/actions
- **ShellCheck:** https://www.shellcheck.net/
- **SwiftLint:** https://github.com/realm/SwiftLint

