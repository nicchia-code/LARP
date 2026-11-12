import AppKit
import Darwin

/// The reading of process information the detection of call apps needs: the process macOS
/// holds responsible for a process, its parent and the bundle identifier of a running
/// application. Replaced in tests.
protocol ProcessInfoReading: Sendable {
    /// The process macOS holds responsible for `pid` (the app that the microphone indicator
    /// names), or `nil` when it cannot be read.
    func responsiblePID(of pid: pid_t) -> pid_t?
    /// The parent of `pid`, or `nil` when it cannot be read.
    func parentPID(of pid: pid_t) -> pid_t?
    /// The bundle identifier of the running application `pid`, or `nil` when it is not one.
    func bundleIdentifier(of pid: pid_t) -> String?
}

/// Reads the process information from macOS: the responsible process through an undocumented
/// function looked up at run time (`responsibility_get_pid_for_pid`, else
/// `responsibility_get_pid_responsible_for_pid`, the name this macOS exports), the parent
/// through the BSD process information and bundle identifiers through the running
/// applications of AppKit.
struct SystemProcessInfoReader: ProcessInfoReading {
    private typealias ResponsibilityFunction = @convention(c) (pid_t) -> pid_t

    /// The names of the responsibility function, in the order they are tried.
    static let responsibilitySymbolNames = [
        "responsibility_get_pid_for_pid",
        "responsibility_get_pid_responsible_for_pid",
    ]

    /// The address of the first of `names` that `lookup` finds, or `nil` when none is found.
    static func firstSymbol(
        in names: [String], lookup: (String) -> UnsafeMutableRawPointer?
    ) -> UnsafeMutableRawPointer? {
        for name in names {
            if let symbol = lookup(name) { return symbol }
        }
        return nil
    }

    /// `nil` when this macOS has none of the functions.
    private static let responsibilityFunction: ResponsibilityFunction? = {
        let rtldDefault = UnsafeMutableRawPointer(bitPattern: -2)
        guard let symbol = firstSymbol(in: responsibilitySymbolNames, lookup: { dlsym(rtldDefault, $0) }) else {
            return nil
        }
        return unsafeBitCast(symbol, to: ResponsibilityFunction.self)
    }()

    func responsiblePID(of pid: pid_t) -> pid_t? {
        guard let function = Self.responsibilityFunction else { return nil }
        let responsible = function(pid)
        return responsible > 0 ? responsible : nil
    }

    func parentPID(of pid: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else { return nil }
        return pid_t(info.pbi_ppid)
    }

    func bundleIdentifier(of pid: pid_t) -> String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }
}

/// A process met while attributing a microphone user to a call app.
struct ProcessIdentity: Equatable, Sendable {
    let pid: pid_t
    /// `nil` when the process is not a running application.
    let bundleIdentifier: String?
}

/// What was read about a process using the microphone and the call app it was attributed to.
struct CallAppAttribution: Equatable, Sendable {
    /// Why the walk up the parent processes ended.
    enum WalkEnd: Equatable, Sendable {
        /// The app was found before the walk, or the walk found it itself.
        case notWalked
        case matchedParent
        /// The parent has identifier 1 or lower (`launchd`).
        case reachedRoot(pid: pid_t)
        /// The parent of this process could not be read.
        case parentUnreadable(pid: pid_t)
        /// The maximum number of levels was reached without a match.
        case levelLimit
        /// The identifier of the process is not known, so it has no parents to walk.
        case unknownPID
    }

    /// The most levels of parent processes looked at.
    static let maxParentLevels = 8

    let pid: pid_t?
    /// The bundle identifier as Core Audio reports it; empty when it reports none.
    let coreAudioBundleIdentifier: String
    let responsible: ProcessIdentity?
    /// The parent processes looked at, nearest first.
    let parents: [ProcessIdentity]
    let walkEnd: WalkEnd
    let app: CallApp?

    /// The known call app the process belongs to: first the app macOS holds responsible for it;
    /// then the process itself; then its parents, up to `maxParentLevels`, stopping at the first
    /// process with identifier 1 or lower. The first app of `apps` that matches wins.
    static func resolve(
        pid: pid_t?, coreAudioBundleIdentifier: String?, reader: any ProcessInfoReading,
        apps: [CallApp] = KnownCallApps.all
    ) -> CallAppAttribution {
        let ownBundleIdentifier = coreAudioBundleIdentifier ?? ""

        var responsible: ProcessIdentity?
        if let pid, let responsiblePID = reader.responsiblePID(of: pid) {
            // The own bundle identifier of the process is the one Core Audio reports: the
            // process itself is never looked up among the running applications.
            let bundleIdentifier = responsiblePID == pid
                ? (ownBundleIdentifier.isEmpty ? nil : ownBundleIdentifier)
                : reader.bundleIdentifier(of: responsiblePID)
            responsible = ProcessIdentity(pid: responsiblePID, bundleIdentifier: bundleIdentifier)
            if let bundleIdentifier, let app = KnownCallApps.app(forBundleIdentifier: bundleIdentifier, in: apps) {
                return CallAppAttribution(
                    pid: pid, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
                    parents: [], walkEnd: .notWalked, app: app)
            }
        }

        if !ownBundleIdentifier.isEmpty,
           let app = KnownCallApps.app(forBundleIdentifier: ownBundleIdentifier, in: apps) {
            return CallAppAttribution(
                pid: pid, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
                parents: [], walkEnd: .notWalked, app: app)
        }

        guard var current = pid else {
            return CallAppAttribution(
                pid: nil, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
                parents: [], walkEnd: .unknownPID, app: nil)
        }
        var parents: [ProcessIdentity] = []
        for _ in 0..<maxParentLevels {
            guard let parent = reader.parentPID(of: current) else {
                return CallAppAttribution(
                    pid: pid, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
                    parents: parents, walkEnd: .parentUnreadable(pid: current), app: nil)
            }
            guard parent > 1 else {
                return CallAppAttribution(
                    pid: pid, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
                    parents: parents, walkEnd: .reachedRoot(pid: parent), app: nil)
            }
            let bundleIdentifier = reader.bundleIdentifier(of: parent)
            parents.append(ProcessIdentity(pid: parent, bundleIdentifier: bundleIdentifier))
            if let bundleIdentifier, let app = KnownCallApps.app(forBundleIdentifier: bundleIdentifier, in: apps) {
                return CallAppAttribution(
                    pid: pid, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
                    parents: parents, walkEnd: .matchedParent, app: app)
            }
            current = parent
        }
        return CallAppAttribution(
            pid: pid, coreAudioBundleIdentifier: ownBundleIdentifier, responsible: responsible,
            parents: parents, walkEnd: .levelLimit, app: nil)
    }
}

extension CallAppAttribution {
    /// The details as the diagnostic log tells them: only process and app identifiers.
    var logDescription: String {
        let pidText = pid.map { String($0) } ?? "unknown"
        let responsibleText = responsible.map { "\($0.pid) \(Self.quoted($0.bundleIdentifier))" } ?? "none"
        let parentsText = parents.isEmpty
            ? "none"
            : parents.enumerated().map { "\($0.offset + 1): \($0.element.pid) \(Self.quoted($0.element.bundleIdentifier))" }
                .joined(separator: ", ")
        return "pid \(pidText) bundle \(Self.quoted(coreAudioBundleIdentifier)); responsible \(responsibleText); "
            + "parents \(parentsText); walk ended: \(walkEnd.logDescription); call app: \(app?.name ?? "none")"
    }

    private static func quoted(_ bundleIdentifier: String?) -> String {
        "\"\(bundleIdentifier ?? "")\""
    }
}

extension CallAppAttribution.WalkEnd {
    var logDescription: String {
        switch self {
        case .notWalked: "not needed, app recognised before the walk"
        case .matchedParent: "app recognised in a parent"
        case .reachedRoot(let pid): "parent has identifier \(pid) (1 or lower)"
        case .parentUnreadable(let pid): "parent of \(pid) could not be read"
        case .levelLimit: "limit of \(CallAppAttribution.maxParentLevels) levels reached"
        case .unknownPID: "process identifier unknown"
        }
    }
}
