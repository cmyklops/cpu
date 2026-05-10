import Darwin
import Combine
import Foundation
import OSLog

typealias mach_port_t = UInt32
typealias kern_return_t = Int32
typealias mach_msg_type_number_t = UInt32

private struct HostCpuLoadInfo {
    var cpu_ticks: (UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0)
}

@_silgen_name("mach_host_self")
private func machHostSelf() -> mach_port_t

@_silgen_name("host_statistics")
private func hostStatistics(
    host: mach_port_t,
    flavor: Int32,
    host_info: UnsafeMutableRawPointer,
    host_info_count: UnsafeMutablePointer<mach_msg_type_number_t>
) -> kern_return_t

private let HOST_CPU_LOAD_INFO = 3

final class CPUMonitor: NSObject, ObservableObject {
    static let shared = CPUMonitor()

    let objectWillChange = ObservableObjectPublisher()

    private(set) var cpuHistory: [Double] = []
    private(set) var memoryHistory: [Double] = []
    private(set) var highlightedBarPositions: Set<Int> = []
    private(set) var currentMetric: MetricType = .cpu
    private(set) var currentValue: Double = 0
    private(set) var averageValue: Double = 0
    private(set) var peakValue: Double = 0
    private(set) var memoryPressureLevel: Int = 0
    private(set) var isDataFresh: Bool = true
    private(set) var sampleStatus: SampleStatus = .waiting
    private(set) var lastSampleDate: Date?

    private let sampleQueue = DispatchQueue(label: "com.cpumeter.sampling", qos: .userInitiated)
    private let maxDataPoints = 12
    private var timer: DispatchSourceTimer?
    private var updateInterval: Double
    private var model: MonitorHistoryModel
    private var cpuCalculator = CPUUsageCalculator()
    private var lastFrequencyChangeTime = Date.distantPast
    private var errorCount = 0
    private let maxErrorThreshold = 10
    private let staleDataThreshold: TimeInterval = 5
    private var lastSuccessfulUpdate = Date()
    private var memoryPressureSource: DispatchSourceMemoryPressure?
    private var cachedMemoryUsage: Double = 0
    private var lastMemorySampleDate = Date.distantPast
    private let memorySampleInterval: TimeInterval = 1

    private var smoothingFactor: Double {
        switch updateInterval {
        case ...0.2: return 0.75
        case 0.2..<0.5: return 0.7
        case 0.5..<1.0: return 0.65
        case 1.0..<2.0: return 0.6
        default: return 0.55
        }
    }

    override init() {
        let metric = PreferencesManager.shared.metricType
        self.updateInterval = PreferencesManager.shared.updateFrequency
        self.model = MonitorHistoryModel(maxDataPoints: maxDataPoints, currentMetric: metric)
        self.currentMetric = metric
        super.init()

        startMemoryPressureSource()
        startMonitoring()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFrequencyChanged(_:)),
            name: .updateFrequencyChanged,
            object: nil
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        sampleQueue.sync {
            stopMonitoringLocked()
        }
        memoryPressureSource?.cancel()
        memoryPressureSource = nil
    }

    func setMetric(_ metric: MetricType) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.currentMetric = metric
        }
        sampleQueue.async {
            let snapshot = self.model.setMetric(metric)
            self.publish(snapshot: snapshot, status: self.sampleStatusForFreshness())
        }
    }

    @objc private func updateFrequencyChanged(_ notification: Notification) {
        guard let frequency = notification.object as? Double else {
            return
        }

        sampleQueue.async {
            self.updateInterval = PreferencesManager.clampedFrequency(frequency)
            self.restartMonitoringLocked()

            DispatchQueue.main.async {
                let timeSinceLastChange = Date().timeIntervalSince(self.lastFrequencyChangeTime)
                if timeSinceLastChange >= 0.5 {
                    self.objectWillChange.send()
                    self.highlightedBarPositions.insert(0)
                    self.lastFrequencyChangeTime = Date()
                }
            }
        }
    }

    private func startMonitoring() {
        sampleQueue.async {
            self.startMonitoringLocked()
        }
    }

    private func startMonitoringLocked() {
        let timer = DispatchSource.makeTimerSource(queue: sampleQueue)
        let interval = DispatchTimeInterval.nanoseconds(Int(updateInterval * 1_000_000_000))
        timer.schedule(deadline: .now(), repeating: interval, leeway: timerLeeway(for: updateInterval))
        timer.setEventHandler { [weak self] in
            self?.updateSampleLocked()
        }
        timer.resume()
        self.timer = timer
    }

    private func stopMonitoringLocked() {
        timer?.cancel()
        timer = nil
    }

    private func restartMonitoringLocked() {
        stopMonitoringLocked()
        startMonitoringLocked()
    }

    private func updateSampleLocked() {
        let cpuUsage = getCPUUsageLocked()
        let memoryUsage = getMemoryPressureLocked()

        guard cpuUsage >= 0 && memoryUsage >= 0 else {
            errorCount += 1
            if errorCount > maxErrorThreshold {
                Logger.sampling.warning("Consecutive measurement failures: \(self.errorCount)")
            }
            publishFreshnessOnly(status: sampleStatusForFreshness(failure: "Measurement failed"))
            return
        }

        errorCount = 0
        lastSuccessfulUpdate = Date()

        let snapshot = model.record(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            smoothingFactor: smoothingFactor
        )
        publish(snapshot: snapshot, status: .fresh)
    }

    private func publish(snapshot: MonitorSnapshot, status: SampleStatus) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.cpuHistory = snapshot.cpuHistory
            self.memoryHistory = snapshot.memoryHistory
            self.currentMetric = snapshot.currentMetric
            self.currentValue = snapshot.stats.current
            self.averageValue = snapshot.stats.average
            self.peakValue = snapshot.stats.peak
            self.sampleStatus = status
            self.isDataFresh = status != .stale
            self.lastSampleDate = self.lastSuccessfulUpdate

            var updatedPositions = Set<Int>()
            for position in self.highlightedBarPositions {
                let newPosition = position + 1
                if newPosition < self.maxDataPoints {
                    updatedPositions.insert(newPosition)
                }
            }
            self.highlightedBarPositions = updatedPositions
        }
    }

    private func publishFreshnessOnly(status: SampleStatus) {
        DispatchQueue.main.async {
            self.objectWillChange.send()
            self.sampleStatus = status
            self.isDataFresh = status != .stale && {
                if case .failed = status { return false }
                return true
            }()
        }
    }

    private func sampleStatusForFreshness(failure: String? = nil) -> SampleStatus {
        if let failure {
            return .failed(failure)
        }
        return Date().timeIntervalSince(lastSuccessfulUpdate) < staleDataThreshold ? .fresh : .stale
    }

    private func startMemoryPressureSource() {
        let source = DispatchSource.makeMemoryPressureSource(
            eventMask: [.normal, .warning, .critical],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            guard let self else { return }
            let event = source.data
            self.objectWillChange.send()
            if event.contains(.critical) {
                self.memoryPressureLevel = 2
            } else if event.contains(.warning) {
                self.memoryPressureLevel = 1
            } else {
                self.memoryPressureLevel = 0
            }
        }
        source.resume()
        memoryPressureSource = source
    }

    private func timerLeeway(for interval: Double) -> DispatchTimeInterval {
        let leeway = min(max(interval * 0.1, 0.02), 0.15)
        return .nanoseconds(Int(leeway * 1_000_000_000))
    }

    private func getMemoryPressureLocked() -> Double {
        let now = Date()
        guard model.currentMetric == .memory || now.timeIntervalSince(lastMemorySampleDate) >= memorySampleInterval else {
            return cachedMemoryUsage
        }

        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let ret = sysctlbyname("kern.memorystatus_level", &level, &size, nil, 0)
        guard ret == 0 else {
            Logger.sampling.error("Memory pressure query failed: \(String(cString: strerror(errno)), privacy: .public)")
            return -1
        }
        cachedMemoryUsage = Double(max(0, 100 - level))
        lastMemorySampleDate = now
        return cachedMemoryUsage
    }

    private func getCPUUsageLocked() -> Double {
        let host = machHostSelf()
        defer {
            mach_port_deallocate(mach_task_self_, host)
        }

        var cpuLoadInfo = HostCpuLoadInfo()
        var count = mach_msg_type_number_t(4)

        let result = withUnsafeMutablePointer(to: &cpuLoadInfo.cpu_ticks) { ptr -> kern_return_t in
            hostStatistics(
                host: host,
                flavor: Int32(HOST_CPU_LOAD_INFO),
                host_info: UnsafeMutableRawPointer(ptr),
                host_info_count: &count
            )
        }

        guard result == 0 else {
            Logger.sampling.error("CPU query failed with code: \(result)")
            return -1
        }

        let ticks = CPUTicks(
            user: UInt64(cpuLoadInfo.cpu_ticks.0),
            system: UInt64(cpuLoadInfo.cpu_ticks.1),
            idle: UInt64(cpuLoadInfo.cpu_ticks.2),
            nice: UInt64(cpuLoadInfo.cpu_ticks.3)
        )
        return cpuCalculator.usage(from: ticks)
    }
}
