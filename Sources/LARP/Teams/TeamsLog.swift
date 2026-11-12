import Foundation
import os

/// The diagnostic log of the reading of Teams (area `teams` of the diagnostic log of LARP, and the
/// category `teams` of `os.Logger`). It stays on the Mac and never holds a title, a name or any
/// other text read from Teams: only numbers and reasons.
enum TeamsLog {
    static let logger = Logger(subsystem: "com.larp.LARP", category: "teams")

    /// The line of one reading.
    static func line(for result: TeamsTreeResult) -> String {
        let milliseconds = Int((result.duration * 1000).rounded())
        let limit = result.limit.map { "reached the limit of \($0.rawValue)" } ?? "within the limits"
        let seconds = String(format: "%.0f", result.pause)
        return "Reading: \(milliseconds) ms, \(result.elements) elements in \(result.windows) windows, \(limit), "
            + "expose request \(result.exposeRequested ? "made" : "not made"), "
            + "meeting marker \(result.markerFound ? "found" : "not found"), "
            + "\(result.participantElements) participant elements, \(result.speakerMarks) speaker marks, "
            + "next reading after \(seconds) s"
    }

    static func reading(_ result: TeamsTreeResult) {
        write(line(for: result))
    }

    /// The reading of Teams starts or stops, and why.
    static func started(_ reason: String) { write("Teams reading started: \(reason)") }

    static func stopped(_ reason: String) { write("Teams reading stopped: \(reason)") }

    /// A launch of Teams that is not read any more.
    static func gaveUp() {
        write(
            "Teams launch given up: no web identifier in \(TeamsReadingLimits.readingsWithoutIdentifiersBeforeGivingUp) readings after the request to expose the interface")
    }

    private static func write(_ message: String) {
        logger.info("\(message, privacy: .public)")
        DiagnosticLog.write(area: .teams, message)
    }
}
