import Foundation

struct MetricStats: Equatable {
    var current: Double = 0
    var average: Double = 0
    var peak: Double = 0
}

struct MonitorSnapshot: Equatable {
    var cpuHistory: [Double]
    var memoryHistory: [Double]
    var currentMetric: MetricType
    var stats: MetricStats
}

struct CPUTicks: Equatable {
    var user: UInt64
    var system: UInt64
    var idle: UInt64
    var nice: UInt64
}

struct CPUUsageCalculator {
    private var previousTicks: CPUTicks?

    mutating func usage(from ticks: CPUTicks) -> Double {
        guard let previousTicks else {
            self.previousTicks = ticks
            return 0
        }

        let diffs = [
            ticks.user.subtractingReportingOverflow(previousTicks.user),
            ticks.system.subtractingReportingOverflow(previousTicks.system),
            ticks.idle.subtractingReportingOverflow(previousTicks.idle),
            ticks.nice.subtractingReportingOverflow(previousTicks.nice)
        ]

        guard diffs.allSatisfy({ !$0.overflow }) else {
            self.previousTicks = ticks
            return 0
        }

        self.previousTicks = ticks

        let userDiff = diffs[0].partialValue
        let systemDiff = diffs[1].partialValue
        let idleDiff = diffs[2].partialValue
        let niceDiff = diffs[3].partialValue
        let totalDiff = userDiff + systemDiff + idleDiff + niceDiff

        guard totalDiff > 0 else {
            return 0
        }

        let usedDiff = userDiff + systemDiff + niceDiff
        let usage = Double(usedDiff) / Double(totalDiff) * 100
        return min(max(usage, 0), 100)
    }
}

struct MonitorHistoryModel {
    let maxDataPoints: Int
    private(set) var cpuHistory: [Double] = []
    private(set) var memoryHistory: [Double] = []
    private(set) var currentMetric: MetricType

    init(maxDataPoints: Int = 12, currentMetric: MetricType = .cpu) {
        self.maxDataPoints = maxDataPoints
        self.currentMetric = currentMetric
    }

    mutating func setMetric(_ metric: MetricType) -> MonitorSnapshot {
        currentMetric = metric
        return snapshot()
    }

    mutating func record(cpuUsage: Double, memoryUsage: Double, smoothingFactor: Double) -> MonitorSnapshot {
        cpuHistory.append(smoothed(newValue: cpuUsage, history: cpuHistory, factor: smoothingFactor))
        memoryHistory.append(smoothed(newValue: memoryUsage, history: memoryHistory, factor: smoothingFactor))

        trimHistory()
        return snapshot()
    }

    func snapshot() -> MonitorSnapshot {
        MonitorSnapshot(
            cpuHistory: cpuHistory,
            memoryHistory: memoryHistory,
            currentMetric: currentMetric,
            stats: stats(for: currentMetric)
        )
    }

    private func stats(for metric: MetricType) -> MetricStats {
        let history = metric == .cpu ? cpuHistory : memoryHistory
        guard !history.isEmpty else {
            return MetricStats()
        }

        return MetricStats(
            current: history.last ?? 0,
            average: history.reduce(0, +) / Double(history.count),
            peak: history.max() ?? 0
        )
    }

    private func smoothed(newValue: Double, history: [Double], factor: Double) -> Double {
        guard let lastValue = history.last else {
            return newValue
        }
        return (newValue * factor) + (lastValue * (1 - factor))
    }

    private mutating func trimHistory() {
        if cpuHistory.count > maxDataPoints {
            cpuHistory.removeFirst(cpuHistory.count - maxDataPoints)
        }
        if memoryHistory.count > maxDataPoints {
            memoryHistory.removeFirst(memoryHistory.count - maxDataPoints)
        }
    }
}
