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
        // Create status bar item with custom view
        statusItem = NSStatusBar.system.statusItem(withLength: 35)
        
        // Create SwiftUI graph view
        let contentView = ContentView()
        graphView = NSHostingView(rootView: contentView)
        
        guard let hostingView = graphView, let button = statusItem?.button else { return }
        hostingView.frame = NSRect(x: 0, y: 0, width: 35, height: 22)
        
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
        // Create settings popover
        settingsPopover = NSPopover()
        settingsPopover?.contentSize = NSSize(width: 264, height: 180)
        settingsPopover?.behavior = .transient
        settingsPopover?.contentViewController = NSHostingController(rootView: SettingsView())
        
        settingsPopover?.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }
}
