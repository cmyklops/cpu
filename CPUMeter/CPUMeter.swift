import SwiftUI

@main
struct CPUMeterApp: App {
    init() {
        // Check for single instance
        if !SingleInstanceManager.ensureSingleInstance() {
            NSApplication.shared.terminate(nil)
        }
        
        // Initialize in background to avoid blocking UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            _ = StatusBarController.shared
            _ = CPUMonitor.shared
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

