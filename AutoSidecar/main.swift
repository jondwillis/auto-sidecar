import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib

let logger = Logger()

class AutoSidecar {
    private let usbMonitor: USBMonitor
    private let sidecarController: SidecarController
    private var isSidecarActive = false
    private var lastActivationAttempt: Date?
    private let activationDebounceInterval: TimeInterval = 5.0 // 5 seconds
    
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
        
        // Keep the run loop alive
        RunLoop.main.run()
    }
    
    private func handleDeviceConnected(_ deviceInfo: USBDeviceInfo) {
        logger.log("Device connected: \(deviceInfo.name) (Vendor: \(deviceInfo.vendorID), Product: \(deviceInfo.productID))")
        
        // Check if this is an iPad
        if deviceInfo.isIPad {
            logger.log("iPad detected: \(deviceInfo.name)")
            
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
            logger.log("iPad disconnected")
            isSidecarActive = false
        }
    }
    
    private func activateSidecar() {
        guard !isSidecarActive else {
            logger.log("Sidecar already active, skipping activation")
            return
        }
        
        lastActivationAttempt = Date()
        logger.log("Attempting to activate Sidecar...")
        
        sidecarController.enableSidecar { [weak self] success in
            if success {
                self?.isSidecarActive = true
                self?.logger.log("Sidecar activated successfully")
            } else {
                self?.logger.log("Failed to activate Sidecar, will retry on next connection")
            }
        }
    }
}

// Main entry point
let autoSidecar = AutoSidecar()
autoSidecar.start()

