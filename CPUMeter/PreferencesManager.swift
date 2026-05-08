import Foundation
import OSLog

final class PreferencesManager: ObservableObject {
    static let shared = PreferencesManager()

    @Published private(set) var updateFrequency: Double
    @Published private(set) var launchAtStartup: Bool
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus
    @Published private(set) var displayMode: DisplayMode
    @Published private(set) var metricType: MetricType

    private let defaults: UserDefaults
    private let launchAtLoginService: LaunchAtLoginServicing
    private let updateFrequencyKey = "com.cpumeter.updateFrequency"
    private let launchAtStartupKey = "com.cpumeter.launchAtStartup"
    private let displayModeKey = "com.cpumeter.displayMode"
    private let metricTypeKey = "com.cpumeter.metricType"

    private var debounceTimers: [String: Timer] = [:]
    private let debounceInterval: TimeInterval = 0.5

    init(
        defaults: UserDefaults = .standard,
        launchAtLoginService: LaunchAtLoginServicing = LaunchAtLoginService()
    ) {
        self.defaults = defaults
        self.launchAtLoginService = launchAtLoginService

        let frequency = defaults.double(forKey: updateFrequencyKey)
        self.updateFrequency = Self.clampedFrequency(frequency > 0 ? frequency : 1)
        self.displayMode = DisplayMode(rawValue: defaults.string(forKey: displayModeKey) ?? "") ?? .bars
        self.metricType = MetricType(rawValue: defaults.string(forKey: metricTypeKey) ?? "") ?? .cpu

        let serviceStatus = launchAtLoginService.status()
        self.launchAtLoginStatus = serviceStatus
        self.launchAtStartup = serviceStatus.isEnabled || defaults.bool(forKey: launchAtStartupKey)
    }

    deinit {
        debounceTimers.values.forEach { $0.invalidate() }
    }

    static func clampedFrequency(_ frequency: Double) -> Double {
        max(0.1, min(2.0, frequency))
    }

    func setUpdateFrequency(_ frequency: Double) {
        let validatedFrequency = Self.clampedFrequency(frequency)
        updateFrequency = validatedFrequency
        scheduleDebouncedWrite(key: updateFrequencyKey) { [defaults, updateFrequencyKey] in
            defaults.set(validatedFrequency, forKey: updateFrequencyKey)
        }
        NotificationCenter.default.post(name: .updateFrequencyChanged, object: validatedFrequency)
    }

    func setLaunchAtStartup(_ enabled: Bool) {
        launchAtStartup = enabled
        do {
            try launchAtLoginService.setEnabled(enabled)
            launchAtLoginStatus = launchAtLoginService.status()
            scheduleDebouncedWrite(key: launchAtStartupKey) { [defaults, launchAtStartupKey] in
                defaults.set(enabled, forKey: launchAtStartupKey)
            }
        } catch {
            Logger.preferences.error("Launch-at-login update failed: \(error.localizedDescription, privacy: .public)")
            launchAtLoginStatus = .failed(error.localizedDescription)
            launchAtStartup = launchAtLoginStatus.isEnabled
        }
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLoginService.status()
        launchAtStartup = launchAtLoginStatus.isEnabled
    }

    func setDisplayMode(_ mode: DisplayMode) {
        displayMode = mode
        scheduleDebouncedWrite(key: displayModeKey) { [defaults, displayModeKey] in
            defaults.set(mode.rawValue, forKey: displayModeKey)
        }
    }

    func setMetricType(_ metric: MetricType) {
        metricType = metric
        scheduleDebouncedWrite(key: metricTypeKey) { [defaults, metricTypeKey] in
            defaults.set(metric.rawValue, forKey: metricTypeKey)
        }
        #if !CPUMETER_TESTING
        CPUMonitor.shared.setMetric(metric)
        #endif
    }

    func resetToDefaults() {
        updateFrequency = 1
        displayMode = .bars
        metricType = .cpu
        setLaunchAtStartup(false)

        defaults.set(1.0, forKey: updateFrequencyKey)
        defaults.set(DisplayMode.bars.rawValue, forKey: displayModeKey)
        defaults.set(MetricType.cpu.rawValue, forKey: metricTypeKey)
        defaults.set(false, forKey: launchAtStartupKey)

        NotificationCenter.default.post(name: .updateFrequencyChanged, object: 1.0)
        #if !CPUMETER_TESTING
        CPUMonitor.shared.setMetric(.cpu)
        #endif
    }

    private func scheduleDebouncedWrite(key: String, block: @escaping () -> Void) {
        debounceTimers[key]?.invalidate()
        let timer = Timer.scheduledTimer(withTimeInterval: debounceInterval, repeats: false) { [weak self] _ in
            block()
            self?.debounceTimers[key] = nil
        }
        debounceTimers[key] = timer
    }
}

extension Notification.Name {
    static let updateFrequencyChanged = Notification.Name("UpdateFrequencyChanged")
}
