import Foundation
import IOKit

let logger = Logger()

class AutoSidecar {
    private let usbMonitor: USBMonitor
    private let sidecarController: SidecarController
    private var isSidecarActive = false
    private var lastActivationAttempt: Date?
    private var stateCheckTimer: Timer?
    private let activationDebounceInterval: TimeInterval = 5.0 // 5 seconds
    private let stateCheckInterval: TimeInterval = 10.0 // Check Sidecar state every 10 seconds
    
    init() {
        self.usbMonitor = USBMonitor()
        self.sidecarController = SidecarController()
        
        usbMonitor.onDeviceConnected = { [weak self] deviceInfo in
            self?.handleDeviceConnected(deviceInfo)
        }
        
        usbMonitor.onDeviceDisconnected = { [weak self] deviceInfo in
            self?.handleDeviceDisconnected(deviceInfo)
        }
    }
    
    func start() {
        logger.log("Starting Auto Sidecar daemon...")
        usbMonitor.start()
        
        // Start periodic state checking to keep isSidecarActive in sync
        startStateChecking()
        
        // Keep the run loop alive
        RunLoop.main.run()
    }
    
    private func startStateChecking() {
        // Check Sidecar state periodically to keep our flag in sync
        stateCheckTimer = Timer.scheduledTimer(withTimeInterval: stateCheckInterval, repeats: true) { [weak self] _ in
            self?.checkSidecarState()
        }
        RunLoop.main.add(stateCheckTimer!, forMode: .common)
        
        // Do an initial check
        checkSidecarState()
    }
    
    private func checkSidecarState() {
        let actualState = sidecarController.isSidecarConnected()
        if actualState != isSidecarActive {
            logger.log("Sidecar state changed: \(isSidecarActive) -> \(actualState)")
            isSidecarActive = actualState
        }
    }
    
    private func handleDeviceConnected(_ deviceInfo: USBDeviceInfo) {
        logger.log("Device connected: \(deviceInfo.name) (Vendor: \(deviceInfo.vendorID), Product: \(deviceInfo.productID))")
        
        // Check if this is an iPad
        if deviceInfo.isIPad {
            logger.log("iPad detected: \(deviceInfo.name)")
            
            // Check actual Sidecar state first
            checkSidecarState()
            
            // If already connected, don't try again
            if isSidecarActive {
                logger.log("Sidecar already connected, skipping activation")
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
                // Check state again before activating (might have changed)
                self?.checkSidecarState()
                if !(self?.isSidecarActive ?? false) {
                    self?.activateSidecar()
                }
            }
        }
    }
    
    private func handleDeviceDisconnected(_ deviceInfo: USBDeviceInfo) {
        logger.log("Device disconnected: \(deviceInfo.name)")
        if deviceInfo.isIPad {
            logger.log("iPad disconnected")
            // Reset state - Sidecar should disconnect automatically when iPad disconnects
            isSidecarActive = false
            // Reset last activation attempt to allow immediate retry on reconnect
            lastActivationAttempt = nil
        }
    }
    
    private func activateSidecar() {
        // Always try to activate - let SidecarLauncher handle "already connected" state
        // This ensures we connect even if the flag is incorrect
        lastActivationAttempt = Date()
        logger.log("Attempting to activate Sidecar...")
        
        sidecarController.enableSidecar { [weak self] success in
            if success {
                self?.isSidecarActive = true
                logger.log("Sidecar activated successfully")
            } else {
                self?.isSidecarActive = false
                logger.log("Failed to activate Sidecar, will retry on next connection")
            }
        }
    }
}

// Main entry point
let autoSidecar = AutoSidecar()
autoSidecar.start()

