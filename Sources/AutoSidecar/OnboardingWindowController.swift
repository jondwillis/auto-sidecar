import Cocoa
import ServiceManagement

class OnboardingWindowController: NSWindowController {
    private var contentView: OnboardingView!
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Welcome to Auto Sidecar"
        window.center()
        window.isReleasedWhenClosed = false
        
        super.init(window: window)
        
        contentView = OnboardingView(windowController: self)
        window.contentView = contentView
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func completeOnboarding() {
        Preferences.shared.hasCompletedOnboarding = true
        window?.close()
    }
}

class OnboardingView: NSView {
    weak var windowController: OnboardingWindowController?
    
    private let titleLabel = NSTextField(labelWithString: "Welcome to Auto Sidecar")
    private let subtitleLabel = NSTextField(labelWithString: "Let's get you set up to automatically connect your iPad as a Sidecar display")
    
    private let permissionsTitle = NSTextField(labelWithString: "Permissions")
    private let accessibilityCheckbox = NSButton(checkboxWithTitle: "Accessibility Access (Required)", target: nil, action: nil)
    private let accessibilityButton = NSButton(title: "Grant Permission", target: nil, action: #selector(openAccessibilityPreferences))
    
    private let preferencesTitle = NSTextField(labelWithString: "Preferences")
    private let launchAtLoginCheckbox = NSButton(checkboxWithTitle: "Launch at Login", target: nil, action: #selector(toggleLaunchAtLogin))
    private let disconnectOnRemovalCheckbox = NSButton(checkboxWithTitle: "Disconnect Sidecar when iPad is unplugged", target: nil, action: #selector(toggleDisconnectOnRemoval))
    
    private let doneButton = NSButton(title: "Get Started", target: nil, action: #selector(completeOnboarding))
    
    init(windowController: OnboardingWindowController) {
        self.windowController = windowController
        super.init(frame: .zero)
        setupUI()
        updateAccessibilityStatus()
        
        // Start a timer to check accessibility status
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateAccessibilityStatus()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        // Title
        titleLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        titleLabel.alignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(titleLabel)
        
        // Subtitle
        subtitleLabel.font = NSFont.systemFont(ofSize: 13)
        subtitleLabel.alignment = .center
        subtitleLabel.textColor = .secondaryLabelColor
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(subtitleLabel)
        
        // Permissions section
        permissionsTitle.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        permissionsTitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(permissionsTitle)
        
        accessibilityCheckbox.isEnabled = false
        accessibilityCheckbox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accessibilityCheckbox)
        
        accessibilityButton.bezelStyle = .rounded
        accessibilityButton.target = self
        accessibilityButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(accessibilityButton)
        
        // Preferences section
        preferencesTitle.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        preferencesTitle.translatesAutoresizingMaskIntoConstraints = false
        addSubview(preferencesTitle)
        
        launchAtLoginCheckbox.state = Preferences.shared.launchAtLogin ? .on : .off
        launchAtLoginCheckbox.target = self
        launchAtLoginCheckbox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(launchAtLoginCheckbox)
        
        disconnectOnRemovalCheckbox.state = Preferences.shared.shouldDisconnectOnUSBRemoval ? .on : .off
        disconnectOnRemovalCheckbox.target = self
        disconnectOnRemovalCheckbox.translatesAutoresizingMaskIntoConstraints = false
        addSubview(disconnectOnRemovalCheckbox)
        
        // Done button
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.target = self
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(doneButton)
        
        // Layout
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 40),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            subtitleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            subtitleLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            permissionsTitle.topAnchor.constraint(equalTo: subtitleLabel.bottomAnchor, constant: 40),
            permissionsTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            
            accessibilityCheckbox.topAnchor.constraint(equalTo: permissionsTitle.bottomAnchor, constant: 16),
            accessibilityCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            
            accessibilityButton.centerYAnchor.constraint(equalTo: accessibilityCheckbox.centerYAnchor),
            accessibilityButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            preferencesTitle.topAnchor.constraint(equalTo: accessibilityCheckbox.bottomAnchor, constant: 40),
            preferencesTitle.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            
            launchAtLoginCheckbox.topAnchor.constraint(equalTo: preferencesTitle.bottomAnchor, constant: 16),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            
            disconnectOnRemovalCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 12),
            disconnectOnRemovalCheckbox.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 50),
            
            doneButton.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -40),
            doneButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            doneButton.widthAnchor.constraint(equalToConstant: 150)
        ])
    }
    
    private func updateAccessibilityStatus() {
        let hasAccess = AXIsProcessTrusted()
        accessibilityCheckbox.state = hasAccess ? .on : .off
        accessibilityButton.isHidden = hasAccess
        accessibilityButton.title = hasAccess ? "✓ Granted" : "Grant Permission"
    }
    
    @objc private func openAccessibilityPreferences() {
        let prefpaneUrl = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(prefpaneUrl)
    }
    
    @objc private func toggleLaunchAtLogin(_ sender: NSButton) {
        let enabled = sender.state == .on
        Preferences.shared.launchAtLogin = enabled
        
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                logger.log("Failed to update launch at login: \(error.localizedDescription)")
            }
        }
    }
    
    @objc private func toggleDisconnectOnRemoval(_ sender: NSButton) {
        Preferences.shared.shouldDisconnectOnUSBRemoval = sender.state == .on
    }
    
    @objc private func completeOnboarding() {
        windowController?.completeOnboarding()
    }
}

