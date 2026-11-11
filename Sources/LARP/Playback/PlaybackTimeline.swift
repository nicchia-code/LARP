import Foundation

/// The segment of the playback timeline of one transcript line.
struct TimelineSegment: Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
    var speakerKind: SpeakerKind
    /// The participant's number within the call, when the speaker is a participant.
    var participantNumber: Int?

    init(_ line: TranscriptLine) {
        start = line.start
        end = line.end
        speakerKind = line.speakerKind
        participantNumber = line.participant?.number
    }

    init(start: TimeInterval, end: TimeInterval, speakerKind: SpeakerKind, participantNumber: Int? = nil) {
        self.start = start
        self.end = end
        self.speakerKind = speakerKind
        self.participantNumber = participantNumber
    }
}

/// Geometry of the playback timeline: one segment per transcript line placed at its time,
/// a bar at the time reached, and the way back from a position on the timeline to a time.
enum PlaybackTimelineGeometry {
    /// Gap between two segments, in points.
    static let gap: CGFloat = 2

    /// Horizontal span `(x, width)` of every segment, in the same order, for a timeline `width`
    /// points wide that shows `duration` seconds. The gap is taken off the end of each segment;
    /// a segment keeps at least one point, so that a very short line stays visible.
    /// Empty when there is no length to draw.
    static func frames(
        of segments: [TimelineSegment], duration: TimeInterval, width: CGFloat
    ) -> [(x: CGFloat, width: CGFloat)] {
        guard duration > 0, width > 0 else { return [] }
        let scale = width / duration
        return segments.map { segment in
            let start = min(max(segment.start, 0), duration)
            let end = min(max(segment.end, start), duration)
            let x = start * scale
            return (x, max(end * scale - x - gap, 1))
        }
    }

    /// Horizontal position of the bar of the time reached; 0 without a length.
    static func playheadX(time: TimeInterval, duration: TimeInterval, width: CGFloat) -> CGFloat {
        guard duration > 0 else { return 0 }
        return min(max(time, 0), duration) / duration * width
    }

    /// Time under the horizontal position `x`, kept between 0 and `duration`.
    static func time(atX x: CGFloat, duration: TimeInterval, width: CGFloat) -> TimeInterval {
        guard duration > 0, width > 0 else { return 0 }
        return min(max(x / width, 0), 1) * duration
    }
}
