import Foundation
import IOKit

struct USBDeviceInfo {
    let name: String
    let vendorID: UInt16
    let productID: UInt16
    let serialNumber: String?
    
    var isIPad: Bool {
        // Apple's vendor ID is 0x05ac
        // Check for iPad product IDs or device name
        if vendorID == 0x05ac {
            // Common iPad identifiers in device name
            let lowerName = name.lowercased()
            return lowerName.contains("ipad") || 
                   lowerName.contains("apple mobile device") ||
                   // Additional checks for iPad Pro models
                   productID == 0x12a8 || // iPad Pro 12.9" (1st gen)
                   productID == 0x12ab || // iPad Pro 9.7"
                   productID == 0x13a1 || // iPad Pro 10.5"
                   productID == 0x13a2 || // iPad Pro 12.9" (2nd gen)
                   productID == 0x13a3 || // iPad Pro 11"
                   productID == 0x13a4 || // iPad Pro 12.9" (3rd gen)
                   productID == 0x13a5 || // iPad Pro 11" (2nd gen)
                   productID == 0x13a6 || // iPad Pro 12.9" (4th gen)
                   productID == 0x13a7 || // iPad Pro 11" (3rd gen)
                   productID == 0x13a8 || // iPad Pro 12.9" (5th gen)
                   productID == 0x13a9 || // iPad Pro 11" (4th gen)
                   productID == 0x13aa || // iPad Pro 12.9" (6th gen)
                   productID == 0x13ab || // iPad Pro 11" (5th gen)
                   productID == 0x13ac || // iPad Pro 12.9" (7th gen)
                   productID == 0x13ad    // iPad Pro 11" (6th gen)
        }
        return false
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
        
        // Try to get device name from IORegistry
        var deviceName = "Unknown Device"
        if let nameRef = IORegistryEntryCreateCFProperty(
            device,
            "USB Product Name" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue() as? String {
            deviceName = nameRef
        } else {
            // Fallback: use system_profiler to get device name
            deviceName = getDeviceNameViaSystemProfiler(vendorID: vendorID, productID: productID)
        }
        
        return USBDeviceInfo(
            name: deviceName,
            vendorID: vendorID,
            productID: productID,
            serialNumber: serialNumber
        )
    }
    
    private func getDeviceNameViaSystemProfiler(vendorID: UInt16, productID: UInt16) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        task.arguments = ["SPUSBDataType", "-xml"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [[String: Any]],
               let items = plist.first?["_items"] as? [[String: Any]] {
                return findDeviceName(in: items, vendorID: vendorID, productID: productID) ?? "USB Device"
            }
        } catch {
            Logger().log("Failed to run system_profiler: \(error.localizedDescription)")
        }
        
        return "USB Device"
    }
    
    private func findDeviceName(in items: [[String: Any]], vendorID: UInt16, productID: UInt16) -> String? {
        for item in items {
            if let itemVendorID = item["vendor_id"] as? Int,
               let itemProductID = item["product_id"] as? Int,
               UInt16(itemVendorID) == vendorID,
               UInt16(itemProductID) == productID,
               let name = item["_name"] as? String {
                return name
            }
            
            if let subItems = item["_items"] as? [[String: Any]],
               let name = findDeviceName(in: subItems, vendorID: vendorID, productID: productID) {
                return name
            }
        }
        return nil
    }
}

