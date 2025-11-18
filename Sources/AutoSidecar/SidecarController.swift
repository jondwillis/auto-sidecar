import Foundation

class SidecarController {
    private let logger = Logger()
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
    
    private func connectViaSidecarLauncher() -> Bool {
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
            return false
        }
    }
}
