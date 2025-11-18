import Foundation

class Logger {
    private let logFileURL: URL
    private let dateFormatter: DateFormatter
    private let fileHandle: FileHandle?
    
    init() {
        let logDirectory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs")
        
        // Create Logs directory if it doesn't exist
        try? FileManager.default.createDirectory(at: logDirectory, withIntermediateDirectories: true)
        
        logFileURL = logDirectory.appendingPathComponent("auto-sidecar.log")
        
        dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        // Create log file if it doesn't exist
        if !FileManager.default.fileExists(atPath: logFileURL.path) {
            FileManager.default.createFile(atPath: logFileURL.path, contents: nil)
        }
        
        fileHandle = try? FileHandle(forWritingTo: logFileURL)
        fileHandle?.seekToEndOfFile()
    }
    
    func log(_ message: String) {
        let timestamp = dateFormatter.string(from: Date())
        let logMessage = "[\(timestamp)] \(message)\n"
        
        // Print to console
        print(logMessage, terminator: "")
        
        // Write to file - let OS handle buffering for better energy efficiency
        if let data = logMessage.data(using: .utf8) {
            fileHandle?.write(data)
        }
    }
    
    deinit {
        fileHandle?.closeFile()
    }
}

