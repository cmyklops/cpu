import Foundation

class SingleInstanceManager {
    static func ensureSingleInstance() -> Bool {
        let lockFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".com.cpumeter.lock")
        
        // Try to create the lock file
        let fileManager = FileManager.default
        
        // Remove stale lock file if process doesn't exist
        if fileManager.fileExists(atPath: lockFile.path) {
            do {
                let data = try Data(contentsOf: lockFile)
                if let pidString = String(data: data, encoding: .utf8), 
                   let pid = Int32(pidString) {
                    // Check if process is still running
                    if kill(pid, 0) == -1 {
                        // Process not running, remove stale lock
                        try fileManager.removeItem(at: lockFile)
                    } else {
                        // Another instance is running
                        return false
                    }
                }
            } catch {
                try? fileManager.removeItem(at: lockFile)
            }
        }
        
        // Write current process ID
        let currentPID = "\(ProcessInfo.processInfo.processIdentifier)"
        try? currentPID.write(to: lockFile, atomically: true, encoding: .utf8)
        
        return true
    }
    
    static func cleanup() {
        let lockFile = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".com.cpumeter.lock")
        try? FileManager.default.removeItem(at: lockFile)
    }
}
