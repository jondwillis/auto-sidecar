import Cocoa
import Foundation

class MenuBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let autoSidecar: AutoSidecar
    
    // Menu items that need to be updated
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var connectMenuItem: NSMenuItem!
    private var disconnectOnRemovalMenuItem: NSMenuItem!
    
    private var isCheckingConnection = false
    
    init(autoSidecar: AutoSidecar) {
        self.autoSidecar = autoSidecar
        setupMenuBar()
        setupObservers()
        updateMenuItems()
    }
    
    private func setupMenuBar() {
        // Create status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            // Using system symbols for the icon
            button.image = NSImage(systemSymbolName: "ipad.and.arrow.forward", accessibilityDescription: "Auto Sidecar")
            button.image?.isTemplate = true
        }
        
        // Create menu
        menu = NSMenu()
        
        // Status item (non-interactive)
        statusMenuItem = NSMenuItem(title: "Status: Initializing...", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Toggle auto-activation
        toggleMenuItem = NSMenuItem(title: "Disable Auto-Activation", action: #selector(toggleAutoActivation), keyEquivalent: "d")
        toggleMenuItem.target = self
        menu.addItem(toggleMenuItem)
        
        // Manual connect/disconnect (toggle)
        connectMenuItem = NSMenuItem(title: "Connect Now", action: #selector(toggleConnection), keyEquivalent: "c")
        connectMenuItem.target = self
        menu.addItem(connectMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Disconnect on USB removal option
        disconnectOnRemovalMenuItem = NSMenuItem(title: "Disconnect When iPad Unplugged", action: #selector(toggleDisconnectOnRemoval), keyEquivalent: "")
        disconnectOnRemovalMenuItem.target = self
        disconnectOnRemovalMenuItem.state = Preferences.shared.shouldDisconnectOnUSBRemoval ? .on : .off
        menu.addItem(disconnectOnRemovalMenuItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // View logs
        let logsItem = NSMenuItem(title: "View Logs", action: #selector(openLogs), keyEquivalent: "l")
        logsItem.target = self
        menu.addItem(logsItem)
        
        // About
        let aboutItem = NSMenuItem(title: "About Auto Sidecar", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit
        let quitItem = NSMenuItem(title: "Quit Auto Sidecar", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem.menu = menu
    }
    
    private func setupObservers() {
        // Update menu items when state changes
        NotificationCenter.default.addObserver(
            forName: .autoSidecarStateChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateMenuItems()
        }
    }
    
    private func updateMenuItems() {
        let state = autoSidecar.currentState
        
        // Update status text
        var statusText = "Status: "
        if !state.isEnabled {
            statusText += "Auto-Activation Disabled"
        } else if state.hasConnectedIPad {
            statusText += "iPad Connected"
        } else {
            statusText += "Waiting for iPad"
        }
        statusMenuItem.title = statusText
        
        // Update icon based on state
        if let button = statusItem.button {
            if !state.isEnabled {
                button.image = NSImage(systemSymbolName: "ipad.slash", accessibilityDescription: "Auto Sidecar Disabled")
            } else if state.hasConnectedIPad {
                button.image = NSImage(systemSymbolName: "ipad.badge.play", accessibilityDescription: "iPad Connected")
            } else {
                button.image = NSImage(systemSymbolName: "ipad.and.arrow.forward", accessibilityDescription: "Auto Sidecar Active")
            }
            button.image?.isTemplate = true
        }
        
        // Update toggle text
        toggleMenuItem.title = state.isEnabled ? "Disable Auto-Activation" : "Enable Auto-Activation"
        
        // Update connect/disconnect button based on Sidecar connection status
        updateConnectionMenuItem()
        
        // Update disconnect on removal checkbox
        disconnectOnRemovalMenuItem.state = Preferences.shared.shouldDisconnectOnUSBRemoval ? .on : .off
    }
    
    private func updateConnectionMenuItem() {
        guard !isCheckingConnection else { return }
        
        isCheckingConnection = true
        autoSidecar.sidecarController.isConnected { [weak self] connected in
            guard let self = self else { return }
            self.isCheckingConnection = false
            
            if connected {
                self.connectMenuItem.title = "Disconnect Sidecar"
                self.connectMenuItem.isEnabled = true
            } else {
                self.connectMenuItem.title = "Connect to Sidecar"
                self.connectMenuItem.isEnabled = self.autoSidecar.currentState.hasConnectedIPad
            }
        }
    }
    
    @objc private func toggleAutoActivation() {
        Preferences.shared.isAutoActivationEnabled.toggle()
        autoSidecar.updateFromPreferences()
        updateMenuItems()
        
        let enabled = Preferences.shared.isAutoActivationEnabled
        showNotification(
            title: "Auto Sidecar",
            message: enabled ? "Auto-activation enabled" : "Auto-activation disabled"
        )
    }
    
    @objc private func toggleConnection() {
        // Check current connection status
        autoSidecar.sidecarController.isConnected { [weak self] connected in
            guard let self = self else { return }
            
            if connected {
                // Disconnect
                self.showNotification(title: "Auto Sidecar", message: "Disconnecting from iPad...")
                self.autoSidecar.manualDisconnect { success in
                    DispatchQueue.main.async {
                        self.showNotification(
                            title: "Auto Sidecar",
                            message: success ? "Disconnected successfully" : "Disconnect failed"
                        )
                        self.updateMenuItems()
                    }
                }
            } else {
                // Connect
                self.showNotification(title: "Auto Sidecar", message: "Connecting to iPad...")
                self.autoSidecar.manualConnect { success in
                    DispatchQueue.main.async {
                        self.showNotification(
                            title: "Auto Sidecar",
                            message: success ? "Connected successfully" : "Connection failed"
                        )
                        self.updateMenuItems()
                    }
                }
            }
        }
    }
    
    @objc private func toggleDisconnectOnRemoval(_ sender: NSMenuItem) {
        Preferences.shared.shouldDisconnectOnUSBRemoval.toggle()
        sender.state = Preferences.shared.shouldDisconnectOnUSBRemoval ? .on : .off
    }
    
    @objc private func openLogs() {
        let logPath = "\(NSHomeDirectory())/Library/Logs/auto-sidecar.log"
        
        // Open in Console.app if available, otherwise in default text editor
        if let consoleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Console") {
            NSWorkspace.shared.open([URL(fileURLWithPath: logPath)], withApplicationAt: consoleURL, configuration: NSWorkspace.OpenConfiguration())
        } else {
            NSWorkspace.shared.openFile(logPath)
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Auto Sidecar"
        alert.informativeText = """
        Version 1.2.0
        
        Automatically connects your iPad as a Sidecar display when plugged in via USB.
        
        © 2025 Jon Willis
        Licensed under MIT
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "GitHub")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            if let url = URL(string: "https://github.com/jonwillis/auto-continuity") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
    
    private func showNotification(title: String, message: String) {
        let notification = NSUserNotification()
        notification.title = title
        notification.informativeText = message
        notification.soundName = NSUserNotificationDefaultSoundName
        NSUserNotificationCenter.default.deliver(notification)
    }
}

