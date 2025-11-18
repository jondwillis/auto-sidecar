import Foundation
import IOKit

struct USBDeviceInfo {
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

class USBMonitor {
    var onDeviceConnected: ((USBDeviceInfo) -> Void)?
    var onDeviceDisconnected: ((USBDeviceInfo) -> Void)?
    
    private var addedIterator: io_iterator_t = 0
    private var removedIterator: io_iterator_t = 0
    private var notificationPort: IONotificationPortRef?
    private var runLoopSource: CFRunLoopSource?
    
    func start() {
        // Create notification port
        notificationPort = IONotificationPortCreate(kIOMainPortDefault)
        guard let notificationPort = notificationPort else {
            Logger().log("Failed to create IONotificationPort")
            return
        }
        
        // Get run loop source
        runLoopSource = IONotificationPortGetRunLoopSource(notificationPort).takeUnretainedValue()
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        
        // Set up matching dictionary for USB devices
        guard let matchingDict = IOServiceMatching("IOUSBDevice") else {
            Logger().log("Failed to create matching dictionary")
            return
        }
        
        // Add notification for device addition
        let addedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDeviceAdded(iterator)
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
            Logger().log("Failed to add matching notification for device addition: \(kr)")
            return
        }
        
        // Set up notification for device removal
        let removedCallback: IOServiceMatchingCallback = { (refcon, iterator) in
            let monitor = Unmanaged<USBMonitor>.fromOpaque(refcon!).takeUnretainedValue()
            monitor.handleDeviceRemoved(iterator)
        }
        
        guard let removedMatchingDict = IOServiceMatching("IOUSBDevice") else {
            Logger().log("Failed to create matching dictionary for removal")
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
            Logger().log("Failed to add matching notification for device removal: \(kr2)")
            return
        }
        
        removedIterator = removedIteratorTemp
        
        // Process initial devices
        handleDeviceAdded(addedIterator)
        
        Logger().log("USB monitoring started")
    }
    
    private func handleDeviceAdded(_ iterator: io_iterator_t) {
        var device = IOIteratorNext(iterator)
        while device != 0 {
            if let deviceInfo = getDeviceInfo(device) {
                onDeviceConnected?(deviceInfo)
            }
            IOObjectRelease(device)
            device = IOIteratorNext(iterator)
        }
    }
    
    private func handleDeviceRemoved(_ iterator: io_iterator_t) {
        var device = IOIteratorNext(iterator)
        while device != 0 {
            if let deviceInfo = getDeviceInfo(device) {
                onDeviceDisconnected?(deviceInfo)
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

