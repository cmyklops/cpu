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
private struct vm_statistics64 {
    var free_count: Int32 = 0
    var active_count: Int32 = 0
    var inactive_count: Int32 = 0
    var wire_count: Int32 = 0
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
    
    private var timer: Timer?
    private let maxDataPoints = 12
    private var updateInterval: Double = 1.0
    private var lastFrequencyChangeTime: Date = Date.distantPast
    private var lastCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)? = nil
    private let smoothingFactor: Double = 0.6  // EMA smoothing (0.6 = 60% current, 40% history)
    
    override init() {
        super.init()
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
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateCPU()
        }
        // Trigger first update immediately
        updateCPU()
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func restartMonitoring() {
        stopMonitoring()
        startMonitoring()
    }
    
    private func updateCPU() {
        let cpuUsage = getCPUUsage()
        let memoryUsage = getMemoryUsage()
        
        DispatchQueue.main.async {
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
            
            // Update current value based on metric
            self.currentValue = self.currentMetric == "CPU" ? smoothedCPU : smoothedMemory
            
            // Calculate average and peak
            let activeHistory = self.currentMetric == "CPU" ? self.cpuHistory : self.memoryHistory
            if !activeHistory.isEmpty {
                self.averageValue = activeHistory.reduce(0, +) / Double(activeHistory.count)
                self.peakValue = activeHistory.max() ?? 0
            }
            
            // Increment positions of highlighted bars
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
    
    private func getMemoryUsage() -> Double {
        // Get system-wide memory statistics
        var stats = vm_statistics64_data_t()
        // Count should be number of Int32 values in the struct
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<Int32>.size)
        
        let hostPort = machHostSelf()
        
        let result = withUnsafeMutablePointer(to: &stats) { ptr -> kern_return_t in
            return hostStatistics(
                host: hostPort,
                flavor: 4,  // HOST_VM_INFO64
                host_info: UnsafeMutableRawPointer(ptr),
                host_info_count: &count
            )
        }
        
        guard result == 0 else {
            return 0.0
        }
        
        // Get page size
        let pageSize = UInt64(getpagesize())
        
        // Calculate used memory: active + inactive + wired
        let usedPages = UInt64(stats.active_count) + UInt64(stats.inactive_count) + UInt64(stats.wire_count)
        let usedMemory = usedPages * pageSize
        
        // Total physical memory
        let totalMemory = UInt64(ProcessInfo.processInfo.physicalMemory)
        
        // Calculate percentage
        let memoryPercentage = (Double(usedMemory) / Double(totalMemory)) * 100.0
        
        return min(max(memoryPercentage, 0.0), 100.0)
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
            return 0.0
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
