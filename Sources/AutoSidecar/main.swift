import Foundation
import IOKit
import Cocoa
import UserNotifications
import Observation

/// Observable state for Auto Sidecar
@available(macOS 14.0, *)
@Observable
@MainActor
final class AutoSidecar {
    // Observable state properties
    var isEnabled = true
    var hasConnectedIPad = false
    var isSleeping = false
    var failureCount = 0
    
    // Dependencies
    private let usbMonitor = USBMonitor()
    let sidecarController = SidecarController()
    
    // State management
    private var lastActivationAttempt: Date?
    private let activationDebounceInterval: TimeInterval = 5.0
    private var connectedIPadSerials = Set<String>()
    private let maxFailures = 3
    private var monitoringTask: Task<Void, Never>?
    
    init() {
        updateFromPreferences()
        registerForSleepNotifications()
    }
    
    func start() {
        Task {
            await Logger.shared.info("Starting Auto Sidecar (v1.2)")
            if !isEnabled {
                await Logger.shared.info("Auto-activation is DISABLED. Use menu bar to enable.")
            }
            
            // Start monitoring USB events via AsyncStream
            monitoringTask = Task {
                for await event in await usbMonitor.events() {
                    await handleUSBEvent(event)
                }
            }
        }
    }
    
    private func registerForSleepNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isSleeping = true
                await Logger.shared.info("System going to sleep - disabling auto-activation")
            }
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.isSleeping = false
                self.failureCount = 0
                await Logger.shared.info("System woke up - re-enabling auto-activation")
            }
        }
    }
    
    func updateFromPreferences() {
        isEnabled = Preferences.shared.isAutoActivationEnabled
    }
    
    func toggleAutoActivation() {
        Preferences.shared.isAutoActivationEnabled.toggle()
        updateFromPreferences()
        Task {
            await Logger.shared.info("Auto-activation \(isEnabled ? "enabled" : "disabled") via menu bar")
        }
    }
    
    func manualConnect() async -> Bool {
        await Logger.shared.info("Manual connection requested via menu bar")
        return await sidecarController.enableSidecar()
    }
    
    func manualDisconnect() async -> Bool {
        await Logger.shared.info("Manual disconnection requested via menu bar")
        return await sidecarController.disableSidecar()
    }
    
    private func handleUSBEvent(_ event: USBDeviceEvent) async {
        switch event {
        case .connected(let deviceInfo):
            await handleDeviceConnected(deviceInfo)
        case .disconnected(let deviceInfo):
            await handleDeviceDisconnected(deviceInfo)
        }
    }
    
    private func handleDeviceConnected(_ deviceInfo: USBDeviceInfo) async {
        await Logger.shared.info("Device connected: \(deviceInfo.name) (Vendor: \(deviceInfo.vendorID), Product: \(deviceInfo.productID))")
        
        guard deviceInfo.isIPad else { return }
        
        await Logger.shared.info("iPad detected: \(deviceInfo.name)")
        
        // Track this iPad as physically connected via USB
        if let serial = deviceInfo.serialNumber {
            connectedIPadSerials.insert(serial)
            await Logger.shared.info("Tracking iPad serial: \(serial)")
        }
        
        hasConnectedIPad = !connectedIPadSerials.isEmpty
        
        // Check if auto-activation is disabled
        guard isEnabled else {
            await Logger.shared.info("Auto-activation is disabled - skipping")
            return
        }
        
        // Don't activate if system is sleeping
        guard !isSleeping else {
            await Logger.shared.info("System is sleeping - skipping activation")
            return
        }
        
        // Check failure count
        guard failureCount < maxFailures else {
            await Logger.shared.info("Too many failures (\(failureCount)) - skipping until next disconnect/reconnect")
            return
        }
        
        // Debounce activation attempts
        if let lastAttempt = lastActivationAttempt {
            let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
            guard timeSinceLastAttempt >= activationDebounceInterval else {
                await Logger.shared.info("Skipping activation - too soon since last attempt (\(Int(timeSinceLastAttempt))s)")
                return
            }
        }
        
        // Small delay to ensure iPad is fully initialized
        try? await Task.sleep(for: .seconds(2))
        await activateSidecar()
    }
    
    private func handleDeviceDisconnected(_ deviceInfo: USBDeviceInfo) async {
        await Logger.shared.info("Device disconnected: \(deviceInfo.name)")
        
        guard deviceInfo.isIPad else { return }
        
        await Logger.shared.info("iPad physically disconnected from USB")
        
        // Remove from tracking
        if let serial = deviceInfo.serialNumber {
            connectedIPadSerials.remove(serial)
            await Logger.shared.info("Removed iPad serial: \(serial)")
        }
        
        hasConnectedIPad = !connectedIPadSerials.isEmpty
        
        // Disconnect Sidecar if preference is enabled
        if Preferences.shared.shouldDisconnectOnUSBRemoval {
            await Logger.shared.info("Disconnecting Sidecar due to USB removal (preference enabled)")
            let success = await sidecarController.disableSidecar()
            if success {
                await Logger.shared.info("✓ Sidecar disconnected after iPad removal")
            } else {
                await Logger.shared.error("✗ Failed to disconnect Sidecar after iPad removal")
            }
        }
        
        // Reset state for next connection
        lastActivationAttempt = nil
        failureCount = 0
    }
    
    private func activateSidecar() async {
        // Double-check we're not sleeping
        guard !isSleeping else {
            await Logger.shared.info("Aborting activation - system is sleeping")
            return
        }
        
        // Only activate if we have a physically connected iPad
        guard !connectedIPadSerials.isEmpty else {
            await Logger.shared.info("Aborting activation - no iPad physically connected via USB")
            return
        }
        
        lastActivationAttempt = Date()
        await Logger.shared.info("Attempting to activate Sidecar...")
        
        let success = await sidecarController.enableSidecar()
        
        if success {
            await Logger.shared.info("✓ Sidecar activated successfully")
            failureCount = 0
        } else {
            failureCount += 1
            await Logger.shared.error("✗ Failed to activate Sidecar (attempt \(failureCount)/\(maxFailures))")
            
            if failureCount >= maxFailures {
                await Logger.shared.error("⚠️  Too many failures - stopping attempts. Disconnect and reconnect iPad to retry.")
            }
        }
    }
}

// Modern AppDelegate using async/await
@available(macOS 14.0, *)
@MainActor
@objc(AppDelegate)
class AppDelegate: NSObject, NSApplicationDelegate {
    var autoSidecar: AutoSidecar!
    var menuBarController: MenuBarController!
    var onboardingWindowController: OnboardingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (menu bar only, no Dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Initialize AutoSidecar with @Observable support
        autoSidecar = AutoSidecar()
        
        // Create menu bar UI
        menuBarController = MenuBarController(autoSidecar: autoSidecar)
        
        // Show onboarding if first launch
        if !Preferences.shared.hasCompletedOnboarding {
            showOnboarding()
        }
        
        // Start monitoring
        autoSidecar.start()
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Task {
            await Logger.shared.info("Auto Sidecar terminating")
        }
    }
    
    private func showOnboarding() {
        onboardingWindowController = OnboardingWindowController()
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Main entry point
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)

