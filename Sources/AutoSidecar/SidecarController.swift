import Foundation
import AppKit
import Darwin

class SidecarController {
    private let logger = Logger()
    
    // Check if Sidecar is currently connected
    func isSidecarConnected() -> Bool {
        let launcherPath = "/Users/jon/auto-continuity/SidecarLauncher"
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            return false
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launcherPath)
        task.arguments = ["devices"]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            // If we get devices but connection check fails, Sidecar might be connected
            // Check by trying to connect - if it says "already in use", it's connected
            let lines = output.components(separatedBy: .newlines)
            if let ipadName = lines.first(where: { $0.contains("iPad") && !$0.isEmpty })?.trimmingCharacters(in: .whitespacesAndNewlines) {
                // Try a quick connect to see if already connected
                let connectTask = Process()
                connectTask.executableURL = URL(fileURLWithPath: launcherPath)
                connectTask.arguments = ["connect", ipadName]
                
                let connectPipe = Pipe()
                connectTask.standardOutput = connectPipe
                connectTask.standardError = connectPipe
                
                try connectTask.run()
                connectTask.waitUntilExit()
                
                let connectData = connectPipe.fileHandleForReading.readDataToEndOfFile()
                let connectOutput = String(data: connectData, encoding: .utf8) ?? ""
                
                // If it says "already in use" or "connected", Sidecar is active
                return connectOutput.contains("AlreadyInUse") || 
                       connectOutput.contains("already") ||
                       connectOutput.contains("connected") ||
                       connectTask.terminationStatus == 0
            }
        } catch {
            // If we can't check, assume not connected
        }
        
        return false
    }
    
    // Use SidecarLauncher binary (from Mirror project) or SidecarCore framework
    func enableSidecar(completion: @escaping (Bool) -> Void) {
        // Try using SidecarLauncher binary first (most reliable)
        if let result = connectViaSidecarLauncher() {
            completion(result)
            return
        }
        
        // Try using SidecarCore framework
        if let result = connectViaSidecarCore() {
            completion(result)
            return
        }
        
        // Fallback to AppleScript if both fail
        enableSidecarViaAppleScript(completion: completion)
    }
    
    private func connectViaSidecarLauncher() -> Bool? {
        // Try to use SidecarLauncher binary (if available)
        let launcherPath = "/Users/jon/auto-continuity/SidecarLauncher"
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            return nil
        }
        
        // List devices
        let listTask = Process()
        listTask.executableURL = URL(fileURLWithPath: launcherPath)
        listTask.arguments = ["devices"]
        
        let listPipe = Pipe()
        listTask.standardOutput = listPipe
        listTask.standardError = listPipe
        
        do {
            try listTask.run()
            listTask.waitUntilExit()
            
            let listData = listPipe.fileHandleForReading.readDataToEndOfFile()
            let listOutput = String(data: listData, encoding: .utf8) ?? ""
            
            // Find iPad in the list
            let lines = listOutput.components(separatedBy: .newlines)
            guard let ipadName = lines.first(where: { $0.contains("iPad") && !$0.isEmpty })?.trimmingCharacters(in: .whitespacesAndNewlines) else {
                logger.log("No iPad found in SidecarLauncher device list")
                return false
            }
            
            logger.log("Found iPad via SidecarLauncher: \(ipadName)")
            
            // Connect to iPad
            let connectTask = Process()
            connectTask.executableURL = URL(fileURLWithPath: launcherPath)
            connectTask.arguments = ["connect", ipadName]
            
            let connectPipe = Pipe()
            connectTask.standardOutput = connectPipe
            connectTask.standardError = connectPipe
            
            try connectTask.run()
            connectTask.waitUntilExit()
            
            let connectData = connectPipe.fileHandleForReading.readDataToEndOfFile()
            let connectOutput = String(data: connectData, encoding: .utf8) ?? ""
            
            let success = connectTask.terminationStatus == 0
            if success {
                logger.log("Sidecar connected successfully via SidecarLauncher")
                return true
            } else {
                // Check if error is "already in use" - that means it's already connected!
                if connectOutput.contains("AlreadyInUse") || connectOutput.contains("already") {
                    logger.log("Sidecar already connected (AlreadyInUse error)")
                    return true
                }
                logger.log("SidecarLauncher connection failed: \(connectOutput)")
                return false
            }
        } catch {
            logger.log("Failed to run SidecarLauncher: \(error.localizedDescription)")
            return nil
        }
    }
    
    private func connectViaSidecarCore() -> Bool? {
        // Load the private SidecarCore framework
        let frameworkPath = "/System/Library/PrivateFrameworks/SidecarCore.framework/SidecarCore"
        guard let framework = dlopen(frameworkPath, RTLD_LAZY) else {
            logger.log("SidecarCore framework not available: \(String(cString: dlerror()))")
            return nil
        }
        defer { dlclose(framework) }
        
        // Get SidecarDisplayManager class
        guard let managerClass = NSClassFromString("SidecarDisplayManager") as? NSObject.Type else {
            logger.log("SidecarDisplayManager class not found")
            return nil
        }
        
        // Get shared instance
        guard let sharedInstance = managerClass.perform(NSSelectorFromString("sharedManager"))?.takeUnretainedValue() as? NSObject else {
            logger.log("Failed to get SidecarDisplayManager instance")
            return nil
        }
        
        // Get available devices
        guard let devices = sharedInstance.perform(NSSelectorFromString("devices"))?.takeUnretainedValue() as? [AnyObject] else {
            logger.log("No Sidecar devices available")
            return false
        }
        
        // Find iPad device
        for device in devices {
            guard let deviceName = device.value(forKey: "name") as? String else { continue }
            if deviceName.contains("iPad") {
                logger.log("Found iPad device: \(deviceName)")
                
                // Connect to device using Objective-C runtime
                let connectSelector = NSSelectorFromString("connectToDevice:completion:")
                if sharedInstance.responds(to: connectSelector) {
                    var success = false
                    var connectionError: Error?
                    let semaphore = DispatchSemaphore(value: 0)
                    
                    // Use IMP to call the method with completion block
                    typealias ConnectBlock = @convention(block) (Error?) -> Void
                    let completionBlock: ConnectBlock = { (error: Error?) in
                        connectionError = error
                        success = (error == nil)
                        if let error = error {
                            self.logger.log("Sidecar connection error: \(error.localizedDescription)")
                        } else {
                            self.logger.log("Sidecar connected successfully via SidecarCore")
                        }
                        semaphore.signal()
                    }
                    
                    // Call using perform with the block
                    let imp = sharedInstance.method(for: connectSelector)
                    typealias ConnectMethod = @convention(c) (NSObject, Selector, AnyObject, @escaping ConnectBlock) -> Void
                    let method = unsafeBitCast(imp, to: ConnectMethod.self)
                    method(sharedInstance, connectSelector, device, completionBlock)
                    
                    // Wait for completion (with timeout)
                    if semaphore.wait(timeout: .now() + 10.0) == .timedOut {
                        logger.log("Sidecar connection timed out")
                        return false
                    }
                    
                    return success
                } else {
                    logger.log("connectToDevice:completion: method not available")
                }
            }
        }
        
        logger.log("No iPad found in Sidecar devices")
        return false
    }
    
    private func enableSidecarViaAppleScript(completion: @escaping (Bool) -> Void) {
        // Use AppleScript to enable Sidecar via System Settings (more reliable than Control Center)
        let script = """
        tell application "System Settings"
            activate
        end tell
        
        tell application "System Events"
            try
                -- Open Displays settings using URL scheme
                do shell script "open 'x-apple.systempreferences:com.apple.preference.displays'"
                delay 2
                
                -- Wait for Displays window to appear
                set maxWait to 10
                set waitCount to 0
                repeat until (exists window 1 of process "System Settings") or waitCount > maxWait
                    delay 0.5
                    set waitCount to waitCount + 1
                end repeat
                
                if not (exists window 1 of process "System Settings") then
                    return "false:WindowNotFound"
                end if
                
                tell process "System Settings"
                    -- Try to find the display selection popup/button
                    -- The structure varies, so try multiple approaches
                    
                    -- Method 1: Look for popup button with display options
                    try
                        set popupButtons to pop up buttons of window 1
                        repeat with popupButton in popupButtons
                            try
                                click popupButton
                                delay 0.5
                                
                                -- Look for iPad in the menu
                                try
                                    set menuItems to menu items of menu 1 of popupButton
                                    repeat with menuItem in menuItems
                                        try
                                            set itemName to name of menuItem as string
                                            if itemName contains "iPad" then
                                                click menuItem
                                                delay 1
                                                tell application "System Settings" to quit
                                                return "true:Method1-Popup"
                                            end if
                                        end try
                                    end repeat
                                end try
                                
                                -- Close menu if iPad not found
                                key code 53
                                delay 0.3
                            end try
                        end repeat
                    end try
                    
                    -- Method 2: Look for "Add Display" or similar button
                    try
                        set allButtons to buttons of window 1
                        repeat with aButton in allButtons
                            try
                                set buttonName to name of aButton as string
                                if buttonName contains "Add Display" or buttonName contains "Display" or buttonName contains "Use" then
                                    click aButton
                                    delay 1
                                    
                                    -- Look for iPad in resulting menu
                                    try
                                        set menuItems to menu items of menu 1
                                        repeat with menuItem in menuItems
                                            try
                                                set itemName to name of menuItem as string
                                                if itemName contains "iPad" then
                                                    click menuItem
                                                    delay 1
                                                    tell application "System Settings" to quit
                                                    return "true:Method2-Button"
                                                end if
                                            end try
                                        end repeat
                                    end try
                                    
                                    key code 53
                                    delay 0.3
                                end if
                            end try
                        end repeat
                    end try
                    
                    -- Method 3: Try keyboard navigation (Command+F to search, then type "display")
                    try
                        keystroke "f" using command down
                        delay 0.5
                        keystroke "display"
                        delay 1
                        keystroke return
                        delay 2
                        
                        -- Try to find and click iPad option
                        try
                            set allButtons to buttons of window 1
                            repeat with aButton in allButtons
                                try
                                    set buttonName to name of aButton as string
                                    if buttonName contains "iPad" then
                                        click aButton
                                        delay 1
                                        tell application "System Settings" to quit
                                        return "true:Method3-Search"
                                    end if
                                end try
                            end repeat
                        end try
                    end try
                    
                    tell application "System Settings" to quit
                end tell
                
                return "false:AllMethodsFailed"
            on error errorMessage
                try
                    tell application "System Settings" to quit
                end try
                return "false:Error-" & errorMessage
            end try
        end tell
        """
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // Use NSAppleScript instead of osascript to avoid permission issues
            guard let appleScript = NSAppleScript(source: script) else {
                DispatchQueue.main.async {
                    self?.logger.log("Failed to create NSAppleScript")
                    completion(false)
                }
                return
            }
            
            var errorDict: NSDictionary?
            let result = appleScript.executeAndReturnError(&errorDict)
            
            DispatchQueue.main.async {
                if let error = errorDict {
                    let errorMessage = error[NSAppleScript.errorMessage] as? String ?? "Unknown error"
                    let errorNumber = error[NSAppleScript.errorNumber] as? Int ?? -1
                    self?.logger.log("AppleScript error: \(errorMessage) (code: \(errorNumber))")
                    completion(false)
                } else {
                    let output = result.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    let success = output.hasPrefix("true")
                    
                    if success {
                        let method = output.contains(":") ? String(output.split(separator: ":").last ?? "") : "unknown"
                        self?.logger.log("Sidecar enabled successfully via AppleScript (Method: \(method))")
                    } else {
                        self?.logger.log("Failed to enable Sidecar via AppleScript. Output: '\(output)'")
                        if !output.isEmpty {
                            self?.logger.log("AppleScript details: \(output)")
                        }
                    }
                    completion(success)
                }
            }
        }
    }
    
    // Alternative method using direct menu bar interaction
    func enableSidecarViaMenuBar(completion: @escaping (Bool) -> Void) {
        let script = """
        tell application "System Events"
            try
                -- Access Control Center via menu bar
                tell application process "ControlCenter"
                    -- Find Screen Mirroring button in menu bar
                    set screenMirroringButton to menu bar item "Screen Mirroring" of menu bar 1
                    click screenMirroringButton
                    delay 1
                    
                    -- Find and click iPad option
                    try
                        set ipadOption to menu item whose name contains "iPad" of menu 1 of screenMirroringButton
                        click ipadOption
                        delay 0.5
                        return true
                    on error
                        -- iPad not found, close menu
                        key code 53
                        return false
                    end try
                end tell
            on error errorMessage
                return false
            end try
        end tell
        """
        
        executeAppleScript(script, completion: completion)
    }
    
    private func executeAppleScript(_ script: String, completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            task.arguments = ["-e", script]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                let success = task.terminationStatus == 0
                
                DispatchQueue.main.async {
                    if success {
                        self?.logger.log("AppleScript executed successfully")
                    } else {
                        self?.logger.log("AppleScript failed. Output: \(output)")
                    }
                    completion(success)
                }
            } catch {
                DispatchQueue.main.async {
                    self?.logger.log("Failed to execute AppleScript: \(error.localizedDescription)")
                    completion(false)
                }
            }
        }
    }
}

