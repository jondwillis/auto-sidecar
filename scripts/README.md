# Scripts Directory

Shell scripts organized by purpose, called by Swift Package Manager plugins for idiomatic Swift development.

## Architecture

Auto Sidecar uses **SPM command plugins** (Swift-native) that delegate to these shell scripts:

```
SPM Plugin (Swift) → Shell Script (Bash) → System Commands
```

This hybrid approach provides:
- **Type-safe, idiomatic Swift interfaces** via SPM plugins
- **Battle-tested shell scripts** for system operations
- **Flexibility** for direct script execution when needed

## Directory Structure

### `build/`
Build and compilation scripts:
- `build-app.sh` - Creates the app bundle (`Auto Sidecar.app`)
- `build-cli.sh` - Builds CLI version and installs to `/usr/local/bin`

### `tools/`
User-facing management tools:
- `status.sh` - Display app status and recent logs
- `enable.sh` - Enable auto-activation
- `disable.sh` - Disable auto-activation
- `check-permissions.sh` - Check Accessibility permissions
- `diagnose-devices.sh` - Comprehensive device and system diagnostics
- `uninstall.sh` - Uninstall the app and clean up

### `dev/`
Development and CI/CD scripts:
- `validate-local.sh` - Run validation checks (syntax, permissions, required files)
- `test-device-detection.sh` - Test device detection improvements
- `install-git-hooks.sh` - Install pre-push validation hook

## Usage

### SPM Plugins (Primary Interface)

All functionality is exposed through Swift Package Manager plugins:

```bash
# Build
swift package build-app              # Build app bundle

# Development tools
swift package dev-tools validate     # Run validation
swift package dev-tools diagnose     # Run diagnostics
swift package dev-tools test         # Run tests
swift package dev-tools status       # Show app status
swift package dev-tools help         # Show all commands
```

### Direct Script Execution

Scripts can also be run directly if needed:

```bash
./scripts/build/build-app.sh
./scripts/tools/status.sh
./scripts/dev/validate-local.sh
```

## Script Standards

All scripts follow these conventions:
- Bash with `#!/bin/bash` shebang
- `set -e` for error handling (where appropriate)
- Clear output with status indicators (✓, ✗, ⚠️)
- Consistent formatting and structure
- Executable permissions (`chmod +x`)
- SCRIPT_DIR resolution for path independence

