import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.cpumeter.app"

    static let sampling = Logger(subsystem: subsystem, category: "sampling")
    static let preferences = Logger(subsystem: subsystem, category: "preferences")
    static let startup = Logger(subsystem: subsystem, category: "startup")
    static let release = Logger(subsystem: subsystem, category: "release")
}
