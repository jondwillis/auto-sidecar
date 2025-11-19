import Foundation
import OSLog

/// Modern, structured logger using OSLog subsystem
actor Logger {
    static let shared = Logger()
    
    private let logger = os.Logger(subsystem: "com.jonwillis.autosidecar", category: "general")
    private let logFileURL: URL
    private var fileHandle: FileHandle?
    
    private init() {
        let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
        
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        logFileURL = logDirectory.appendingPathComponent("auto-sidecar.log")
        
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
    }
    
    func log(_ message: String, level: OSLogType = .default) {
        // Use structured logging with OSLog
        logger.log(level: level, "\(message, privacy: .public)")
        
        // Also write to file for legacy compatibility
        Task.detached { [logFileURL] in
            let timestamp = Date.now.formatted(date: .numeric, time: .standard)
            let logMessage = "[\(timestamp)] \(message)\n"
            
            guard let data = logMessage.data(using: .utf8),
                  let handle = try? FileHandle(forWritingTo: logFileURL) else { return }
            
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            _ = try? handle.write(contentsOf: data)
        }
    }
    
    func debug(_ message: String) {
        log(message, level: .debug)
    }
    
    func info(_ message: String) {
        log(message, level: .info)
    }
    
    func error(_ message: String) {
        log(message, level: .error)
    }
}

