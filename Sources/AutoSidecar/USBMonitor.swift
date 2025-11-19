import Foundation
import IOKit

/// Sendable USB device information
struct USBDeviceInfo: Sendable {
    let name: String
    let vendorID: UInt16
    let productID: UInt16
    let serialNumber: String?
    
    var isIPad: Bool {
        // Apple's vendor ID is 0x05ac
        guard vendorID == 0x05ac else { return false }
        let lowerName = name.lowercased()
        return lowerName.contains("ipad")
    }
}

/// USB device event stream
enum USBDeviceEvent: Sendable {
    case connected(USBDeviceInfo)
    case disconnected(USBDeviceInfo)
}

/// Modern USB monitor using AsyncStream and actors for thread safety
actor USBMonitor {
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var notificationPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    private var runLoop: CFRunLoop?
    private var eventContinuation: AsyncStream<USBDeviceEvent>.Continuation?
    
    /// Stream of USB device events
    func events() -> AsyncStream<USBDeviceEvent> {
        AsyncStream { continuation in
            self.eventContinuation = continuation
            
            Task {
                await self.startMonitoring()
            }
            
            continuation.onTermination = { @Sendable _ in
                Task {
                    await self.stopMonitoring()
                }
            }
        }
    }
    
    private func startMonitoring() async {
        // Create notification port
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort = notificationPort else {
            await Logger.shared.error("Failed to create IONotificationPort")
            return
        }
        
        // Get run loop source and attach to main run loop
        // Note: We use CFRunLoopGetMain() instead of CFRunLoopGetCurrent() 
        // because CFRunLoopGetCurrent() is unavailable in async contexts
        runLoop = CFRunLoopGetMain()
        runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(runLoop, runLoopSource, .defaultMode)
        
        // Set up matching dictionary for USB devices
        guard let matchingDict = IOServiceMatching("IOUSBDevice") else {
            await Logger.shared.error("Failed to create matching dictionary")
            return
        }
        
        // Add notification for device addition
        let addedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            Task {
                await monitor.handleDeviceAdded(iterator)
            }
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let matchingDictRetained = matchingDict as NSDictionary
        let kr = IOServiceAddMatchingNotification(
            notificationPort,
            kIOFirstMatchNotification,
            matchingDictRetained as CFDictionary,
            addedCallback,
            selfPtr,
            &addedIterator
        )
        
        if kr != KERN_SUCCESS {
            await Logger.shared.error("Failed to add matching notification for device addition: \(kr)")
            return
        }
        
        // Set up notification for device removal
        let removedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            Task {
                await monitor.handleDeviceRemoved(iterator)
            }
        }
        
        guard let removedMatchingDict = IOServiceMatching("IOUSBDevice") else {
            await Logger.shared.error("Failed to create matching dictionary for removal")
            return
        }
        
        var removedIteratorTemp: io_iterator_t = 0
        let removedMatchingDictRetained = removedMatchingDict as NSDictionary
        let kr2 = IOServiceAddMatchingNotification(
            notificationPort,
            kIOTerminatedNotification,
            removedMatchingDictRetained as CFDictionary,
            removedCallback,
            selfPtr,
            &removedIteratorTemp
        )
        
        if kr2 != KERN_SUCCESS {
            await Logger.shared.error("Failed to add matching notification for device removal: \(kr2)")
            return
        }
        
        removedIterator = removedIteratorTemp
        
        // Process initial devices
        handleDeviceAdded(addedIterator)
        
        await Logger.shared.info("USB monitoring started")
    }
    
    private func stopMonitoring() {
        if addedIterator != 0 {
            IOObjectRelease(addedIterator)
            addedIterator = 0
        }
        if removedIterator != 0 {
            IOObjectRelease(removedIterator)
            removedIterator = 0
        }
        if let runLoopSource = runLoopSource, let runLoop = runLoop {
            CFRunLoopRemoveSource(runLoop, runLoopSource, .defaultMode)
            self.runLoopSource = nil
            self.runLoop = nil
        }
        if let notificationPort = notificationPort {
            IONotificationPortDestroy(notificationPort)
            self.notificationPort = nil
        }
    }
    
    private func handleDeviceAdded(_ iterator: io_iterator_t) {
        var device = IOIteratorNext(iterator)
        while device != 0 {
            if let deviceInfo = getDeviceInfo(device) {
                eventContinuation?.yield(.connected(deviceInfo))
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func handleDeviceRemoved(_ iterator: io_iterator_t) {
        var device = IOIteratorNext(iterator)
        while device != 0 {
            if let deviceInfo = getDeviceInfo(device) {
                eventContinuation?.yield(.disconnected(deviceInfo))
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func getDeviceInfo(_ device: io_service_t) -> USBDeviceInfo? {
        // Get vendor ID
        var vendorID: UInt16 = 0
        if let vendorIDRef = IORegistryEntryCreateCFProperty(
            device,
            "idVendor" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber {
            vendorID = vendorIDRef.uint16Value
        }
        
        // Get product ID
        var productID: UInt16 = 0
        if let productIDRef = IORegistryEntryCreateCFProperty(
            device,
            "idProduct" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? NSNumber {
            productID = productIDRef.uint16Value
        }
        
        // Get serial number (optional)
        let serialNumber = IORegistryEntryCreateCFProperty(
            device,
            "USB Serial Number" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String
        
        // Get device name from IORegistry
        let deviceName = IORegistryEntryCreateCFProperty(
            device,
            "USB Product Name" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String ?? "USB Device"
        
        return USBDeviceInfo(
            name: deviceName,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber
        )
    }
}

