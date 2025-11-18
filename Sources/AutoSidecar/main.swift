import Foundation
import IOKit
import Cocoa

let logger = Logger()

class AutoSidecar {
    private let usbMonitor: USBMonitor
    private let sidecarController: SidecarController
    private var lastActivationAttempt: Date?
    private let activationDebounceInterval: TimeInterval = 5.0 // 5 seconds
    private var isEnabled = true  // Can be toggled via file flag
    private var isSleeping = false
    private var connectedIPadSerials = Set<String>()  // Track physically connected iPads
    private var failureCount = 0
    private let maxFailures = 3  // Stop trying after 3 failures
    
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
        
        // Check if daemon is disabled via flag file
        checkEnabledStatus()
    }
    
    func start() {
        logger.log("Starting Auto Sidecar daemon (v1.1)")
        if !isEnabled {
            logger.log("Auto-activation is DISABLED. Remove ~/Library/Preferences/.auto-sidecar-disabled to enable")
        }
        usbMonitor.start()
        
        // Keep the run loop alive
        RunLoop.main.run()
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
    
    private func checkEnabledStatus() {
        let disableFlagPath = NSHomeDirectory() + "/Library/Preferences/.auto-sidecar-disabled"
        isEnabled = !FileManager.default.fileExists(atPath: disableFlagPath)
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
            
            // Check if auto-activation is disabled
            checkEnabledStatus()
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
            
            // Reset state for next connection
            lastActivationAttempt = nil
            failureCount = 0  // Reset failure count on disconnect
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

// Main entry point
let autoSidecar = AutoSidecar()
autoSidecar.start()

