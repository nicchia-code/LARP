import CoreGraphics
import Testing

@testable import LARP

@Suite("PlaybackTimelineGeometry")
struct PlaybackTimelineTests {
    private func segment(_ start: Double, _ end: Double) -> TimelineSegment {
        TimelineSegment(start: start, end: end, speakerKind: .me)
    }

    @Test("every segment sits at its time, with a 2 point gap taken off its end")
    func segmentsAtTheirTime() {
        let frames = PlaybackTimelineGeometry.frames(
            of: [segment(0, 10), segment(10, 25), segment(50, 100)], duration: 100, width: 400)
        #expect(frames.count == 3)
        #expect(frames[0].x == 0 && frames[0].width == 38)
        #expect(frames[1].x == 40 && frames[1].width == 58)
        #expect(frames[2].x == 200 && frames[2].width == 198)
    }

    @Test("a very short line keeps one point and a line past the audio is cut at its end")
    func shortAndOverlongSegments() {
        let frames = PlaybackTimelineGeometry.frames(
            of: [segment(1, 1.1), segment(90, 130)], duration: 100, width: 100)
        #expect(frames[0].width == 1)
        #expect(frames[1].x == 90 && frames[1].width == 8)
    }

    @Test("there is nothing to draw without a length or a width")
    func nothingToDraw() {
        #expect(PlaybackTimelineGeometry.frames(of: [segment(0, 1)], duration: 0, width: 100).isEmpty)
        #expect(PlaybackTimelineGeometry.frames(of: [segment(0, 1)], duration: 10, width: 0).isEmpty)
    }

    @Test("a position on the timeline is a time kept between 0 and the length of the audio")
    func positionToTime() {
        #expect(PlaybackTimelineGeometry.time(atX: 100, duration: 60, width: 400) == 15)
        #expect(PlaybackTimelineGeometry.time(atX: -20, duration: 60, width: 400) == 0)
        #expect(PlaybackTimelineGeometry.time(atX: 900, duration: 60, width: 400) == 60)
        #expect(PlaybackTimelineGeometry.time(atX: 100, duration: 0, width: 400) == 0)
    }

    @Test("the bar of the time reached follows the time, kept within the timeline")
    func playheadPosition() {
        #expect(PlaybackTimelineGeometry.playheadX(time: 30, duration: 60, width: 400) == 200)
        #expect(PlaybackTimelineGeometry.playheadX(time: 90, duration: 60, width: 400) == 400)
        #expect(PlaybackTimelineGeometry.playheadX(time: -1, duration: 60, width: 400) == 0)
        #expect(PlaybackTimelineGeometry.playheadX(time: 5, duration: 0, width: 400) == 0)
    }

    @Test("a line gives its segment its speaker kind and its participant number")
    func segmentOfLine() {
        let participant = Participant(number: 3)
        let me = TimelineSegment(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: ""))
        #expect(me.speakerKind == .me && me.participantNumber == nil)
        let line = TranscriptLine(
            speakerKind: .participant, participant: participant, start: 2, end: 5, text: "")
        let segment = TimelineSegment(line)
        #expect(segment.speakerKind == .participant && segment.participantNumber == 3)
        #expect(segment.start == 2 && segment.end == 5)
    }
}
