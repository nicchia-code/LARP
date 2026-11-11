import Foundation

/// What the live window shows of Microsoft Teams while it shows the meeting of the call and
/// "Identifica i parlanti" is on. It is a view only: nothing of it changes the lines kept with the
/// call. Without a meeting, or with the switch off, the window shows "Io" and "Altri" as always.
enum LiveTeamsNames {
    /// The name Teams marked as speaking at `time` seconds into the call: the span of the timeline
    /// that covers it, or, for a moment after the last closed span, the speaker Teams marks now (the
    /// span still open); `nil` when nobody was marked, or in the gaps the timeline leaves (while
    /// paused, or for a change shorter than the timeline keeps).
    static func speaker(at time: TimeInterval, spans: [SpeakerSpan], current: String?) -> String? {
        if let span = spans.first(where: { $0.start <= time && time < $0.end }) {
            return span.name
        }
        if time >= (spans.last?.end ?? 0) {
            return current
        }
        return nil
    }

    /// One person of "Nella call".
    struct Member: Equatable, Identifiable, Sendable {
        var name: String
        /// Teams marks this person as speaking now.
        var isSpeaking: Bool

        var id: String { name }
    }

    /// The people Teams shows in the meeting, each marked when Teams indicates them as speaking.
    static func members(people: [String], speaker: String?) -> [Member] {
        let folded = speaker.map(TeamsText.fold)
        return people.map { Member(name: $0, isSpeaking: folded != nil && TeamsText.fold($0) == folded) }
    }
}
