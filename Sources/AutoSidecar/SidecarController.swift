import Foundation

/// Modern Sidecar controller using async/await
actor SidecarController {
    private var cachedDeviceName: String?
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
        Task {
            await logSystemDiagnostics()
        }
    }
    
    private func logSystemDiagnostics() async {
        guard !hasLoggedDiagnostics else { return }
        hasLoggedDiagnostics = true
        
        await Logger.shared.info("=== Sidecar System Diagnostics ===")
        await Logger.shared.info("SidecarLauncher path: \(launcherPath)")
        await Logger.shared.info("SidecarLauncher exists: \(FileManager.default.fileExists(atPath: launcherPath))")
        
        // Check for common issues
        if !FileManager.default.fileExists(atPath: launcherPath) {
            await Logger.shared.error("⚠️  WARNING: SidecarLauncher not found!")
            await Logger.shared.error("   Run diagnose-devices.sh to troubleshoot")
        }
        
        // Log macOS version
        let version = ProcessInfo.processInfo.operatingSystemVersion
        await Logger.shared.info("macOS Version: \(version.majorVersion).\(version.minorVersion).\(version.patchVersion)")
        
        await Logger.shared.info("=== End Diagnostics ===")
    }
    
    // Check if Sidecar is currently connected
    func isConnected() async -> Bool {
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            return false
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launcherPath)
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
            return output.lowercased().contains("connected")
        } catch {
            return false
        }
    }
    
    // Connect to Sidecar using SidecarLauncher binary
    func enableSidecar() async -> Bool {
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            await Logger.shared.error("SidecarLauncher not found at \(launcherPath)")
            return false
        }
        
        return await connectViaSidecarLauncher()
    }
    
    // Disconnect Sidecar
    func disableSidecar() async -> Bool {
        guard FileManager.default.fileExists(atPath: launcherPath) else {
            await Logger.shared.error("SidecarLauncher not found at \(launcherPath)")
            return false
        }
        
        return await disconnectViaSidecarLauncher()
    }
    
    private func listDevices(maxRetries: Int = 3) async -> String? {
        for attempt in 1...maxRetries {
            let listTask = Process()
            listTask.executableURL = URL(fileURLWithPath: launcherPath)
            listTask.arguments = ["devices"]
            
            let listPipe = Pipe()
            listTask.standardOutput = listPipe
            listTask.standardError = listPipe
            
            do {
                await Logger.shared.info("Listing Sidecar devices (attempt \(attempt)/\(maxRetries))...")
                try listTask.run()
                listTask.waitUntilExit()
                
                let listData = listPipe.fileHandleForReading.readDataToEndOfFile()
                let listOutput = String(data: listData, encoding: .utf8) ?? ""
                
                let exitCode = listTask.terminationStatus
                await Logger.shared.info("SidecarLauncher devices exit code: \(exitCode)")
                if !listOutput.isEmpty {
                    await Logger.shared.info("SidecarLauncher devices output:\n\(listOutput)")
                }
                
                // Exit code 2 means no reachable devices
                if exitCode == 2 {
                    await Logger.shared.log("⚠️  No reachable Sidecar devices (exit code 2)")
                    if attempt == 1 {
                        await Logger.shared.info("Troubleshooting tips:")
                        await Logger.shared.info("  • Ensure iPad is unlocked and connected via USB")
                        await Logger.shared.info("  • Check that WiFi and Bluetooth are enabled")
                        await Logger.shared.info("  • Verify Handoff is enabled (System Settings > General > AirDrop & Handoff)")
                        await Logger.shared.info("  • Run diagnose-devices.sh for detailed diagnostics")
                    }
                    if attempt < maxRetries {
                        await Logger.shared.info("Waiting 2 seconds before retry...")
                        try? await Task.sleep(for: .seconds(2))
                        continue
                    }
                    return nil
                }
                
                // Exit code 4 means SidecarCore private error
                if exitCode == 4 {
                    await Logger.shared.log("⚠️  SidecarCore private error encountered (exit code 4)")
                    if attempt == 1 {
                        await Logger.shared.info("This usually indicates a system-level issue with Sidecar.")
                        await Logger.shared.info("Troubleshooting tips:")
                        await Logger.shared.info("  • Restart your Mac")
                        await Logger.shared.info("  • Sign out and back into iCloud")
                        await Logger.shared.info("  • Ensure iPad and Mac are on the same iCloud account")
                    }
                    if attempt < maxRetries {
                        await Logger.shared.info("Waiting 2 seconds before retry...")
                        try? await Task.sleep(for: .seconds(2))
                        continue
                    }
                    return nil
                }
                
                // Find iPad in the list
                let lines = listOutput.components(separatedBy: .newlines)
                let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                
                if let ipadName = nonEmptyLines.first(where: { $0.contains("iPad") })?.trimmingCharacters(in: .whitespacesAndNewlines) {
                    await Logger.shared.info("✓ Found iPad via SidecarLauncher: \(ipadName)")
                    return ipadName
                } else {
                    await Logger.shared.log("⚠️  No iPad found in device list output")
                    if !nonEmptyLines.isEmpty {
                        await Logger.shared.info("Available devices:")
                        for line in nonEmptyLines {
                            await Logger.shared.info("  • \(line)")
                        }
                    }
                    if attempt < maxRetries {
                        try? await Task.sleep(for: .seconds(2))
                        continue
                    }
                }
            } catch {
                await Logger.shared.error("❌ Failed to run SidecarLauncher devices: \(error.localizedDescription)")
                if attempt < maxRetries {
                    try? await Task.sleep(for: .seconds(2))
                    continue
                }
            }
        }
        
        return nil
    }
    
    private func connectViaSidecarLauncher() async -> Bool {
        // List devices with retry logic
        guard let ipadName = await listDevices() else {
            await Logger.shared.error("❌ No iPad found after retries")
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
            await Logger.shared.info("Connecting to \(ipadName)...")
            try connectTask.run()
            connectTask.waitUntilExit()
            
            let connectData = connectPipe.fileHandleForReading.readDataToEndOfFile()
            let connectOutput = String(data: connectData, encoding: .utf8) ?? ""
            
            let exitCode = connectTask.terminationStatus
            await Logger.shared.info("SidecarLauncher connect exit code: \(exitCode)")
            if !connectOutput.isEmpty {
                await Logger.shared.info("SidecarLauncher connect output:\n\(connectOutput)")
            }
            
            if exitCode == 0 {
                await Logger.shared.info("✓ Sidecar connected successfully via SidecarLauncher")
                return true
            } else {
                // Check if error is "already in use" - that means it's already connected!
                if connectOutput.contains("AlreadyInUse") || connectOutput.contains("already") {
                    await Logger.shared.info("✓ Sidecar already connected (AlreadyInUse error)")
                    return true
                }
                await Logger.shared.error("❌ SidecarLauncher connection failed (exit code \(exitCode)): \(connectOutput)")
                return false
            }
        } catch {
            await Logger.shared.error("❌ Failed to run SidecarLauncher connect: \(error.localizedDescription)")
            return false
        }
    }
    
    private func disconnectViaSidecarLauncher() async -> Bool {
        // Try to get device name - either from cache or by listing devices
        var deviceName = cachedDeviceName
        
        if deviceName == nil {
            await Logger.shared.info("No cached device name, attempting to list devices...")
            deviceName = await listDevices(maxRetries: 1)
        }
        
        guard let name = deviceName else {
            await Logger.shared.error("❌ Cannot disconnect: no device name available")
            return false
        }
        
        let task = Process()
        task.executableURL = URL(fileURLWithPath: launcherPath)
        task.arguments = ["disconnect", name]
        
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        
        do {
            await Logger.shared.info("Disconnecting from \(name)...")
            try task.run()
            task.waitUntilExit()
            
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            
            let exitCode = task.terminationStatus
            await Logger.shared.info("SidecarLauncher disconnect exit code: \(exitCode)")
            if !output.isEmpty {
                await Logger.shared.info("SidecarLauncher disconnect output:\n\(output)")
            }
            
            if exitCode == 0 {
                await Logger.shared.info("✓ Sidecar disconnected successfully")
                cachedDeviceName = nil
                return true
            } else {
                await Logger.shared.error("❌ SidecarLauncher disconnect failed (exit code \(exitCode)): \(output)")
                return false
            }
        } catch {
            await Logger.shared.error("❌ Failed to run SidecarLauncher disconnect: \(error.localizedDescription)")
            return false
        }
    }
}
