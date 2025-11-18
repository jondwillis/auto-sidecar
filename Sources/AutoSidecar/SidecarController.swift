import Foundation

class SidecarController {
    private let logger = Logger()
    private var cachedDeviceName: String?
    private var lastDeviceListAttempt: Date?
    private let deviceListRetryInterval: TimeInterval = 2.0
    private var hasLoggedDiagnostics = false
    
    private let launcherPath: String = {
        // Look for SidecarLauncher in multiple locations
        let possiblePaths = [
            Bundle.main.resourcePath.map { "\($0)/SidecarLauncher" },
            "\(NSHomeDirectory())/auto-continuity/SidecarLauncher",
            "/usr/local/bin/SidecarLauncher",
            "\(FileManager.default.currentDirectoryPath)/SidecarLauncher"
        ].compactMap { $0 }
        
        for path in possiblePaths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Fallback to project directory
        return "\(NSHomeDirectory())/auto-continuity/SidecarLauncher"
    }()
    
    init() {
        logSystemDiagnostics()
    }
    
    private func logSystemDiagnostics() {
        guard !hasLoggedDiagnostics else { return }
        hasLoggedDiagnostics = true
        
        logger.log("=== Sidecar System Diagnostics ===")
        logger.log("SidecarLauncher path: \(launcherPath)")
        logger.log("SidecarLauncher exists: \(FileManager.default.fileExists(atPath: launcherPath))")
        
        // Check for common issues
        if !FileManager.default.fileExists(atPath: launcherPath) {
            logger.log("⚠️  WARNING: SidecarLauncher not found!")
            logger.log("   Run diagnose-devices.sh to troubleshoot")
        }
        
        // Log macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        logger.log("macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        
        logger.log("=== End Diagnostics ===")
    }
    
    // Check if Sidecar is currently connected
    func isConnected(completion: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let task = Process()
            task.executableURL = URL(fileURLWithPath: self.launcherPath)
            task.arguments = ["status"]
            
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: data, encoding: .utf8) ?? ""
                
                // If status shows "Connected" or similar, it's connected
                let isConnected = output.lowercased().contains("connected")
                DispatchQueue.main.async {
                    completion(isConnected)
                }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }
    
    // Connect to Sidecar using SidecarLauncher binary
    func enableSidecar(completion: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            logger.log("SidecarLauncher not found at \(launcherPath)")
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let success = self.connectViaSidecarLauncher()
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    // Disconnect Sidecar
    func disableSidecar(completion: @escaping (Bool) -> Void) {
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            logger.log("SidecarLauncher not found at \(launcherPath)")
            completion(false)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            let success = self.disconnectViaSidecarLauncher()
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
    
    private func listDevices(maxRetries: Int = 3) -> String? {
        for attempt in 1...maxRetries {
            let listTask = Process()
            listTask.executableURL = URL(fileURLWithPath: launcherPath)
            listTask.arguments = ["devices"]
            
            let listPipe = Pipe()
            listTask.standardOutput = listPipe
            listTask.standardError = listPipe
            
            do {
                logger.log("Listing Sidecar devices (attempt \(attempt)/\(maxRetries))...")
                try listTask.run()
                listTask.waitUntilExit()
                
                let listData = listPipe.fileHandleForReading.readDataToEndOfFile()
                let listOutput = String(data: listData, encoding: .utf8) ?? ""
                
                let exitCode = listTask.terminationStatus
                logger.log("SidecarLauncher devices exit code: \(exitCode)")
                if !listOutput.isEmpty {
                    logger.log("SidecarLauncher devices output:\n\(listOutput)")
                }
                
                // Exit code 2 means no reachable devices
                if exitCode == 2 {
                    logger.log("⚠️  No reachable Sidecar devices (exit code 2)")
                    if attempt == 1 {
                        logger.log("Troubleshooting tips:")
                        logger.log("  • Ensure iPad is unlocked and connected via USB")
                        logger.log("  • Check that WiFi and Bluetooth are enabled")
                        logger.log("  • Verify Handoff is enabled (System Settings > General > AirDrop & Handoff)")
                        logger.log("  • Run diagnose-devices.sh for detailed diagnostics")
                    }
                    if attempt < maxRetries {
                        logger.log("Waiting 2 seconds before retry...")
                        Thread.sleep(forTimeInterval: 2.0)
                        continue
                    }
                    return nil
                }
                
                // Exit code 4 means SidecarCore private error
                if exitCode == 4 {
                    logger.log("⚠️  SidecarCore private error encountered (exit code 4)")
                    if attempt == 1 {
                        logger.log("This usually indicates a system-level issue with Sidecar.")
                        logger.log("Troubleshooting tips:")
                        logger.log("  • Restart your Mac")
                        logger.log("  • Sign out and back into iCloud")
                        logger.log("  • Ensure iPad and Mac are on the same iCloud account")
                    }
                    if attempt < maxRetries {
                        logger.log("Waiting 2 seconds before retry...")
                        Thread.sleep(forTimeInterval: 2.0)
                        continue
                    }
                    return nil
                }
                
                // Find iPad in the list
                let lines = listOutput.components(separatedBy: .newlines)
                let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                if let ipadName = nonEmptyLines.first(where: { $0.contains("iPad") })?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    logger.log("✓ Found iPad via SidecarLauncher: \(ipadName)")
                    return ipadName
                } else {
                    logger.log("⚠️  No iPad found in device list output")
                    if !nonEmptyLines.isEmpty {
                        logger.log("Available devices:")
                        for line in nonEmptyLines {
                            logger.log("  • \(line)")
                        }
                    }
                    if attempt < maxRetries {
                        Thread.sleep(forTimeInterval: 2.0)
                        continue
                    }
                }
            } catch {
                logger.log("❌ Failed to run SidecarLauncher devices: \(error.localizedDescription)")
                if attempt < maxRetries {
                    Thread.sleep(forTimeInterval: 2.0)
                    continue
                }
            }
        }
        
        return nil
    }
    
    private func connectViaSidecarLauncher() -> Bool {
        // List devices with retry logic
        guard let ipadName = listDevices() else {
            logger.log("❌ No iPad found after retries")
            return false
        }
        
        // Cache the device name for disconnect
        cachedDeviceName = ipadName
        
        // Connect to iPad
        let connectTask = Process()
        connectTask.executableURL = URL(fileURLWithPath: launcherPath)
        connectTask.arguments = ["connect", ipadName]
        
        let connectPipe = Pipe()
        connectTask.standardOutput = connectPipe
        connectTask.standardError = connectPipe
        
        do {
            logger.log("Connecting to \(ipadName)...")
            try connectTask.run()
            connectTask.waitUntilExit()
            
            let connectData = connectPipe.fileHandleForReading.readDataToEndOfFile()
            let connectOutput = String(data: connectData, encoding: .utf8) ?? ""
            
            let exitCode = connectTask.terminationStatus
            logger.log("SidecarLauncher connect exit code: \(exitCode)")
            if !connectOutput.isEmpty {
                logger.log("SidecarLauncher connect output:\n\(connectOutput)")
            }
            
            if exitCode == 0 {
                logger.log("✓ Sidecar connected successfully via SidecarLauncher")
                return true
            } else {
                // Check if error is "already in use" - that means it's already connected!
                if connectOutput.contains("AlreadyInUse") || connectOutput.contains("already") {
                    logger.log("✓ Sidecar already connected (AlreadyInUse error)")
                    return true
                }
                logger.log("❌ SidecarLauncher connection failed (exit code \(exitCode)): \(connectOutput)")
                return false
            }
        } catch {
            logger.log("❌ Failed to run SidecarLauncher connect: \(error.localizedDescription)")
            return false
        }
    }
    
    private func disconnectViaSidecarLauncher() -> Bool {
        // Try to get device name - either from cache or by listing devices
        var deviceName = cachedDeviceName
        
        if deviceName == nil {
            logger.log("No cached device name, attempting to list devices...")
            deviceName = listDevices(maxRetries: 1)
        }
        
        guard let name = deviceName else {
            logger.log("❌ Cannot disconnect: no device name available")
            return false
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launcherPath)
        task.arguments = ["disconnect", name]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            logger.log("Disconnecting from \(name)...")
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let exitCode = task.terminationStatus
            logger.log("SidecarLauncher disconnect exit code: \(exitCode)")
            if !output.isEmpty {
                logger.log("SidecarLauncher disconnect output:\n\(output)")
            }
            
            if exitCode == 0 {
                logger.log("✓ Sidecar disconnected successfully")
                cachedDeviceName = nil
                return true
            } else {
                logger.log("❌ SidecarLauncher disconnect failed (exit code \(exitCode)): \(output)")
                return false
            }
        } catch {
            logger.log("❌ Failed to run SidecarLauncher disconnect: \(error.localizedDescription)")
            return false
        }
    }
}
