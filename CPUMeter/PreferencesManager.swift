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
    
    // Debounce timer for throttled writes
    private var debounceTimers: [String: Timer] = [:]
    private let debounceInterval: TimeInterval = 0.5
    
    init() {
        // Batch load all settings with fallback to defaults
        let frequency = defaults.double(forKey: updateFrequencyKey)
        self.updateFrequency = frequency > 0 ? frequency : 1.0
        self.launchAtStartup = defaults.bool(forKey: launchAtStartupKey)
        self.displayMode = defaults.string(forKey: displayModeKey) ?? "bars"
        self.metricType = defaults.string(forKey: metricTypeKey) ?? "CPU"
    }
    
    private func scheduleDebouncedWrite(key: String, block: @escaping () -> Void) {
        // Cancel existing timer for this key
        debounceTimers[key]?.invalidate()
        
        // Schedule new write after debounce interval
        let timer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            block()
            self?.debounceTimers[key] = nil
        }
        debounceTimers[key] = timer
    }
    
    func setUpdateFrequency(_ frequency: Double) {
        let validatedFrequency = max(0.1, min(2.0, frequency))  // Clamp to 0.1-2.0s
        self.updateFrequency = validatedFrequency
        scheduleDebouncedWrite(key: updateFrequencyKey) { [weak self, updateFrequencyKey] in
            self?.defaults.set(validatedFrequency, forKey: updateFrequencyKey)
        }
        NotificationCenter.default.post(name: NSNotification.Name("UpdateFrequencyChanged"), object: validatedFrequency)
    }
    
    func setLaunchAtStartup(_ enabled: Bool) {
        self.launchAtStartup = enabled
        scheduleDebouncedWrite(key: launchAtStartupKey) { [weak self, launchAtStartupKey] in
            self?.defaults.set(enabled, forKey: launchAtStartupKey)
        }
        
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
        scheduleDebouncedWrite(key: displayModeKey) { [weak self, displayModeKey] in
            self?.defaults.set(mode, forKey: displayModeKey)
        }
    }
    
    func setMetricType(_ metric: String) {
        self.metricType = metric
        scheduleDebouncedWrite(key: metricTypeKey) { [weak self, metricTypeKey] in
            self?.defaults.set(metric, forKey: metricTypeKey)
        }
        CPUMonitor.shared.currentMetric = metric
    }
    
    func resetToDefaults() {
        self.updateFrequency = 1.0
        self.displayMode = "bars"
        self.metricType = "CPU"
        self.launchAtStartup = false
        
        defaults.set(1.0, forKey: updateFrequencyKey)
        defaults.set("bars", forKey: displayModeKey)
        defaults.set("CPU", forKey: metricTypeKey)
        defaults.set(false, forKey: launchAtStartupKey)
        
        disableLaunchAtStartup()
        NotificationCenter.default.post(name: NSNotification.Name("UpdateFrequencyChanged"), object: 1.0)
    }
}
