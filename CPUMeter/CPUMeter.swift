import OSLog
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationWillTerminate(_ notification: Notification) {
        SingleInstanceManager.cleanup()
    }
}

@main
struct CPUMeterApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        if !SingleInstanceManager.ensureSingleInstance() {
            Logger.startup.info("Another CPUMeter instance is already running.")
            NSApplication.shared.terminate(nil)
        }

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
