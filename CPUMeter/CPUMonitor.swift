import Foundation

// Import getloadavg from libc
@_silgen_name("getloadavg")
private func getLoadAverage(_ loadavg: UnsafeMutablePointer<Double>, _ nelem: Int32) -> Int32

class CPUMonitor: NSObject, ObservableObject {
    static let shared = CPUMonitor()
    
    @Published var cpuHistory: [Double] = []
    private var timer: Timer?
    private let maxDataPoints = 12
    private var updateInterval: Double = 1.0
    
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
        DispatchQueue.main.async {
            self.cpuHistory.append(cpuUsage)
            if self.cpuHistory.count > self.maxDataPoints {
                self.cpuHistory.removeFirst()
            }
        }
    }
    
    private func getCPUUsage() -> Double {
        var loadAverage = [Double](repeating: 0.0, count: 3)
        
        // Get system load average
        let result = loadAverage.withUnsafeMutableBufferPointer { buffer -> Int32 in
            guard let baseAddress = buffer.baseAddress else { return -1 }
            return getLoadAverage(baseAddress, 3)
        }
        
        guard result == 3 else {
            return 0.0
        }
        
        // Get number of CPU cores
        let coreCount = Double(ProcessInfo.processInfo.activeProcessorCount)
        
        // Calculate CPU usage as percentage (1-minute load average)
        let cpuUsage = (loadAverage[0] / coreCount) * 100.0
        
        return min(max(cpuUsage, 0.0), 100.0)
    }
}
