# Auto Sidecar Daemon

A macOS background daemon that automatically enables Sidecar when an iPad Pro is connected via USB, allowing your iPad to function as an external display without manual intervention.

## Features

- **Automatic Detection**: Monitors USB connections using IOKit for efficient, event-driven device detection
- **Auto-Enable Sidecar**: Automatically activates Sidecar when an iPad is detected
- **Background Service**: Runs as a LaunchAgent daemon, starting automatically at login
- **Debouncing**: Prevents multiple activation attempts when devices are connected/disconnected rapidly
- **Logging**: Comprehensive logging to `~/Library/Logs/auto-sidecar.log` for debugging

## Requirements

- macOS 13.0 (Ventura) or later
- iPad running iPadOS 13.0 or later
- Both devices signed in with the same Apple ID
- Handoff enabled on both devices
- Bluetooth and Wi-Fi enabled
- iPad connected via USB (USB 3 hub supported)

## Installation

1. **Build and Install**:
   ```bash
   ./build.sh
   ```

   This will:
   - Compile the Swift application
   - Install the binary to `/usr/local/bin/auto-sidecar`
   - Install and load the LaunchAgent

2. **Grant Permissions**:
   
   The daemon requires Accessibility permissions to control System Events for Sidecar activation:
   
   - Open **System Settings** > **Privacy & Security** > **Accessibility**
   - Click the **+** button
   - Navigate to `/usr/local/bin/auto-sidecar`
   - Add it to the list
   - Ensure the checkbox is enabled

3. **Verify Installation**:
   ```bash
   launchctl list | grep autosidecar
   ```
   
   You should see `com.jonwillis.autosidecar` in the list.

## Usage

Once installed, the daemon runs automatically in the background. Simply connect your iPad Pro via USB, and Sidecar should activate automatically within a few seconds.

### Manual Control

**Stop the daemon**:
```bash
launchctl unload ~/Library/LaunchAgents/com.jonwillis.autosidecar.plist
```

**Start the daemon**:
```bash
launchctl load ~/Library/LaunchAgents/com.jonwillis.autosidecar.plist
```

**View logs**:
```bash
tail -f ~/Library/Logs/auto-sidecar.log
```

## How It Works

1. **USB Monitoring**: Uses IOKit to register for USB device connection/disconnection notifications
2. **Device Detection**: Filters connected devices to identify iPads by:
   - Apple vendor ID (0x05ac)
   - Device name containing "iPad"
   - Known iPad product IDs
3. **Sidecar Activation**: When an iPad is detected:
   - Waits 2 seconds for device initialization
   - Executes AppleScript to enable Sidecar via Control Center
   - Uses debouncing to prevent duplicate activation attempts

## Troubleshooting

### Sidecar doesn't activate automatically

1. **Check logs**:
   ```bash
   tail -f ~/Library/Logs/auto-sidecar.log
   ```

2. **Verify iPad is detected**:
   - Check logs for "iPad detected" messages
   - Verify the iPad appears in System Settings > Displays

3. **Check permissions**:
   - Ensure Accessibility permissions are granted
   - System Settings > Privacy & Security > Accessibility

4. **Verify Sidecar requirements**:
   - Both devices signed in with same Apple ID
   - Handoff enabled
   - Bluetooth and Wi-Fi enabled
   - iPad unlocked and on

5. **Manual activation test**:
   - Try manually enabling Sidecar via Control Center
   - If manual activation works, the issue is with the automation script
   - Check if your iPad name in Control Center matches what the script expects

### Daemon not running

1. **Check if LaunchAgent is loaded**:
   ```bash
   launchctl list | grep autosidecar
   ```

2. **Reload the LaunchAgent**:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.jonwillis.autosidecar.plist
   launchctl load ~/Library/LaunchAgents/com.jonwillis.autosidecar.plist
   ```

3. **Check for errors**:
   ```bash
   launchctl error
   ```

### iPad not detected

1. **Verify USB connection**:
   - Check that the iPad appears in System Information > USB
   - Try a different USB port or cable

2. **Check device name**:
   - The script identifies iPads by name and vendor/product IDs
   - If your iPad has an unusual name, you may need to update the detection logic in `USBMonitor.swift`

3. **Test device detection**:
   ```bash
   system_profiler SPUSBDataType | grep -i ipad
   ```

## Uninstallation

1. **Unload and remove LaunchAgent**:
   ```bash
   launchctl unload ~/Library/LaunchAgents/com.jonwillis.autosidecar.plist
   rm ~/Library/LaunchAgents/com.jonwillis.autosidecar.plist
   ```

2. **Remove binary**:
   ```bash
   sudo rm /usr/local/bin/auto-sidecar
   ```

3. **Remove logs** (optional):
   ```bash
   rm ~/Library/Logs/auto-sidecar.log
   ```

## Development

### Project Structure

This project uses Swift Package Manager for building:

```
.
├── Package.swift                    # Swift Package Manager manifest
├── Sources/
│   └── AutoSidecar/
│       ├── main.swift              # Main entry point and orchestration
│       ├── USBMonitor.swift        # IOKit USB device monitoring
│       ├── SidecarController.swift # AppleScript-based Sidecar activation
│       └── Logger.swift            # Logging utility
├── com.jonwillis.autosidecar.plist # LaunchAgent configuration
└── build.sh                        # Build and installation script
```

### Building from Source

Using Swift Package Manager:

```bash
# Debug build
swift build

# Release build (recommended for production)
swift build -c release

# Run directly
swift run

# Or use the build script
./build.sh
```

The built binary will be at `.build/release/auto-sidecar` (or `.build/debug/auto-sidecar` for debug builds).

## Limitations

- Requires GUI automation (AppleScript) since there's no public API for Sidecar control
- May break with macOS updates that change Control Center structure
- iPad name must be recognizable in device detection logic
- Requires Accessibility permissions

## License

This project is provided as-is for personal use.

