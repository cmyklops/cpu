import Foundation

// Import getloadavg from libc
@_silgen_name("getloadavg")
private func getLoadAverage(_ loadavg: UnsafeMutablePointer<Double>, _ nelem: Int32) -> Int32

class CPUMonitor: NSObject, ObservableObject {
    static let shared = CPUMonitor()
    
    @Published var cpuHistory: [Double] = []
    private var timer: Timer?
    private let maxDataPoints = 12
    
    override init() {
        super.init()
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.updateCPU()
        }
        // Trigger first update immediately
        updateCPU()
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
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
