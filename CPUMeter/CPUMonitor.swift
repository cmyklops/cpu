import Foundation
import Darwin

// Mach kernel types and functions
typealias mach_port_t = UInt32
typealias kern_return_t = Int32
typealias mach_msg_type_number_t = UInt32
typealias natural_t = UInt

private struct HostCpuLoadInfo {
    var cpu_ticks: (UInt32, UInt32, UInt32, UInt32) = (0, 0, 0, 0)
}

private struct task_vm_info {
    var resident_size: UInt64 = 0
    var virtual_size: UInt64 = 0
}

private typealias task_vm_info_data_t = task_vm_info

// VM statistics for system memory
// Real struct from macOS mach/vm_statistics.h (160 bytes total)
private struct vm_statistics64 {
    // First 4 natural_t (UInt32) fields
    var free_count: UInt32 = 0
    var active_count: UInt32 = 0
    var inactive_count: UInt32 = 0
    var wire_count: UInt32 = 0
    
    // 13 uint64_t fields
    var zero_fill_count: UInt64 = 0
    var reactivations: UInt64 = 0
    var pageins: UInt64 = 0
    var pageouts: UInt64 = 0
    var faults: UInt64 = 0
    var cow_faults: UInt64 = 0
    var lookups: UInt64 = 0
    var hits: UInt64 = 0
    var purges: UInt64 = 0
    
    // natural_t fields
    var purgeable_count: UInt32 = 0
    var speculative_count: UInt32 = 0
    
    // More uint64_t fields (rev1)
    var decompressions: UInt64 = 0
    var compressions: UInt64 = 0
    var swapins: UInt64 = 0
    var swapouts: UInt64 = 0
    
    // More natural_t fields
    var compressor_page_count: UInt32 = 0
    var throttled_count: UInt32 = 0
    var external_page_count: UInt32 = 0
    var internal_page_count: UInt32 = 0
    
    // Last uint64_t field (rev2)
    var total_uncompressed_pages_in_compressor: UInt64 = 0
    var swapped_count: UInt64 = 0
}

private typealias vm_statistics64_data_t = vm_statistics64

@_silgen_name("mach_task_self_")
private func machTaskSelf() -> mach_port_t

private let mach_task_self_ = machTaskSelf()
private let TASK_VM_INFO: natural_t = 22

@_silgen_name("task_info")
private func taskInfo(
    target_task: mach_port_t,
    flavor: natural_t,
    task_info: UnsafeMutablePointer<Int32>,
    task_info_count: UnsafeMutablePointer<mach_msg_type_number_t>
) -> kern_return_t

@_silgen_name("mach_host_self")
private func machHostSelf() -> mach_port_t

@_silgen_name("host_statistics")
private func hostStatistics(
    host: mach_port_t,
    flavor: Int32,
    host_info: UnsafeMutableRawPointer,
    host_info_count: UnsafeMutablePointer<mach_msg_type_number_t>
) -> kern_return_t

@_silgen_name("host_statistics64")
private func hostStatistics64(
    host: mach_port_t,
    flavor: Int32,
    host_info: UnsafeMutableRawPointer,
    host_info_count: UnsafeMutablePointer<mach_msg_type_number_t>
) -> kern_return_t

private let HOST_CPU_LOAD_INFO = 3

class CPUMonitor: NSObject, ObservableObject {
    static let shared = CPUMonitor()
    
    @Published var cpuHistory: [Double] = []
    @Published var memoryHistory: [Double] = []
    @Published var highlightedBarPositions: Set<Int> = []
    @Published var currentMetric: String = "CPU"  // "CPU" or "Memory"
    @Published var currentValue: Double = 0.0
    @Published var averageValue: Double = 0.0
    @Published var peakValue: Double = 0.0
    @Published var showStats: Bool = false
    @Published var memoryPressureLevel: Int = 0  // 0=green, 1=yellow, 2=red
    
    private var timer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.cpumeter.timer", qos: .userInitiated)
    private let maxDataPoints = 12
    private var updateInterval: Double = 1.0
    private var lastFrequencyChangeTime: Date = Date.distantPast
    private var lastCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)? = nil
    
    // Pressure delta tracking
    private var lastSwapouts: UInt64 = 0
    private var lastCompressions: UInt64 = 0
    private var isFirstMemorySample: Bool = true
    private var lastSwapDelta: UInt64 = 0
    private var lastCompressionDelta: UInt64 = 0
    
    // Pre-calculated page size
    private let pageSize: UInt64 = UInt64(getpagesize())
    
    // Stale data detection
    private var lastSuccessfulUpdate: Date = Date()
    @Published var isDataFresh: Bool = true
    private let staleDataThreshold: TimeInterval = 5.0  // Consider data stale after 5 seconds
    
    private var errorCount: Int = 0
    private let maxErrorThreshold: Int = 10
    
    // Dynamic EMA factor based on update frequency (slower = lower factor)
    private var smoothingFactor: Double {
        switch updateInterval {
        case ...0.2: return 0.75  // Fast updates, more aggressive smoothing
        case 0.2..<0.5: return 0.7
        case 0.5..<1.0: return 0.65
        case 1.0..<2.0: return 0.6
        default: return 0.55  // Slow updates, less aggressive smoothing
        }
    }
    
    override init() {
        super.init()
        // Sync metric from saved preferences
        self.currentMetric = PreferencesManager.shared.metricType
        startMonitoring()
        
        // Listen for update frequency changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateFrequencyChanged(_:)),
            name: NSNotification.Name("UpdateFrequencyChanged"),
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        stopMonitoring()
    }
    
    @objc private func updateFrequencyChanged(_ notification: Notification) {
        if let frequency = notification.object as? Double {
            self.updateInterval = frequency
            DispatchQueue.main.async {
                // Only highlight a bar if enough time has passed since the last frequency change
                // This prevents rapid slider adjustments from highlighting multiple bars
                let timeSinceLastChange = Date().timeIntervalSince(self.lastFrequencyChangeTime)
                if timeSinceLastChange >= 0.5 {  // At least 500ms between highlights
                    // Mark the current bar (rightmost) for highlighting
                    self.highlightedBarPositions.insert(0)
                    self.lastFrequencyChangeTime = Date()
                }
            }
            restartMonitoring()
        }
    }
    
    private func startMonitoring() {
        let queue = timerQueue
        let timer = DispatchSource.makeTimerSource(queue: queue)
        let intervalInSeconds = UInt64(updateInterval * 1_000_000_000)  // Convert to nanoseconds
        
        timer.schedule(deadline: .now(), repeating: .nanoseconds(Int(intervalInSeconds)))
        timer.setEventHandler { [weak self] in
            self?.updateCPU()
        }
        
        timer.resume()
        self.timer = timer
        // Trigger first update immediately
        updateCPU()
    }
    
    private func stopMonitoring() {
        timer?.cancel()
        timer = nil
    }
    
    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }
    
    private func debugLog(_ message: String) {
        #if DEBUG
        NSLog("[CPUMeter] \(message)")
        #endif
    }
    
    private func updateCPU() {
        let cpuUsage = getCPUUsage()
        let memoryUsage = getMemoryPressure()
        
        // Skip update if measurements failed (negative = error)
        guard cpuUsage >= 0 && memoryUsage >= 0 else {
            errorCount += 1
            if errorCount > maxErrorThreshold {
                debugLog("Warning: \(errorCount) consecutive measurement failures")
            }
            DispatchQueue.main.async {
                let timeSinceLastUpdate = Date().timeIntervalSince(self.lastSuccessfulUpdate)
                self.isDataFresh = timeSinceLastUpdate < self.staleDataThreshold
            }
            return
        }
        
        errorCount = 0
        
        DispatchQueue.main.async {
            self.lastSuccessfulUpdate = Date()
            // Check if data is stale
            let timeSinceLastUpdate = Date().timeIntervalSince(self.lastSuccessfulUpdate)
            self.isDataFresh = timeSinceLastUpdate < self.staleDataThreshold
            
            // Apply exponential moving average smoothing to CPU
            let smoothedCPU: Double
            if self.cpuHistory.isEmpty {
                smoothedCPU = cpuUsage
            } else {
                let lastValue = self.cpuHistory.last ?? 0
                smoothedCPU = (cpuUsage * self.smoothingFactor) + (lastValue * (1.0 - self.smoothingFactor))
            }
            
            // Apply smoothing to memory
            let smoothedMemory: Double
            if self.memoryHistory.isEmpty {
                smoothedMemory = memoryUsage
            } else {
                let lastValue = self.memoryHistory.last ?? 0
                smoothedMemory = (memoryUsage * self.smoothingFactor) + (lastValue * (1.0 - self.smoothingFactor))
            }
            
            self.cpuHistory.append(smoothedCPU)
            self.memoryHistory.append(smoothedMemory)
            
            if self.cpuHistory.count > self.maxDataPoints {
                self.cpuHistory.removeFirst()
                self.memoryHistory.removeFirst()
            }
            
            // Always update current value display with latest reading
            if self.currentMetric == "CPU" {
                self.currentValue = smoothedCPU
            } else {
                self.currentValue = smoothedMemory
            }
            
            // Calculate average and peak (lightweight)
            let activeHistory = self.currentMetric == "CPU" ? self.cpuHistory : self.memoryHistory
            if !activeHistory.isEmpty {
                self.averageValue = activeHistory.reduce(0, +) / Double(activeHistory.count)
                self.peakValue = activeHistory.max() ?? 0
            }
            
            // Update memory pressure level from latest deltas
            let swapD = self.lastSwapDelta
            let compD = self.lastCompressionDelta
            if swapD >= 100 {
                self.memoryPressureLevel = 2  // red
            } else if compD >= 1000 || swapD > 0 {
                self.memoryPressureLevel = 1  // yellow
            } else {
                self.memoryPressureLevel = 0  // green
            }
            
            // Always increment positions of highlighted bars
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
    
    private func getMemoryPressure() -> Double {
        // Get system-wide memory statistics
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<Int32>.size)
        
        let hostPort = machHostSelf()
        
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            return hostStatistics64(
                host: hostPort,
                flavor: 4,  // HOST_VM_INFO64
                host_info: UnsafeMutableRawPointer(ptr),
                host_info_count: &count
            )
        }
        
        guard result == 0 else {
            debugLog("Memory query failed with error code: \(result)")
            return -1.0  // Return negative to signal error
        }
        
        // Calculate app memory only (internal - purgeable), excludes wired/compressed OS overhead
        let appPages = UInt64(stats.internal_page_count) - UInt64(stats.purgeable_count)
        let appMemory = appPages * pageSize
        
        // Total physical memory
        let totalMemory = UInt64(ProcessInfo.processInfo.physicalMemory)
        
        // Calculate percentage
        let memoryPercentage = totalMemory > 0 ? (Double(appMemory) / Double(totalMemory)) * 100.0 : 0.0
        let roundedPercentage = min(max(memoryPercentage, 0.0), 100.0)
        
        // Compute swap/compression deltas for pressure level (skip first sample)
        lastSwapDelta = isFirstMemorySample ? 0 : (stats.swapouts >= lastSwapouts ? stats.swapouts - lastSwapouts : 0)
        lastCompressionDelta = isFirstMemorySample ? 0 : (stats.compressions >= lastCompressions ? stats.compressions - lastCompressions : 0)
        lastSwapouts = stats.swapouts
        lastCompressions = stats.compressions
        isFirstMemorySample = false
        
        return roundedPercentage
    }
    
    private func getCPUUsage() -> Double {
        let host = machHostSelf()
        
        // Allocate space for CPU load info (4 UInt32 values)
        var cpuLoadInfo = HostCpuLoadInfo()
        var count = mach_msg_type_number_t(4)  // 4 values: user, system, idle, nice
        
        let result = withUnsafeMutablePointer(to: &cpuLoadInfo.cpu_ticks) { ptr -> kern_return_t in
            hostStatistics(
                host: host,
                flavor: Int32(HOST_CPU_LOAD_INFO),
                host_info: UnsafeMutableRawPointer(ptr),
                host_info_count: &count
            )
        }
        
        guard result == 0 else {  // KERN_SUCCESS = 0
            debugLog("CPU query failed with error code: \(result)")
            return -1.0  // Return negative to signal error
        }
        
        let user = UInt64(cpuLoadInfo.cpu_ticks.0)
        let system = UInt64(cpuLoadInfo.cpu_ticks.1)
        let idle = UInt64(cpuLoadInfo.cpu_ticks.2)
        let nice = UInt64(cpuLoadInfo.cpu_ticks.3)
        
        // If first reading, store and return 0
        if lastCPUTicks == nil {
            lastCPUTicks = (user: user, system: system, idle: idle, nice: nice)
            return 0.0
        }
        
        // Calculate deltas
        let prevUser = lastCPUTicks!.user
        let prevSystem = lastCPUTicks!.system
        let prevIdle = lastCPUTicks!.idle
        let prevNice = lastCPUTicks!.nice
        
        let userDiff = user - prevUser
        let systemDiff = system - prevSystem
        let idleDiff = idle - prevIdle
        let niceDiff = nice - prevNice
        
        // Store current for next calculation
        lastCPUTicks = (user: user, system: system, idle: idle, nice: nice)
        
        // Calculate total and used
        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff
        let usedDiff = userDiff + systemDiff + niceDiff
        
        guard totalDiff > 0 else {
            return 0.0
        }
        
        let cpuUsage = Double(usedDiff) / Double(totalDiff) * 100.0
        return min(max(cpuUsage, 0.0), 100.0)
    }
}
