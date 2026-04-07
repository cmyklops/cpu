import Foundation

class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()
    
    @Published var updateFrequency: Double = 1.0
    @Published var launchAtStartup: Bool = false
    @Published var displayMode: String = "bars"  // "bars", "number", "gradient"
    @Published var metricType: String = "CPU"    // "CPU" or "Memory"
    
    private let defaults = UserDefaults.standard
    private let updateFrequencyKey = "com.cpumeter.updateFrequency"
    private let launchAtStartupKey = "com.cpumeter.launchAtStartup"
    private let displayModeKey = "com.cpumeter.displayMode"
    private let metricTypeKey = "com.cpumeter.metricType"
    
    init() {
        self.updateFrequency = defaults.double(forKey: updateFrequencyKey) > 0 ? 
            defaults.double(forKey: updateFrequencyKey) : 1.0
        self.launchAtStartup = defaults.bool(forKey: launchAtStartupKey)
        self.displayMode = defaults.string(forKey: displayModeKey) ?? "bars"
        self.metricType = defaults.string(forKey: metricTypeKey) ?? "CPU"
    }
    
    func setUpdateFrequency(_ frequency: Double) {
        self.updateFrequency = frequency
        defaults.set(frequency, forKey: updateFrequencyKey)
        NotificationCenter.default.post(name: NSNotification.Name("UpdateFrequencyChanged"), object: frequency)
    }
    
    func setLaunchAtStartup(_ enabled: Bool) {
        self.launchAtStartup = enabled
        defaults.set(enabled, forKey: launchAtStartupKey)
        
        if enabled {
            enableLaunchAtStartup()
        } else {
            disableLaunchAtStartup()
        }
    }
    
    private func enableLaunchAtStartup() {
        let appPath = Bundle.main.bundlePath
        let loginItemsHelper = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.cpumeter.plist")
        
        let plistData: [String: Any] = [
            "Label": "com.cpumeter.launcher",
            "ProgramArguments": [appPath + "/Contents/MacOS/CPUMeter"],
            "RunAtLoad": true
        ]
        
        do {
            let plistContent = try PropertyListSerialization.data(
                fromPropertyList: plistData,
                format: .xml,
                options: 0
            )
            try plistContent.write(to: loginItemsHelper)
        } catch {
            print("Error enabling launch at startup: \(error)")
        }
    }
    
    private func disableLaunchAtStartup() {
        let loginItemsHelper = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.cpumeter.plist")
        
        try? FileManager.default.removeItem(at: loginItemsHelper)
    }
    
    func setDisplayMode(_ mode: String) {
        self.displayMode = mode
        defaults.set(mode, forKey: displayModeKey)
    }
    
    func setMetricType(_ metric: String) {
        self.metricType = metric
        defaults.set(metric, forKey: metricTypeKey)
        CPUMonitor.shared.currentMetric = metric
    }
}
