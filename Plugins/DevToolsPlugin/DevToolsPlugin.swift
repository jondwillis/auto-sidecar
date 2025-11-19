import PackagePlugin
import Foundation

@main
struct DevToolsPlugin: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let packageDir = context.package.directory
        
        guard let command = arguments.first else {
            printHelp()
            return
        }
        
        switch command {
        case "validate":
            try await runValidation(packageDir: packageDir, buildTest: arguments.contains("--build"))
        case "diagnose":
            try await runScript(packageDir: packageDir, script: "scripts/tools/diagnose-devices.sh")
        case "test":
            try await runScript(packageDir: packageDir, script: "scripts/dev/test-device-detection.sh")
        case "status":
            try await runScript(packageDir: packageDir, script: "scripts/tools/status.sh")
        case "enable":
            try await runScript(packageDir: packageDir, script: "scripts/tools/enable.sh")
        case "disable":
            try await runScript(packageDir: packageDir, script: "scripts/tools/disable.sh")
        case "check":
            try await runScript(packageDir: packageDir, script: "scripts/tools/check-permissions.sh")
        case "dev-setup":
            try await runScript(packageDir: packageDir, script: "scripts/dev/install-git-hooks.sh")
        case "help", "--help", "-h":
            printHelp()
        default:
            print("Unknown command: \(command)")
            print("")
            printHelp()
        }
    }
    
    private func runScript(packageDir: Path, script: String) async throws {
        let scriptPath = packageDir.appending(script.split(separator: "/").map(String.init))
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath.string]
        process.currentDirectoryURL = URL(fileURLWithPath: packageDir.string)
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw PluginError.scriptFailed(script)
        }
    }
    
    private func runValidation(packageDir: Path, buildTest: Bool) async throws {
        let scriptPath = packageDir.appending(["scripts", "dev", "validate-local.sh"])
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = buildTest ? [scriptPath.string, "--build"] : [scriptPath.string]
        process.currentDirectoryURL = URL(fileURLWithPath: packageDir.string)
        
        try process.run()
        process.waitUntilExit()
        
        if process.terminationStatus != 0 {
            throw PluginError.validationFailed
        }
    }
    
    private func printHelp() {
        print("""
        Auto Sidecar Development Tools
        
        Usage: swift package dev-tools <command> [options]
        
        Commands:
          validate           Run validation checks
          validate --build   Run validation with build test
          diagnose           Run comprehensive diagnostics
          test               Run device detection tests
          status             Show app status
          enable             Enable auto-activation
          disable            Disable auto-activation
          check              Check accessibility permissions
          dev-setup          Setup git hooks
          help               Show this help
        
        Examples:
          swift package dev-tools validate
          swift package dev-tools diagnose
          swift package dev-tools status
        """)
    }
}

enum PluginError: Error, CustomStringConvertible {
    case scriptFailed(String)
    case validationFailed
    
    var description: String {
        switch self {
        case .scriptFailed(let script):
            return "Script failed: \(script)"
        case .validationFailed:
            return "Validation failed"
        }
    }
}


