import Foundation
import IOKit
import Cocoa

let logger = Logger()

// Notification name for state changes
extension Notification.Name {
    static let autoSidecarStateChanged = Notification.Name("autoSidecarStateChanged")
}

struct AutoSidecarState {
    let isEnabled: Bool
    let hasConnectedIPad: Bool
    let isSleeping: Bool
    let failureCount: Int
}

class AutoSidecar {
    private let usbMonitor: USBMonitor
    let sidecarController: SidecarController  // Made public for MenuBarController access
    private var lastActivationAttempt: Date?
    private let activationDebounceInterval: TimeInterval = 5.0 // 5 seconds
    private var isEnabled = true  // Can be toggled via preferences
    private var isSleeping = false
    private var connectedIPadSerials = Set<String>()  // Track physically connected iPads
    private var failureCount = 0
    private let maxFailures = 3  // Stop trying after 3 failures
    
    var currentState: AutoSidecarState {
        return AutoSidecarState(
            isEnabled: isEnabled,
            hasConnectedIPad: !connectedIPadSerials.isEmpty,
            isSleeping: isSleeping,
            failureCount: failureCount
        )
    }
    
    init() {
        self.usbMonitor = USBMonitor()
        self.sidecarController = SidecarController()
        
        usbMonitor.onDeviceConnected = { [weak self] deviceInfo in
            self?.handleDeviceConnected(deviceInfo)
        }
        
        usbMonitor.onDeviceDisconnected = { [weak self] deviceInfo in
            self?.handleDeviceDisconnected(deviceInfo)
        }
        
        // Register for sleep/wake notifications
        registerForSleepNotifications()
        
        // Load preferences
        updateFromPreferences()
    }
    
    func start() {
        logger.log("Starting Auto Sidecar (v1.2)")
        if !isEnabled {
            logger.log("Auto-activation is DISABLED. Use menu bar to enable or remove ~/Library/Preferences/.auto-sidecar-disabled")
        }
        usbMonitor.start()
        
        // Notify initial state
        notifyStateChanged()
    }
    
    private func registerForSleepNotifications() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSleeping = true
            logger.log("System going to sleep - disabling auto-activation")
        }
        
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.isSleeping = false
            self?.failureCount = 0  // Reset failure count on wake
            logger.log("System woke up - re-enabling auto-activation")
        }
    }
    
    func updateFromPreferences() {
        isEnabled = Preferences.shared.isAutoActivationEnabled
        notifyStateChanged()
    }
    
    func toggleAutoActivation() {
        Preferences.shared.isAutoActivationEnabled.toggle()
        updateFromPreferences()
        logger.log("Auto-activation \(isEnabled ? "enabled" : "disabled") via menu bar")
    }
    
    func manualConnect(completion: @escaping (Bool) -> Void) {
        logger.log("Manual connection requested via menu bar")
        sidecarController.enableSidecar(completion: completion)
    }
    
    func manualDisconnect(completion: @escaping (Bool) -> Void) {
        logger.log("Manual disconnection requested via menu bar")
        sidecarController.disableSidecar(completion: completion)
    }
    
    private func notifyStateChanged() {
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .autoSidecarStateChanged, object: nil)
        }
    }
    
    private func handleDeviceConnected(_ deviceInfo: USBDeviceInfo) {
        logger.log("Device connected: \(deviceInfo.name) (Vendor: \(deviceInfo.vendorID), Product: \(deviceInfo.productID))")
        
        // Check if this is an iPad
        if deviceInfo.isIPad {
            logger.log("iPad detected: \(deviceInfo.name)")
            
            // Track this iPad as physically connected via USB
            if let serial = deviceInfo.serialNumber {
                connectedIPadSerials.insert(serial)
                logger.log("Tracking iPad serial: \(serial)")
            }
            
            // Notify state changed (iPad connected)
            notifyStateChanged()
            
            // Check if auto-activation is disabled
            if !isEnabled {
                logger.log("Auto-activation is disabled - skipping")
                return
            }
            
            // Don't activate if system is sleeping
            if isSleeping {
                logger.log("System is sleeping - skipping activation")
                return
            }
            
            // Check failure count
            if failureCount >= maxFailures {
                logger.log("Too many failures (\(failureCount)) - skipping until next disconnect/reconnect")
                return
            }
            
            // Debounce activation attempts
            if let lastAttempt = lastActivationAttempt {
                let timeSinceLastAttempt = Date().timeIntervalSince(lastAttempt)
                if timeSinceLastAttempt < activationDebounceInterval {
                    logger.log("Skipping activation - too soon since last attempt (\(Int(timeSinceLastAttempt))s)")
                    return
                }
            }
            
            // Small delay to ensure iPad is fully initialized
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.activateSidecar()
            }
        }
    }
    
    private func handleDeviceDisconnected(_ deviceInfo: USBDeviceInfo) {
        logger.log("Device disconnected: \(deviceInfo.name)")
        if deviceInfo.isIPad {
            logger.log("iPad physically disconnected from USB")
            
            // Remove from tracking
            if let serial = deviceInfo.serialNumber {
                connectedIPadSerials.remove(serial)
                logger.log("Removed iPad serial: \(serial)")
            }
            
            // Disconnect Sidecar if preference is enabled
            if Preferences.shared.shouldDisconnectOnUSBRemoval {
                logger.log("Disconnecting Sidecar due to USB removal (preference enabled)")
                sidecarController.disableSidecar { success in
                    if success {
                        logger.log("✓ Sidecar disconnected after iPad removal")
                    } else {
                        logger.log("✗ Failed to disconnect Sidecar after iPad removal")
                    }
                }
            }
            
            // Reset state for next connection
            lastActivationAttempt = nil
            failureCount = 0  // Reset failure count on disconnect
            
            // Notify state changed (iPad disconnected)
            notifyStateChanged()
        }
    }
    
    private func activateSidecar() {
        // Double-check we're not sleeping
        guard !isSleeping else {
            logger.log("Aborting activation - system is sleeping")
            return
        }
        
        // Only activate if we have a physically connected iPad
        guard !connectedIPadSerials.isEmpty else {
            logger.log("Aborting activation - no iPad physically connected via USB")
            return
        }
        
        lastActivationAttempt = Date()
        logger.log("Attempting to activate Sidecar...")
        
        sidecarController.enableSidecar { [weak self] success in
            guard let self = self else { return }
            
            if success {
                logger.log("✓ Sidecar activated successfully")
                self.failureCount = 0  // Reset on success
            } else {
                self.failureCount += 1
                logger.log("✗ Failed to activate Sidecar (attempt \(self.failureCount)/\(self.maxFailures))")
                
                if self.failureCount >= self.maxFailures {
                    logger.log("⚠️  Too many failures - stopping attempts. Disconnect and reconnect iPad to retry.")
                }
            }
        }
    }
}

// AppDelegate for menu bar application
class AppDelegate: NSObject, NSApplicationDelegate {
    var autoSidecar: AutoSidecar!
    var menuBarController: MenuBarController!
    var onboardingWindowController: OnboardingWindowController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Initialize AutoSidecar
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
        logger.log("Auto Sidecar terminating")
    }
    
    private func showOnboarding() {
        onboardingWindowController = OnboardingWindowController()
        onboardingWindowController?.showWindow(nil)
        onboardingWindowController?.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// Main entry point
let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate

// Set activation policy to accessory (menu bar only, no Dock icon)
app.setActivationPolicy(.accessory)

// Run the application
app.run()

