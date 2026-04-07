import SwiftUI

@main
struct CPUMeterApp: App {
    init() {
        // Initialize in background to avoid blocking UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.setActivationPolicy(.accessory)
            _ = StatusBarController.shared
        }
    }
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
