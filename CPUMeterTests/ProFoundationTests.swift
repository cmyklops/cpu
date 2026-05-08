import XCTest

final class ProFoundationTests: XCTestCase {
    func testFrequencyClamping() {
        XCTAssertEqual(PreferencesManager.clampedFrequency(-1), 0.1)
        XCTAssertEqual(PreferencesManager.clampedFrequency(0.5), 0.5)
        XCTAssertEqual(PreferencesManager.clampedFrequency(4), 2.0)
    }

    func testInvalidStoredPreferencesFallBackToDefaults() {
        let defaults = makeDefaults()
        defaults.set("sideways", forKey: "com.cpumeter.displayMode")
        defaults.set("GPU", forKey: "com.cpumeter.metricType")
        defaults.set(9.0, forKey: "com.cpumeter.updateFrequency")

        let preferences = PreferencesManager(defaults: defaults, launchAtLoginService: MockLaunchAtLoginService(status: .disabled))

        XCTAssertEqual(preferences.displayMode, .bars)
        XCTAssertEqual(preferences.metricType, .cpu)
        XCTAssertEqual(preferences.updateFrequency, 2.0)
    }

    func testHistoryTrimsAndSmooths() {
        var model = MonitorHistoryModel(maxDataPoints: 3, currentMetric: .cpu)

        _ = model.record(cpuUsage: 10, memoryUsage: 20, smoothingFactor: 0.5)
        _ = model.record(cpuUsage: 30, memoryUsage: 40, smoothingFactor: 0.5)
        let snapshot = model.record(cpuUsage: 50, memoryUsage: 60, smoothingFactor: 0.5)
        let trimmed = model.record(cpuUsage: 70, memoryUsage: 80, smoothingFactor: 0.5)

        XCTAssertEqual(snapshot.cpuHistory, [10, 20, 35])
        XCTAssertEqual(trimmed.cpuHistory, [20, 35, 52.5])
        XCTAssertEqual(trimmed.memoryHistory, [30, 45, 62.5])
    }

    func testMetricSwitchRefreshesStatsImmediately() {
        var model = MonitorHistoryModel(maxDataPoints: 12, currentMetric: .cpu)
        _ = model.record(cpuUsage: 10, memoryUsage: 60, smoothingFactor: 1)

        let snapshot = model.setMetric(.memory)

        XCTAssertEqual(snapshot.currentMetric, .memory)
        XCTAssertEqual(snapshot.stats.current, 60)
        XCTAssertEqual(snapshot.stats.average, 60)
        XCTAssertEqual(snapshot.stats.peak, 60)
    }

    func testCPUUsageCalculatorHandlesFirstAndZeroDeltaSamples() {
        var calculator = CPUUsageCalculator()
        let first = CPUTicks(user: 10, system: 10, idle: 80, nice: 0)

        XCTAssertEqual(calculator.usage(from: first), 0)
        XCTAssertEqual(calculator.usage(from: first), 0)

        let next = CPUTicks(user: 20, system: 15, idle: 85, nice: 0)
        XCTAssertEqual(calculator.usage(from: next), 75)
    }

    func testSingleInstanceLockRejectsSecondActiveLockAndAllowsAfterRelease() {
        let lockURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("cpumeter-\(UUID().uuidString).lock")
        let first = SingleInstanceLock(lockURL: lockURL)
        let second = SingleInstanceLock(lockURL: lockURL)

        XCTAssertTrue(first.acquire())
        XCTAssertFalse(second.acquire())

        first.release()
        XCTAssertTrue(second.acquire())
        second.release()
        try? FileManager.default.removeItem(at: lockURL)
    }

    func testLaunchAtLoginStatusMappingThroughPreferences() {
        let defaults = makeDefaults()
        let service = MockLaunchAtLoginService(status: .requiresApproval)
        let preferences = PreferencesManager(defaults: defaults, launchAtLoginService: service)

        XCTAssertEqual(preferences.launchAtLoginStatus, .requiresApproval)
        XCTAssertFalse(preferences.launchAtStartup)

        service.currentStatus = .enabled
        preferences.refreshLaunchAtLoginStatus()
        XCTAssertEqual(preferences.launchAtLoginStatus, .enabled)
        XCTAssertTrue(preferences.launchAtStartup)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "com.cpumeter.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private final class MockLaunchAtLoginService: LaunchAtLoginServicing {
    var currentStatus: LaunchAtLoginStatus

    init(status: LaunchAtLoginStatus) {
        self.currentStatus = status
    }

    func status() -> LaunchAtLoginStatus {
        currentStatus
    }

    func setEnabled(_ enabled: Bool) throws {
        currentStatus = enabled ? .enabled : .disabled
    }
}
