import Cocoa
import SwiftUI

class StatusBarController: NSObject {
    static let shared = StatusBarController()
    
    private var statusItem: NSStatusItem?
    private var graphView: NSHostingView<ContentView>?
    
    override init() {
        super.init()
        setupMenuBar()
    }
    
    private func setupMenuBar() {
        // Create status bar item with custom view
        statusItem = NSStatusBar.system.statusItem(withLength: 35)
        
        // Create SwiftUI graph view
        let contentView = ContentView()
        graphView = NSHostingView(rootView: contentView)
        
        guard let hostingView = graphView else { return }
        hostingView.frame = NSRect(x: 0, y: 0, width: 35, height: 22)
        
        statusItem?.button?.addSubview(hostingView)
    }
}
