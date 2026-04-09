import Cocoa
import SwiftUI

class StatusBarController: NSObject {
    static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem?
    private var graphView: NSHostingView<ContentView>?
    private var settingsPopover: NSPopover?
    private var preferences: PreferencesManager
    
    override init() {
        self.preferences = PreferencesManager.shared
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        // Create status bar item with minimal length
        statusItem = NSStatusBar.system.statusItem(withLength: 35)
        
        // Create SwiftUI graph view
        let contentView = ContentView()
        graphView = NSHostingView(rootView: contentView)
        
        guard let hostingView = graphView, let button = statusItem?.button else { return }
        
        // Remove all button styling to minimize system padding
        button.title = ""
        button.image = nil
        button.isBordered = false
        button.bezelStyle = .recessed
        button.controlSize = .mini
        
        // Set explicit frame to prevent system from adding padding
        button.frame = NSRect(x: 0, y: 0, width: 35, height: 22)
        button.bounds = NSRect(x: 0, y: 0, width: 35, height: 22)
        
        // Disable automatic sizing
        button.autoresizesSubviews = false
        button.autoresizingMask = []
        
        // Add hosting view with exact dimensions
        hostingView.frame = NSRect(x: 0, y: 0, width: 35, height: 22)
        hostingView.autoresizingMask = []
        hostingView.autoresizesSubviews = false
        
        button.addSubview(hostingView)
        
        button.action = #selector(toggleSettings)
        button.target = self
    }
    
    @objc private func toggleSettings() {
        guard let button = statusItem?.button else { return }
        
        if let popover = settingsPopover, popover.isShown {
            popover.performClose(button)
        } else {
            showSettings(from: button)
        }
    }
    
    private func showSettings(from button: NSStatusBarButton) {
        // Lazy initialize popover (create only once)
        if settingsPopover == nil {
            settingsPopover = NSPopover()
            settingsPopover?.contentSize = NSSize(width: 240, height: 440)
            settingsPopover?.behavior = .transient
            settingsPopover?.contentViewController = NSHostingController(rootView: SettingsView())
        }
        
        if let popover = settingsPopover {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            // Make popover window key so it gets focus and click-outside closes it
            if let window = popover.contentViewController?.view.window {
                window.makeKey()
            }
        }
    }
}
