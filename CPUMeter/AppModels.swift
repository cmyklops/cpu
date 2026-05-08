import Foundation

enum MetricType: String, CaseIterable, Codable, Identifiable {
    case cpu = "CPU"
    case memory = "Memory"

    var id: String { rawValue }
}

enum DisplayMode: String, CaseIterable, Codable, Identifiable {
    case bars
    case number
    case gradient

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bars: return "Bars"
        case .number: return "Number"
        case .gradient: return "Gradient"
        }
    }
}

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unavailable
    case failed(String)

    var isEnabled: Bool {
        if case .enabled = self {
            return true
        }
        return false
    }

    var message: String {
        switch self {
        case .enabled:
            return "Enabled"
        case .disabled:
            return "Disabled"
        case .requiresApproval:
            return "Needs approval"
        case .unavailable:
            return "Install app to enable"
        case .failed:
            return "Could not update"
        }
    }

    var detail: String {
        switch self {
        case .enabled:
            return "CPUMeter will open automatically when you log in."
        case .disabled:
            return "CPUMeter will not open automatically when you log in."
        case .requiresApproval:
            return "Approve CPUMeter in System Settings > General > Login Items."
        case .unavailable:
            return "Launch at startup is available after CPUMeter is installed normally, such as in the Applications folder."
        case .failed(let message):
            return message
        }
    }
}

enum SampleStatus: Equatable {
    case waiting
    case fresh
    case stale
    case failed(String)

    var message: String {
        switch self {
        case .waiting:
            return "Waiting for first sample"
        case .fresh:
            return "Fresh"
        case .stale:
            return "Stale"
        case .failed(let message):
            return message
        }
    }
}
