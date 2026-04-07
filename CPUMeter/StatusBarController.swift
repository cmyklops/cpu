import Cocoa
import SwiftUI

class StatusBarController: NSObject, ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    override init() {
        super.init()
        DispatchQueue.main.async {
            self.setupMenuBar()
        }
    }
    
    private func setupMenuBar() {
        // Create status bar item  
        statusItem = NSStatusBar.system.statusItem(withLength: 160)
        guard let button = statusItem?.button else { return }
        
        button.title = "CPU"
        button.font = NSFont.systemFont(ofSize: 10, weight: .medium)
         button.action = #selector(togglePopover)
        button.target = self
        
        // Create popover
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 160, height: 60)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: ContentView())
    }
    
    @objc private func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if let pop = popover, pop.isShown {
            pop.performClose(button)
        } else if let pop = popover {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
