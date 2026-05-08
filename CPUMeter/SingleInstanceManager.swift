import Darwin
import Foundation
import OSLog

final class SingleInstanceLock {
    private let lockURL: URL
    private var fileDescriptor: CInt = -1

    init(lockURL: URL = FileManager.default.temporaryDirectory.appendingPathComponent("com.cpumeter.app.lock")) {
        self.lockURL = lockURL
    }

    deinit {
        release()
    }

    func acquire() -> Bool {
        guard fileDescriptor == -1 else {
            return true
        }

        let descriptor = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard descriptor >= 0 else {
            Logger.startup.error("Unable to open single-instance lock: \(String(cString: strerror(errno)), privacy: .public)")
            return true
        }

        guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else {
            close(descriptor)
            return false
        }

        fileDescriptor = descriptor
        let pid = "\(ProcessInfo.processInfo.processIdentifier)\n"
        _ = ftruncate(fileDescriptor, 0)
        _ = pid.withCString { write(fileDescriptor, $0, strlen($0)) }
        return true
    }

    func release() {
        guard fileDescriptor >= 0 else {
            return
        }

        flock(fileDescriptor, LOCK_UN)
        close(fileDescriptor)
        fileDescriptor = -1
    }
}

enum SingleInstanceManager {
    private static var retainedLock: SingleInstanceLock?

    static func ensureSingleInstance() -> Bool {
        let lock = SingleInstanceLock()
        guard lock.acquire() else {
            return false
        }
        retainedLock = lock
        return true
    }

    static func cleanup() {
        retainedLock?.release()
        retainedLock = nil
    }
}
