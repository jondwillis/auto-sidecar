# Auto Sidecar

Modern macOS app that automatically activates Sidecar when your iPad is connected via USB. Features an intuitive menu bar interface, onboarding flow, and smart preferences.

## Requirements

- macOS 13.0 (Ventura) or later
- iPad running iPadOS 13.0 or later
- Both devices signed in with the same Apple ID
- Handoff enabled on both devices
- Bluetooth and Wi-Fi enabled
- USB connection (works through USB hubs)

## Installation

### Option 1: Pre-built App (Recommended)

1. Download `Auto Sidecar.app` from the latest release
2. Drag it to your `/Applications` folder
3. Double-click to launch
4. Complete the onboarding wizard

### Option 2: Build from Source

```bash
git clone https://github.com/yourusername/auto-continuity.git
cd auto-continuity
./build-app.sh
```

Then drag `Auto Sidecar.app` to your `/Applications` folder and launch it.

## Features

### 🚀 First Launch Onboarding
- Interactive setup wizard
- Accessibility permissions checklist
- Configure launch at login
- Set disconnect-on-removal preference

### 📊 Menu Bar Interface
- **Smart Status Display**: Real-time monitoring of connection state
- **Toggle Auto-Activation**: Quick enable/disable of automatic connections
- **Connect/Disconnect Toggle**: Manual control with reactive state
- **Disconnect on USB Removal**: Optional automatic disconnection when iPad unplugged
- **View Logs**: Quick access to troubleshooting information
- **About**: Version and license details

### ⚙️ Smart Behavior
- Automatic connection when iPad plugged in
- Optional disconnect when iPad unplugged
- Sleep-aware (won't activate during system sleep)
- Failure tracking with automatic retry limiting
- Works through USB hubs
- Persistent preferences

## Troubleshooting


Quick diagnostic check:
```bash
./diagnose-devices.sh
```

## Usage

After installation, Auto Sidecar will appear in your menu bar with an iPad icon. 

**First Launch:**
1. Complete the onboarding wizard
2. Grant Accessibility permissions
3. Optionally enable "Launch at Login"
4. Configure disconnect behavior

**Daily Use:**
- Simply plug in your iPad - Sidecar activates automatically
- Use menu bar to manually connect/disconnect
- Toggle auto-activation on/off as needed

## Architecture

Event-driven IOKit monitoring detects iPad connections (vendor ID 0x05ac) and triggers Sidecar via SidecarLauncher binary. 5-second debouncing prevents duplicate activations. AppKit-based menu bar interface provides real-time status and control with UserDefaults-backed preferences.

```
Auto Sidecar.app/
├── Contents/
│   ├── MacOS/
│   │   └── AutoSidecar                    # Main executable
│   ├── Resources/
│   │   └── SidecarLauncher                # Sidecar control binary
│   └── Info.plist                         # App metadata

Sources/AutoSidecar/
├── main.swift                             # App lifecycle and coordination
├── MenuBarController.swift                # Menu bar UI and interactions
├── OnboardingWindowController.swift       # First-launch onboarding
├── Preferences.swift                      # UserDefaults-backed settings
├── SidecarController.swift                # Sidecar connect/disconnect
├── USBMonitor.swift                       # IOKit USB monitoring
└── Logger.swift                           # File-based logging
```

## Troubleshooting

Check logs: `tail -f ~/Library/Logs/auto-sidecar.log`

**iPad not detected:**
- Verify USB connection: `system_profiler SPUSBDataType | grep -i ipad`
- Device must have "iPad" in USB product name
- Try different cable/port

**Sidecar doesn't activate:**
- Verify Accessibility permissions are granted
- Check Sidecar requirements (same Apple ID, Handoff, Bluetooth/Wi-Fi)
- Test manual Sidecar connection first

**App not appearing in menu bar:**
- Make sure you've launched `Auto Sidecar.app` from Applications
- Check Activity Monitor for "AutoSidecar" process
- Check logs for errors: `tail -f ~/Library/Logs/auto-sidecar.log`
- Try relaunching the app

**Onboarding not showing:**
- Delete preferences: `defaults delete com.jonwillis.autosidecar`
- Relaunch the app

## Uninstallation

1. Quit Auto Sidecar from the menu bar
2. Move `Auto Sidecar.app` to Trash (from `/Applications`)
3. Remove preferences (optional):
   ```bash
   defaults delete com.jonwillis.autosidecar
   rm ~/Library/Logs/auto-sidecar.log
   ```
4. Remove from Login Items if configured:
   System Settings > General > Login Items

## Development

```bash
swift build                 # Debug build
swift build -c release      # Release build
./build-app.sh              # Build .app bundle
./build.sh                  # Build CLI version (legacy)

# Run from Xcode
open Package.swift          # Open in Xcode
```

## Limitations

- Requires Accessibility permissions for Sidecar control
- Relies on third-party SidecarLauncher binary
- USB (wired) connections only
- macOS 13.0 (Ventura) or later required

## License

MIT - See [LICENSE](LICENSE)
