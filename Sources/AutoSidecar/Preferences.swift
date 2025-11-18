import Foundation

class Preferences {
    static let shared = Preferences()
    
    private let defaults = UserDefaults.standard
    
    // Keys
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isAutoActivationEnabled = "isAutoActivationEnabled"
        static let shouldDisconnectOnUSBRemoval = "shouldDisconnectOnUSBRemoval"
        static let launchAtLogin = "launchAtLogin"
    }
    
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Keys.hasCompletedOnboarding) }
        set { defaults.set(newValue, forKey: Keys.hasCompletedOnboarding) }
    }
    
    var isAutoActivationEnabled: Bool {
        get { 
            // Check for legacy file flag first
            let legacyDisableFlagPath = NSHomeDirectory() + "/Library/Preferences/.auto-sidecar-disabled"
            if FileManager.default.fileExists(atPath: legacyDisableFlagPath) {
                return false
            }
            return defaults.object(forKey: Keys.isAutoActivationEnabled) as? Bool ?? true
        }
        set { 
            defaults.set(newValue, forKey: Keys.isAutoActivationEnabled)
            // Remove legacy flag if it exists
            let legacyDisableFlagPath = NSHomeDirectory() + "/Library/Preferences/.auto-sidecar-disabled"
            try? FileManager.default.removeItem(atPath: legacyDisableFlagPath)
        }
    }
    
    var shouldDisconnectOnUSBRemoval: Bool {
        get { defaults.bool(forKey: Keys.shouldDisconnectOnUSBRemoval) }
        set { defaults.set(newValue, forKey: Keys.shouldDisconnectOnUSBRemoval) }
    }
    
    var launchAtLogin: Bool {
        get { defaults.bool(forKey: Keys.launchAtLogin) }
        set { defaults.set(newValue, forKey: Keys.launchAtLogin) }
    }
}

