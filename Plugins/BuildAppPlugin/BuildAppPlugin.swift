import PackagePlugin
import Foundation

@main
struct BuildAppPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let appName = "Auto Sidecar"
        let executableName = "AutoSidecar"
        
        print("🔨 Building Auto Sidecar.app...")
        print("")
        
        // Build in release mode
        print("📦 Compiling release binary...")
        let buildTool = try context.tool(named: "swift")
        let buildProcess = Process()
        buildProcess.executableURL = URL(fileURLWithPath: buildTool.path.string)
        buildProcess.arguments = ["build", "-c", "release", "--product", "auto-sidecar"]
        buildProcess.currentDirectoryURL = URL(fileURLWithPath: context.package.directory.string)
        
        try buildProcess.run()
        buildProcess.waitUntilExit()
        
        guard buildProcess.terminationStatus == 0 else {
            throw PluginError.buildFailed
        }
        
        print("✓ Build successful!")
        print("")
        
        // Create app bundle
        let packageDir = context.package.directory
        let appBundle = packageDir.appending(["\(appName).app"])
        let contentsDir = appBundle.appending("Contents")
        let macOSDir = contentsDir.appending("MacOS")
        let resourcesDir = contentsDir.appending("Resources")
        
        print("📁 Creating app bundle structure...")
        
        // Clean previous build
        if FileManager.default.fileExists(atPath: appBundle.string) {
            try FileManager.default.removeItem(atPath: appBundle.string)
        }
        
        try FileManager.default.createDirectory(atPath: macOSDir.string, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(atPath: resourcesDir.string, withIntermediateDirectories: true)
        
        // Copy executable
        let releaseBinary = packageDir.appending([".build", "release", "auto-sidecar"])
        let destExecutable = macOSDir.appending(executableName)
        
        print("📄 Copying executable...")
        try FileManager.default.copyItem(atPath: releaseBinary.string, toPath: destExecutable.string)
        
        // Make executable
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: destExecutable.string
        )
        
        // Copy Info.plist
        let infoPlist = packageDir.appending(["Resources", "Info.plist"])
        let destPlist = contentsDir.appending("Info.plist")
        
        print("📄 Copying Info.plist...")
        try FileManager.default.copyItem(atPath: infoPlist.string, toPath: destPlist.string)
        
        // Copy SidecarLauncher if it exists
        let sidecarLauncher = packageDir.appending("SidecarLauncher")
        if FileManager.default.fileExists(atPath: sidecarLauncher.string) {
            let destLauncher = resourcesDir.appending("SidecarLauncher")
            print("📄 Copying SidecarLauncher...")
            try FileManager.default.copyItem(atPath: sidecarLauncher.string, toPath: destLauncher.string)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destLauncher.string
            )
        } else {
            print("⚠️  Warning: SidecarLauncher not found")
        }
        
        print("")
        print("==========================================")
        print("✅ Auto Sidecar.app created successfully!")
        print("==========================================")
        print("")
        print("Location: \(appBundle.string)")
        print("")
        print("To install:")
        print("  1. Drag '\(appName).app' to /Applications")
        print("  2. Double-click to launch")
        print("  3. Grant Accessibility permissions")
        print("")
    }
}

enum PluginError: Error, CustomStringConvertible {
    case buildFailed
    
    var description: String {
        switch self {
        case .buildFailed:
            return "Build failed"
        }
    }
}


