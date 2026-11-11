import Foundation
import SwiftData

/// A moment of a call that the user marked. It has only its time and belongs to one call;
/// it is not tied to a transcript line, so it stays when the lines of a call are discarded
/// and the call is transcribed again.
@Model
final class Bookmark {
    @Attribute(.unique) var id: UUID
    /// Seconds from the start of the call, whole and never below zero.
    var time: TimeInterval
    var call: Call?

    init(id: UUID = UUID(), time: TimeInterval) {
        self.id = id
        self.time = Self.normalizedTime(time)
    }

    /// The second of the call a time falls in: whole, never below zero.
    static func normalizedTime(_ time: TimeInterval) -> TimeInterval {
        time.isFinite ? max(0, time.rounded(.down)) : 0
    }
}
