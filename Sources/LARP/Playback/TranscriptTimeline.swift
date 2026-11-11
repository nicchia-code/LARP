import Foundation

/// The time span of a transcript line, in seconds from the start of the call.
struct LineTiming: Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
}

/// What skipping a silence does at a given time.
enum SilenceSkip: Equatable, Sendable {
    /// Jump to this time of the call.
    case seek(to: TimeInterval)
    /// No line is left: the audio ends.
    case end
}

/// Finds the transcript line being heard at a given time of the call.
///
/// Spans must be given sorted by `start` (the order the transcript is shown in).
/// Lines of the two tracks may overlap: the line that started last wins.
struct TranscriptTimeline: Equatable, Sendable {
    /// A stretch without lines is skipped only when longer than this, in seconds.
    static let silenceThreshold: TimeInterval = 2
    /// A skip lands this many seconds before the start of the next line.
    static let silenceLeadIn: TimeInterval = 0.3

    private let spans: [LineTiming]
    /// Longest span, which bounds how far back an overlapping line can start.
    private let longestSpan: TimeInterval
    /// `latestEnd[i]` is the latest end among the spans `0...i`.
    private let latestEnd: [TimeInterval]

    static let empty = TranscriptTimeline(spans: [])

    init(spans: [LineTiming]) {
        self.spans = spans
        self.longestSpan = spans.map { max($0.end - $0.start, 0) }.max() ?? 0
        var latest = -TimeInterval.infinity
        self.latestEnd = spans.map {
            latest = max(latest, $0.end)
            return latest
        }
    }

    var isEmpty: Bool { spans.isEmpty }

    /// First index whose start is after `time` (binary search).
    private func firstIndex(startingAfter time: TimeInterval) -> Int {
        var low = 0
        var high = spans.count
        while low < high {
            let middle = (low + high) / 2
            if spans[middle].start <= time {
                low = middle + 1
            } else {
                high = middle
            }
        }
        return low
    }

    /// Index of the line with `start <= time < end`, or `nil` when no line is being spoken.
    func lineIndex(at time: TimeInterval) -> Int? {
        var index = firstIndex(startingAfter: time) - 1
        while index >= 0 {
            let span = spans[index]
            if time < span.end { return index }
            // No earlier line can reach `time`: they all start before `time - longestSpan`.
            if span.start < time - longestSpan { return nil }
            index -= 1
        }
        return nil
    }

    /// What to do when `time` is in a stretch without lines longer than two seconds (from the end
    /// of the line before, or the start of the audio, to the start of the next line, or the end of
    /// the audio, `duration`): jump to 0.3 seconds before the next line, or end when there is none.
    /// `nil` when a line is being spoken, the stretch is short, or the jump would not move forward.
    func silenceSkip(at time: TimeInterval, duration: TimeInterval) -> SilenceSkip? {
        guard lineIndex(at: time) == nil else { return nil }
        let next = firstIndex(startingAfter: time)
        let stretchStart = next > 0 ? max(latestEnd[next - 1], 0) : 0
        let stretchEnd = next < spans.count ? spans[next].start : duration
        guard stretchEnd - stretchStart > Self.silenceThreshold else { return nil }
        guard next < spans.count else { return .end }
        let target = stretchEnd - Self.silenceLeadIn
        return target > time ? .seek(to: target) : nil
    }
}
