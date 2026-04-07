import Foundation
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Crash Report Service

/// Lightweight crash reporter that captures uncaught exceptions and POSIX signals,
/// writes a report to disk, and offers to email it on next launch.
/// No third-party SDKs required.
enum CrashReportService {

    /// Fixed file name in the Documents directory.
    static let crashFileName = "crash_report.txt"

    /// Developer contact email for crash reports.
    static let contactEmail = "spltr3app@gmail.com"

    /// Full URL of the crash report file.
    static var crashFileURL: URL {
        // Always available on iOS
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent(crashFileName)
    }

    // Pre-allocated C-level data for async-signal-safe access in signal handler.
    // These avoid ARC and heap allocation when accessed from a signal context.
    private static var filePathBuffer: UnsafeMutablePointer<CChar>?
    private static var headerBuffer: UnsafeMutablePointer<CChar>?
    private static var headerLength: Int = 0
    private static var backtraceBuffer = UnsafeMutablePointer<UnsafeMutableRawPointer?>.allocate(capacity: 128)

    // Rich values for the exception handler path (safe to use ARC there)
    private static var cachedVersion: String = "unknown"
    private static var cachedBuild: String = "unknown"
    private static var cachedSystemVersion: String = "unknown"
    private static var cachedModel: String = "unknown"

    // MARK: - Install handlers

    /// Call once during App.init to register exception and signal handlers.
    static func install() {
        // Pre-cache values for the rich exception report path
        cachedVersion = Bundle.main.appVersion
        cachedBuild = Bundle.main.buildNumber
        cachedSystemVersion = deviceSystemVersion()
        cachedModel = deviceModel()

        // Pre-allocate C strings for the signal handler (no ARC, no heap alloc at crash time)
        if let cPath = crashFileURL.path.cString(using: .utf8) {
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: cPath.count)
            buf.initialize(from: cPath, count: cPath.count)
            filePathBuffer = buf
        }

        // Pre-build the report header as a C string
        let header = """
        === Butter Run Crash Report ===

        App Version: \(cachedVersion) (\(cachedBuild))
        iOS Version: \(cachedSystemVersion)
        Device:      \(cachedModel)

        --- Crash Info ---
        Type: Signal
        """
        if let cHeader = header.cString(using: .utf8) {
            let buf = UnsafeMutablePointer<CChar>.allocate(capacity: cHeader.count)
            buf.initialize(from: cHeader, count: cHeader.count)
            headerBuffer = buf
            headerLength = cHeader.count - 1 // exclude null terminator
        }

        NSSetUncaughtExceptionHandler { exception in
            CrashReportService.handleException(exception)
        }

        let signals: [Int32] = [SIGABRT, SIGSEGV, SIGBUS, SIGFPE, SIGILL]
        for sig in signals {
            signal(sig) { signalValue in
                CrashReportService.handleSignal(signalValue)
            }
        }
    }

    // MARK: - Pending report check

    /// Returns the crash report contents if a file exists from a previous session.
    static func pendingReport() -> String? {
        return try? String(contentsOf: crashFileURL, encoding: .utf8)
    }

    /// Deletes any pending crash report file.
    static func deletePendingReport() {
        try? FileManager.default.removeItem(at: crashFileURL)
    }

    // MARK: - Exception handler (safe to allocate — still on a valid thread)

    private static func handleException(_ exception: NSException) {
        let report = buildRichReport(
            kind: "Uncaught Exception",
            name: exception.name.rawValue,
            reason: exception.reason,
            backtrace: exception.callStackSymbols
        )
        try? report.write(to: crashFileURL, atomically: false, encoding: .utf8)
        NSSetUncaughtExceptionHandler(nil)
    }

    // MARK: - Signal handler (async-signal-safe — no ARC, no Swift allocation)

    private static func handleSignal(_ sig: Int32) {
        guard let path = filePathBuffer else {
            signal(sig, SIG_DFL)
            raise(sig)
            return
        }

        let fd = open(path, O_WRONLY | O_CREAT | O_TRUNC, 0o644)
        guard fd >= 0 else {
            signal(sig, SIG_DFL)
            raise(sig)
            return
        }

        // Write pre-built header (C string, no ARC)
        if let hdr = headerBuffer {
            _ = write(fd, hdr, headerLength)
        }

        // Write signal name
        switch sig {
        case SIGABRT: writeCString(fd, "SIGABRT\n")
        case SIGSEGV: writeCString(fd, "SIGSEGV\n")
        case SIGBUS:  writeCString(fd, "SIGBUS\n")
        case SIGFPE:  writeCString(fd, "SIGFPE\n")
        case SIGILL:  writeCString(fd, "SIGILL\n")
        default:      writeCString(fd, "UNKNOWN\n")
        }

        writeCString(fd, "\n--- Backtrace ---\n")

        // backtrace + backtrace_symbols_fd are async-signal-safe on Darwin
        let frames = backtrace(backtraceBuffer, 128)
        backtrace_symbols_fd(backtraceBuffer, frames, fd)

        writeCString(fd, "\n=== End of Report ===\n")

        close(fd)
        signal(sig, SIG_DFL)
        raise(sig)
    }

    /// Write a StaticString to a file descriptor — no ARC, no heap allocation.
    private static func writeCString(_ fd: Int32, _ str: StaticString) {
        str.withUTF8Buffer { buffer in
            _ = write(fd, buffer.baseAddress, buffer.count)
        }
    }

    // MARK: - Rich report (exception path only — safe to allocate)

    private static func buildRichReport(
        kind: String,
        name: String?,
        reason: String?,
        backtrace: [String]
    ) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        var lines: [String] = []
        lines.append("=== Butter Run Crash Report ===")
        lines.append("")
        lines.append("Timestamp:   \(timestamp)")
        lines.append("App Version: \(cachedVersion) (\(cachedBuild))")
        lines.append("iOS Version: \(cachedSystemVersion)")
        lines.append("Device:      \(cachedModel)")
        lines.append("Free Memory: ~\(approximateAvailableMemoryMB()) MB")
        lines.append("")
        lines.append("--- Crash Info ---")
        lines.append("Type:   \(kind)")
        if let name = name {
            lines.append("Name:   \(name)")
        }
        if let reason = reason {
            lines.append("Reason: \(reason)")
        }
        lines.append("")
        lines.append("--- Backtrace ---")
        for symbol in backtrace {
            lines.append(symbol)
        }
        lines.append("")
        lines.append("=== End of Report ===")
        return lines.joined(separator: "\n")
    }

    // MARK: - Device info helpers

    private static func deviceSystemVersion() -> String {
        #if canImport(UIKit)
        return UIDevice.current.systemVersion
        #else
        return ProcessInfo.processInfo.operatingSystemVersionString
        #endif
    }

    private static func deviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
        return machine
    }

    private static func approximateAvailableMemoryMB() -> Int {
        var pageSize: vm_size_t = 0
        host_page_size(mach_host_self(), &pageSize)

        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }

        let freeBytes = UInt64(stats.free_count) * UInt64(pageSize)
        return Int(freeBytes / (1024 * 1024))
    }

    private static func signalDisplayName(_ sig: Int32) -> String {
        switch sig {
        case SIGABRT: return "SIGABRT"
        case SIGSEGV: return "SIGSEGV"
        case SIGBUS:  return "SIGBUS"
        case SIGFPE:  return "SIGFPE"
        case SIGILL:  return "SIGILL"
        default:      return "SIGNAL(\(sig))"
        }
    }
}
