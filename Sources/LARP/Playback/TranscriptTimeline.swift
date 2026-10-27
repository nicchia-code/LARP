import Foundation

/// The time span of a transcript line, in seconds from the start of the call.
struct LineTiming: Equatable, Sendable {
    var start: TimeInterval
    var end: TimeInterval
}

/// Finds the transcript line being heard at a given time of the call.
///
/// Spans must be given sorted by `start` (the order the transcript is shown in).
/// Lines of the two tracks may overlap: the line that started last wins.
struct TranscriptTimeline: Equatable, Sendable {
    private let spans: [LineTiming]
    /// Longest span, which bounds how far back an overlapping line can start.
    private let longestSpan: TimeInterval

    static let empty = TranscriptTimeline(spans: [])

    init(spans: [LineTiming]) {
        self.spans = spans
        self.longestSpan = spans.map { max($0.end - $0.start, 0) }.max() ?? 0
    }

    var isEmpty: Bool { spans.isEmpty }

    /// Index of the line with `start <= time < end`, or `nil` when no line is being spoken.
    func lineIndex(at time: TimeInterval) -> Int? {
        // Binary search: first index whose start is after `time`.
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
        var index = low - 1
        while index >= 0 {
            let span = spans[index]
            if time < span.end { return index }
            // No earlier line can reach `time`: they all start before `time - longestSpan`.
            if span.start < time - longestSpan { return nil }
            index -= 1
        }
        return nil
    }
}
