import Testing

@testable import LARP

@Suite("TranscriptTimeline")
struct TranscriptTimelineTests {
    private func timeline(_ pairs: [(Double, Double)]) -> TranscriptTimeline {
        TranscriptTimeline(spans: pairs.map { LineTiming(start: $0.0, end: $0.1) })
    }

    @Test("a time inside a line finds that line; the end of a line belongs to the next one")
    func findsLineAtTime() {
        let timeline = timeline([(0, 2), (2, 5), (6, 8)])
        #expect(timeline.lineIndex(at: 0) == 0)
        #expect(timeline.lineIndex(at: 1.99) == 0)
        #expect(timeline.lineIndex(at: 2) == 1)
        #expect(timeline.lineIndex(at: 4.5) == 1)
        #expect(timeline.lineIndex(at: 6) == 2)
        #expect(timeline.lineIndex(at: 7.9) == 2)
    }

    @Test("no line is found in a silence, before the first line or after the last")
    func noLineOutsideSpeech() {
        let timeline = timeline([(1, 2), (4, 5)])
        #expect(timeline.lineIndex(at: 0.5) == nil)
        #expect(timeline.lineIndex(at: 3) == nil)
        #expect(timeline.lineIndex(at: 5) == nil)
        #expect(timeline.lineIndex(at: 100) == nil)
        #expect(timeline.lineIndex(at: -1) == nil)
    }

    @Test("an empty transcript has no current line")
    func emptyTimeline() {
        #expect(TranscriptTimeline.empty.lineIndex(at: 3) == nil)
        #expect(TranscriptTimeline.empty.isEmpty)
    }

    @Test("with overlapping lines the one that started last wins, then the earlier one again")
    func overlappingLines() {
        let timeline = timeline([(0, 10), (3, 4)])
        #expect(timeline.lineIndex(at: 2) == 0)
        #expect(timeline.lineIndex(at: 3.5) == 1)
        #expect(timeline.lineIndex(at: 5) == 0)
    }

    @Test("a long line is found even after several shorter lines that ended before the time")
    func longLineTimingningOthers() {
        let timeline = timeline([(0, 100), (10, 11), (20, 21)])
        #expect(timeline.lineIndex(at: 50) == 0)
        #expect(timeline.lineIndex(at: 20.5) == 2)
        #expect(timeline.lineIndex(at: 100) == nil)
    }
}
