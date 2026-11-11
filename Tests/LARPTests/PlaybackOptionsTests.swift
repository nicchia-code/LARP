import Foundation
import Testing

@testable import LARP

@MainActor
private final class OptionsPlayer: TrackPlayer {
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var speed: Double = 1
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    private(set) var starts: [TimeInterval] = []
    private var onFinished: (@MainActor () -> Void)?

    init(duration: TimeInterval) { self.duration = duration }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) {
        starts.append(time)
        currentTime = time
        self.onFinished = onFinished
    }

    func stop() { onFinished = nil }
    func unload() { onFinished = nil }
}

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

/// The machine `playback-options`: what is saved, and how the speed is shown.
@Suite("Playback options", .serialized)
@MainActor
struct PlaybackOptionsTests {
    @Test("the app starts at 1× without skipping")
    func defaults() {
        let options = PlaybackOptions(defaults: makeDefaults())
        #expect(options.speed == 1)
        #expect(!options.skipSilence)
    }

    @Test("every click goes through 1×, 1,25×, 1,5×, 2× and 0,75×, then 1× again")
    func speedOrder() {
        let options = PlaybackOptions(defaults: makeDefaults())
        var seen: [Double] = []
        for _ in 0..<6 {
            options.changeSpeed()
            seen.append(options.speed)
        }
        #expect(seen == [1.25, 1.5, 2, 0.75, 1, 1.25])
    }

    @Test("the speed and the skipping are kept across launches")
    func kept() {
        let defaults = makeDefaults()
        let options = PlaybackOptions(defaults: defaults)
        options.changeSpeed()
        options.changeSpeed()
        options.setSkipSilence(true)
        #expect(defaults.double(forKey: SettingsKey.playbackSpeed) == 1.5)
        #expect(defaults.bool(forKey: SettingsKey.playbackSkipSilence))

        let relaunched = PlaybackOptions(defaults: defaults)
        #expect(relaunched.speed == 1.5)
        #expect(relaunched.skipSilence)

        relaunched.setSkipSilence(false)
        #expect(!PlaybackOptions(defaults: defaults).skipSilence)
    }

    @Test("a speed that is not one of the five reads as 1")
    func unknownSpeedReadsAsOne() {
        let defaults = makeDefaults()
        defaults.set(3.0, forKey: SettingsKey.playbackSpeed)
        #expect(PlaybackOptions(defaults: defaults).speed == 1)
        defaults.set(0.5, forKey: SettingsKey.playbackSpeed)
        #expect(PlaybackOptions(defaults: defaults).speed == 1)
    }

    @Test("the chip shows the speed with the decimal separator of the language")
    func label() {
        #expect(PlaybackOptions.label(for: 1, language: .italian) == "1,0×")
        #expect(PlaybackOptions.label(for: 1.25, language: .italian) == "1,25×")
        #expect(PlaybackOptions.label(for: 1.5, language: .italian) == "1,5×")
        #expect(PlaybackOptions.label(for: 2, language: .italian) == "2,0×")
        #expect(PlaybackOptions.label(for: 0.75, language: .italian) == "0,75×")
        #expect(PlaybackOptions.label(for: 1.25, language: .english) == "1.25×")
    }
}

/// Skipping the stretches without lines.
@Suite("Skip silence", .serialized)
@MainActor
struct SkipSilenceTests {
    private let timeline = TranscriptTimeline(spans: [
        LineTiming(start: 5, end: 8), LineTiming(start: 8.5, end: 20), LineTiming(start: 21, end: 30),
        LineTiming(start: 40, end: 50),
    ])
    private let lead = TranscriptTimeline.silenceLeadIn

    @Test("a stretch longer than 2 seconds jumps to 0.3 seconds before the next line")
    func jumpsToTheNextLine() {
        // Before the first line, from the start of the audio.
        #expect(timeline.silenceSkip(at: 0, duration: 100) == .seek(to: 5 - lead))
        #expect(timeline.silenceSkip(at: 2, duration: 100) == .seek(to: 5 - lead))
        // Between two lines.
        #expect(timeline.silenceSkip(at: 31, duration: 100) == .seek(to: 40 - lead))
    }

    @Test("a short stretch, or a time in a line, is left as it is")
    func leavesShortStretches() {
        #expect(timeline.silenceSkip(at: 8.2, duration: 100) == nil)
        #expect(timeline.silenceSkip(at: 20.5, duration: 100) == nil)
        #expect(timeline.silenceSkip(at: 6, duration: 100) == nil)
        // The end of a line belongs to what follows.
        #expect(timeline.silenceSkip(at: 30, duration: 100) == .seek(to: 40 - lead))
    }

    @Test("a stretch of exactly 2 seconds is not skipped")
    func exactlyTwoSeconds() {
        let timeline = TranscriptTimeline(spans: [LineTiming(start: 0, end: 4), LineTiming(start: 6, end: 9)])
        #expect(timeline.silenceSkip(at: 5, duration: 20) == nil)
    }

    @Test("after the last line the audio ends, when the rest is longer than 2 seconds")
    func endsAfterTheLastLine() {
        #expect(timeline.silenceSkip(at: 51, duration: 100) == .end)
        #expect(timeline.silenceSkip(at: 51, duration: 52) == nil)
    }

    @Test("a jump never goes back, inside the last 0.3 seconds before a line")
    func neverGoesBack() {
        #expect(timeline.silenceSkip(at: 39.8, duration: 100) == nil)
        #expect(timeline.silenceSkip(at: 40 - lead, duration: 100) == nil)
    }

    @Test("overlapping lines count as one stretch of speech")
    func overlappingLines() {
        let timeline = TranscriptTimeline(spans: [LineTiming(start: 0, end: 30), LineTiming(start: 5, end: 10)])
        #expect(timeline.silenceSkip(at: 31, duration: 100) == .end)
        #expect(timeline.silenceSkip(at: 12, duration: 100) == nil)
    }

    @Test("without lines the whole audio is one stretch")
    func noLines() {
        #expect(TranscriptTimeline.empty.silenceSkip(at: 0, duration: 60) == .end)
        #expect(TranscriptTimeline.empty.silenceSkip(at: 0, duration: 1.5) == nil)
    }

    // MARK: In the controller

    private func makeController(
        skipping: Bool, duration: TimeInterval = 100
    ) -> (PlaybackController, OptionsPlayer, PlaybackOptions) {
        let options = PlaybackOptions(defaults: makeDefaults())
        options.setSkipSilence(skipping)
        let player = OptionsPlayer(duration: duration)
        let controller = PlaybackController(
            options: options, tickInterval: .milliseconds(10), makePlayer: { _ in player })
        controller.show(Call(duration: duration, transcriptionLanguage: "it-IT", state: .ready))
        controller.setTimeline([
            LineTiming(start: 5, end: 8), LineTiming(start: 8.5, end: 20), LineTiming(start: 40, end: 50),
        ])
        return (controller, player, options)
    }

    private func waitUntil(_ condition: @MainActor () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
        for _ in 0..<400 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
        Issue.record("Condition not reached in time", sourceLocation: sourceLocation)
    }

    @Test("while playing with skipping on, a silence is jumped with a seek and the time shows it")
    func skipsWhilePlaying() async {
        let (controller, player, _) = makeController(skipping: true)
        controller.play(fromSentenceStart: 25)
        await waitUntil { player.starts.count == 2 }
        #expect(player.starts == [25, 40 - lead])
        #expect(controller.state == .playing)
        #expect(controller.currentTime == 40 - lead)
        controller.stop()
    }

    @Test("the start of the audio is skipped too")
    func skipsTheBeginning() async {
        let (controller, player, _) = makeController(skipping: true)
        controller.play()
        await waitUntil { player.starts.count == 2 }
        #expect(player.starts == [0, 5 - lead])
        controller.stop()
    }

    @Test("with skipping off nothing is jumped")
    func notSkipping() async {
        let (controller, player, _) = makeController(skipping: false)
        controller.play(fromSentenceStart: 25)
        player.currentTime = 26
        await waitUntil { controller.currentTime == 26 }
        try? await Task.sleep(for: .milliseconds(50))
        #expect(player.starts == [25])
        controller.stop()
    }

    @Test("after the last line the playback ends")
    func endsWhenNoLineIsLeft() async {
        let (controller, player, _) = makeController(skipping: true)
        controller.play(fromSentenceStart: 60)
        await waitUntil { controller.state == .stopped }
        #expect(controller.state == .stopped)
        #expect(controller.currentTime == 0)
        #expect(player.starts == [60])
    }

    @Test("turning skipping on while playing applies at the next tick")
    func turningOnWhilePlaying() async {
        let (controller, player, options) = makeController(skipping: false)
        controller.play(fromSentenceStart: 25)
        options.setSkipSilence(true)
        await waitUntil { player.starts.count == 2 }
        #expect(player.starts == [25, 40 - lead])
        controller.stop()
    }

    @Test("the speed applies at once to the player, and to the next call shown")
    func speedReachesThePlayer() {
        let (controller, player, options) = makeController(skipping: false)
        #expect(player.speed == 1)
        controller.changeSpeed()
        #expect(options.speed == 1.25)
        #expect(player.speed == 1.25)
        controller.changeSpeed()
        #expect(player.speed == 1.5)

        let next = OptionsPlayer(duration: 30)
        let other = PlaybackController(options: options, makePlayer: { _ in next })
        other.show(Call(duration: 30, transcriptionLanguage: "it-IT", state: .ready))
        #expect(next.speed == 1.5)
    }

    @Test("the time reached stays in the time of the audio at every speed")
    func timeStaysInAudioTime() {
        let (controller, player, _) = makeController(skipping: false)
        controller.changeSpeed()
        controller.play(fromSentenceStart: 10)
        player.currentTime = 12.5
        controller.pause()
        #expect(controller.currentTime == 12.5)
        #expect(controller.duration == 100)
    }
}
