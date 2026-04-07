import SwiftUI

@main
struct CPUMeterApp: App {
    @StateObject private var statusBarController = StatusBarController()
    
    init() {
        // Prevent dock icon from appearing
        NSApp.setActivationPolicy(.accessory)
        // Trigger CPUMonitor singleton initialization
        _ = CPUMonitor.shared
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
