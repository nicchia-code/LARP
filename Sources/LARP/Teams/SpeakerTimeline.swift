import Foundation

/// One span of the timeline of Teams speakers of a call: who Teams marked as speaking between two
/// moments, in seconds from the start of the call. `name` is `nil` when nobody was marked.
struct SpeakerSpan: Codable, Hashable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var name: String?
}

/// Builds the timeline of Teams speakers of the call being recorded (`teams.SPEAKER_CHANGED`):
/// one span per change, closed by the next change, and no span shorter than 300 ms.
///
/// Nothing is added while the recording is paused: the span open when it pauses is closed there,
/// and the speaker marked when it resumes opens a new one. A timeline starts with the first
/// speaker known, so a call that never saw Teams has none.
struct SpeakerTimelineBuilder: Sendable {
    /// Spans shorter than this are dropped.
    static let minimumSpan: TimeInterval = 0.3

    /// The spans closed so far, in order of time.
    private(set) var spans: [SpeakerSpan] = []
    /// The span being lived: who is marked and since when. `nil` before the first speaker is known
    /// and while paused.
    private var open: (name: String?, start: TimeInterval)?
    /// The speaker Teams marks now, also while paused, for the span that opens on resume.
    private var current: (known: Bool, name: String?) = (false, nil)
    private var isPaused = false

    init() {}

    /// The speaker Teams marks when the recording starts, with the meeting already on: the first
    /// span opens at `time`.
    mutating func begin(speaker name: String?, at time: TimeInterval) {
        current = (true, name)
        guard !isPaused else { return }
        open = (name, time)
    }

    /// `teams.SPEAKER_CHANGED` at `time` seconds into the call. While paused the change is not
    /// added; it is only remembered for the resume.
    mutating func change(to name: String?, at time: TimeInterval) {
        current = (true, name)
        guard !isPaused else { return }
        close(at: time)
        open = (name, time)
    }

    /// `user.PAUSE_RECORDING`: the span open ends here.
    mutating func pause(at time: TimeInterval) {
        guard !isPaused else { return }
        isPaused = true
        close(at: time)
    }

    /// `user.RESUME_RECORDING`: the speaker marked now opens a new span, when one is known.
    mutating func resume(at time: TimeInterval) {
        guard isPaused else { return }
        isPaused = false
        if current.known { open = (current.name, time) }
    }

    /// The meeting ends at `time` (`teams.MEETING_LEFT`, `teams-access.ACCESS_LOST`): the span open
    /// ends here, and no speaker is known until the next change.
    mutating func meetingEnded(at time: TimeInterval) {
        current = (false, nil)
        close(at: time)
    }

    /// The recording ends at `time`: the span open ends here.
    mutating func finish(at time: TimeInterval) {
        close(at: time)
    }

    private mutating func close(at time: TimeInterval) {
        guard let open else { return }
        self.open = nil
        // Measured in whole milliseconds, so that 300 ms written as 5.599 - 5.299 is not lost to the
        // rounding of floating point numbers.
        guard ((time - open.start) * 1000).rounded() >= Self.minimumSpan * 1000 else { return }
        spans.append(SpeakerSpan(start: open.start, end: time, name: open.name))
    }
}
