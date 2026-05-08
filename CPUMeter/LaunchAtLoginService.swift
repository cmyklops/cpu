import Foundation
import OSLog
import ServiceManagement

protocol LaunchAtLoginServicing: AnyObject {
    func status() -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) throws
}

enum LaunchAtLoginError: LocalizedError {
    case executableUnavailable
    case launchctlFailed(String)

    var errorDescription: String? {
        switch self {
        case .executableUnavailable:
            return "App executable was not found."
        case .launchctlFailed(let message):
            return message
        }
    }
}

final class LaunchAtLoginService: LaunchAtLoginServicing {
    private let fileManager: FileManager
    private let bundle: Bundle
    private let launchAgentURL: URL

    init(
        fileManager: FileManager = .default,
        bundle: Bundle = .main,
        launchAgentURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.bundle = bundle
        self.launchAgentURL = launchAgentURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents/com.cpumeter.app.plist")
    }

    func status() -> LaunchAtLoginStatus {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                return .enabled
            case .requiresApproval:
                return .requiresApproval
            case .notRegistered:
                return .disabled
            case .notFound:
                return .unavailable
            @unknown default:
                return .unavailable
            }
        }

        return fileManager.fileExists(atPath: launchAgentURL.path) ? .enabled : .disabled
    }

    func setEnabled(_ enabled: Bool) throws {
        if #available(macOS 13.0, *) {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return
        }

        if enabled {
            try enableLegacyLaunchAgent()
        } else {
            try disableLegacyLaunchAgent(removePlist: true)
        }
    }

    private func enableLegacyLaunchAgent() throws {
        guard let executableURL = bundle.executableURL else {
            throw LaunchAtLoginError.executableUnavailable
        }

        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )

        let plistData: [String: Any] = [
            "Label": "com.cpumeter.app",
            "ProgramArguments": [executableURL.path],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        let plistContent = try PropertyListSerialization.data(
            fromPropertyList: plistData,
            format: .xml,
            options: 0
        )
        try plistContent.write(to: launchAgentURL, options: .atomic)

        do {
            try runLaunchctl(arguments: ["bootstrap", "gui/\(getuid())", launchAgentURL.path])
        } catch {
            Logger.startup.warning("Legacy launch agent bootstrap failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func disableLegacyLaunchAgent(removePlist: Bool) throws {
        if fileManager.fileExists(atPath: launchAgentURL.path) {
            do {
                try runLaunchctl(arguments: ["bootout", "gui/\(getuid())", launchAgentURL.path])
            } catch {
                Logger.startup.warning("Legacy launch agent bootout failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        if removePlist {
            try? fileManager.removeItem(at: launchAgentURL)
        }
    }

    private func runLaunchctl(arguments: [String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments

        let errorPipe = Pipe()
        process.standardError = errorPipe
        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
            let message = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw LaunchAtLoginError.launchctlFailed(message?.isEmpty == false ? message! : "launchctl failed.")
        }
    }
}
