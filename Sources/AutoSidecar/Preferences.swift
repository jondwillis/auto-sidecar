import Foundation
import Observation

/// Observable preferences using modern @Observable macro
@available(macOS 14.0, *)
@Observable
final class Preferences {
    static let shared = Preferences()
    
    private let defaults = UserDefaults.standard
    
    private enum Keys {
        static let hasCompletedOnboarding = "hasCompletedOnboarding"
        static let isAutoActivationEnabled = "isAutoActivationEnabled"
        static let shouldDisconnectOnUSBRemoval = "shouldDisconnectOnUSBRemoval"
        static let launchAtLogin = "launchAtLogin"
    }
    
    var hasCompletedOnboarding: Bool {
        get {
            access(keyPath: \.hasCompletedOnboarding)
            return defaults.bool(forKey: Keys.hasCompletedOnboarding)
        }
        set {
            withMutation(keyPath: \.hasCompletedOnboarding) {
                defaults.set(newValue, forKey: Keys.hasCompletedOnboarding)
            }
        }
    }
    
    var isAutoActivationEnabled: Bool {
        get {
            access(keyPath: \.isAutoActivationEnabled)
            // Check for legacy file flag first
            let legacyDisableFlagPath = NSHomeDirectory() + "/Library/Preferences/.auto-sidecar-disabled"
            if FileManager.default.fileExists(atPath: legacyDisableFlagPath) {
                return false
            }
            return defaults.object(forKey: Keys.isAutoActivationEnabled) as? Bool ?? true
        }
        set {
            withMutation(keyPath: \.isAutoActivationEnabled) {
                defaults.set(newValue, forKey: Keys.isAutoActivationEnabled)
                // Remove legacy flag if it exists
                let legacyDisableFlagPath = NSHomeDirectory() + "/Library/Preferences/.auto-sidecar-disabled"
                try? FileManager.default.removeItem(atPath: legacyDisableFlagPath)
            }
        }
    }
    
    var shouldDisconnectOnUSBRemoval: Bool {
        get {
            access(keyPath: \.shouldDisconnectOnUSBRemoval)
            return defaults.bool(forKey: Keys.shouldDisconnectOnUSBRemoval)
        }
        set {
            withMutation(keyPath: \.shouldDisconnectOnUSBRemoval) {
                defaults.set(newValue, forKey: Keys.shouldDisconnectOnUSBRemoval)
            }
        }
    }
    
    var launchAtLogin: Bool {
        get {
            access(keyPath: \.launchAtLogin)
            return defaults.bool(forKey: Keys.launchAtLogin)
        }
        set {
            withMutation(keyPath: \.launchAtLogin) {
                defaults.set(newValue, forKey: Keys.launchAtLogin)
            }
        }
    }
    
    private init() {}
}

