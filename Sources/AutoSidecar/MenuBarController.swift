import Cocoa
import Foundation
import UserNotifications

/// Modern menu bar controller with async/await and observation
@available(macOS 14.0, *)
@MainActor
final class MenuBarController {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private let autoSidecar: AutoSidecar
    
    // Menu items that need to be updated
    private var statusMenuItem: NSMenuItem!
    private var toggleMenuItem: NSMenuItem!
    private var connectMenuItem: NSMenuItem!
    private var disconnectOnRemovalMenuItem: NSMenuItem!
    
    private var isCheckingConnection = false
    private var observationTask: Task<Void, Never>?
    
    init(autoSidecar: AutoSidecar) {
        self.autoSidecar = autoSidecar
        setupMenuBar()
        setupObservation()
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
    
    private func setupObservation() {
        // Use modern observation with withObservationTracking
        observationTask = Task { @MainActor in
            while !Task.isCancelled {
                withObservationTracking {
                    // Access observed properties to establish tracking
                    _ = autoSidecar.isEnabled
                    _ = autoSidecar.hasConnectedIPad
                    _ = autoSidecar.isSleeping
                } onChange: {
                    Task { @MainActor in
                        self.updateMenuItems()
                    }
                }
                
                // Small delay to avoid rapid updates
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }
    
    private func updateMenuItems() {
        // Update status text
        var statusText = "Status: "
        if !autoSidecar.isEnabled {
            statusText += "Auto-Activation Disabled"
        } else if autoSidecar.hasConnectedIPad {
            statusText += "iPad Connected"
        } else {
            statusText += "Waiting for iPad"
        }
        statusMenuItem.title = statusText
        
        // Update icon based on state
        if let button = statusItem.button {
            if !autoSidecar.isEnabled {
                button.image = NSImage(systemSymbolName: "ipad.slash", accessibilityDescription: "Auto Sidecar Disabled")
            } else if autoSidecar.hasConnectedIPad {
                button.image = NSImage(systemSymbolName: "ipad.badge.play", accessibilityDescription: "iPad Connected")
            } else {
                button.image = NSImage(systemSymbolName: "ipad.and.arrow.forward", accessibilityDescription: "Auto Sidecar Active")
            }
            button.image?.isTemplate = true
        }
        
        // Update toggle text
        toggleMenuItem.title = autoSidecar.isEnabled ? "Disable Auto-Activation" : "Enable Auto-Activation"
        
        // Update connect/disconnect button based on Sidecar connection status
        Task {
            await updateConnectionMenuItem()
        }
        
        // Update disconnect on removal checkbox
        disconnectOnRemovalMenuItem.state = Preferences.shared.shouldDisconnectOnUSBRemoval ? .on : .off
    }
    
    private func updateConnectionMenuItem() async {
        guard !isCheckingConnection else { return }
        
        isCheckingConnection = true
        let connected = await autoSidecar.sidecarController.isConnected()
        isCheckingConnection = false
        
        await MainActor.run {
            if connected {
                connectMenuItem.title = "Disconnect Sidecar"
                connectMenuItem.isEnabled = true
            } else {
                connectMenuItem.title = "Connect to Sidecar"
                connectMenuItem.isEnabled = autoSidecar.hasConnectedIPad
            }
        }
    }
    
    @objc private func toggleAutoActivation() {
        Preferences.shared.isAutoActivationEnabled.toggle()
        autoSidecar.updateFromPreferences()
        updateMenuItems()
        
        let enabled = Preferences.shared.isAutoActivationEnabled
        Task {
            await showNotification(
                title: "Auto Sidecar",
                message: enabled ? "Auto-activation enabled" : "Auto-activation disabled"
            )
        }
    }
    
    @objc private func toggleConnection() {
        Task {
            // Check current connection status
            let connected = await autoSidecar.sidecarController.isConnected()
            
            if connected {
                // Disconnect
                await showNotification(title: "Auto Sidecar", message: "Disconnecting from iPad...")
                let success = await autoSidecar.manualDisconnect()
                await showNotification(
                    title: "Auto Sidecar",
                    message: success ? "Disconnected successfully" : "Disconnect failed"
                )
            } else {
                // Connect
                await showNotification(title: "Auto Sidecar", message: "Connecting to iPad...")
                let success = await autoSidecar.manualConnect()
                await showNotification(
                    title: "Auto Sidecar",
                    message: success ? "Connected successfully" : "Connection failed"
                )
            }
            
            await MainActor.run {
                updateMenuItems()
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
            NSWorkspace.shared.open(URL(fileURLWithPath: logPath))
        }
    }
    
    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "Auto Sidecar"
        alert.informativeText = """
        Version 1.0.0
        
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
    
    private func showNotification(title: String, message: String) async {
        // Use modern UNUserNotificationCenter
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = message
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            await Logger.shared.error("Failed to show notification: \(error.localizedDescription)")
        }
    }
    
    deinit {
        observationTask?.cancel()
    }
}

