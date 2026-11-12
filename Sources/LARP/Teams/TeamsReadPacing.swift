import Foundation

/// When Teams is read next: every 2 seconds (more after readings that reached a limit), sooner
/// when Teams announces a change, but never in the 3 seconds after Teams opened a window and
/// never sooner than 1 second after the end of the previous reading. Pure, so the rules can be
/// tested without a clock.
struct TeamsReadPacing: Sendable {
    /// The shortest time between the end of a reading and the start of the next.
    static let minimumGap: Duration = .seconds(1)
    /// How long Teams is left alone after it opened a window.
    static let quietAfterWindow: Duration = .seconds(3)

    private var lastEnd: ContinuousClock.Instant?
    private var lastWindowOpened: ContinuousClock.Instant?
    private var announcedAt: ContinuousClock.Instant?
    private var pause: Duration = .seconds(TeamsReadingLimits.basePause)

    /// Teams opened a window: it is read sooner, but not for 3 seconds.
    mutating func windowOpened(at instant: ContinuousClock.Instant) {
        lastWindowOpened = instant
        announced(at: instant)
    }

    /// Teams changed the title of a window, or something else that makes a reading come sooner.
    mutating func announced(at instant: ContinuousClock.Instant) {
        announcedAt = announcedAt ?? instant
    }

    /// A reading starts: what was announced until now is covered by it.
    mutating func readStarted() {
        announcedAt = nil
    }

    /// A reading ended; the next one follows after `pause` seconds.
    mutating func readFinished(at instant: ContinuousClock.Instant, pause seconds: TimeInterval) {
        lastEnd = instant
        pause = .seconds(seconds)
    }

    /// When the next reading may start, given that none runs: the end of the previous one plus the
    /// pause, or the announcement if it came first, and never before the quiet times.
    func nextStart(now: ContinuousClock.Instant) -> ContinuousClock.Instant {
        var due = lastEnd.map { $0 + pause } ?? now
        if let announcedAt { due = min(due, announcedAt) }
        var earliest = due
        if let lastEnd { earliest = max(earliest, lastEnd + Self.minimumGap) }
        if let lastWindowOpened { earliest = max(earliest, lastWindowOpened + Self.quietAfterWindow) }
        return earliest
    }
}
