import Foundation
import Testing

@testable import LARP

@MainActor
private final class FakePlayer: TrackPlayer {
    var duration: TimeInterval
    var currentTime: TimeInterval = 0
    private(set) var starts: [TimeInterval] = []
    private(set) var stops = 0
    private(set) var unloads = 0
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    private var onFinished: (@MainActor () -> Void)?

    init(duration: TimeInterval) {
        self.duration = duration
    }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) {
        starts.append(time)
        currentTime = time
        self.onFinished = onFinished
    }

    func stop() {
        stops += 1
        onFinished = nil
    }

    func unload() {
        unloads += 1
        onFinished = nil
        onInterrupted = nil
    }

    func finish() {
        let callback = onFinished
        onFinished = nil
        callback?()
    }
}

@MainActor
private func waitUntil(
    _ condition: @MainActor () -> Bool, sourceLocation: SourceLocation = #_sourceLocation
) async {
    for _ in 0..<400 {
        if condition() { return }
        try? await Task.sleep(for: .milliseconds(5))
    }
    Issue.record("Condition not reached in time", sourceLocation: sourceLocation)
}

@Suite("PlaybackController")
@MainActor
struct PlaybackControllerTests {
    private func makeCall(state: CallState = .ready) -> Call {
        Call(duration: 60, transcriptionLanguage: "it-IT", state: state)
    }

    private func makeController(duration: TimeInterval = 60) -> (PlaybackController, FakePlayer) {
        let player = FakePlayer(duration: duration)
        let controller = PlaybackController(makePlayer: { _ in player })
        return (controller, player)
    }

    @Test("it starts Stopped, with the duration of the audio")
    func initialState() {
        let (controller, _) = makeController()
        controller.show(makeCall())
        #expect(controller.state == .stopped)
        #expect(controller.canPlay)
        #expect(controller.duration == 60)
    }

    @Test("Play from Stopped plays from the beginning")
    func playFromStopped() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.play()
        #expect(controller.state == .playing)
        #expect(player.starts == [0])
    }

    @Test("Pause holds the time; Play resumes from there")
    func pauseAndResume() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.play()
        player.currentTime = 12.5
        controller.pause()
        #expect(controller.state == .paused)
        #expect(controller.currentTime == 12.5)
        controller.play()
        #expect(controller.state == .playing)
        #expect(player.starts == [0, 12.5])
    }

    @Test("clicking a sentence plays from its start, from every state")
    func selectSentence() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.setTimeline([LineTiming(start: 0, end: 5), LineTiming(start: 5, end: 9), LineTiming(start: 20, end: 30)])

        controller.play(fromSentenceStart: 5)
        #expect(controller.state == .playing)
        #expect(controller.currentLineIndex == 1)

        controller.play(fromSentenceStart: 20)
        #expect(controller.state == .playing)
        #expect(controller.currentLineIndex == 2)

        controller.pause()
        controller.play(fromSentenceStart: 0)
        #expect(controller.state == .playing)
        #expect(controller.currentLineIndex == 0)
        #expect(player.starts == [5, 20, 0])
    }

    @Test("the end of the audio leads to Stopped")
    func playbackEnded() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.play()
        player.finish()
        #expect(controller.state == .stopped)
        #expect(controller.currentTime == 0)
        #expect(controller.currentLineIndex == nil)
    }

    @Test("showing another call, no call or stopping leads to Stopped")
    func leavingTheCall() {
        let (controller, _) = makeController()
        let call = makeCall()
        controller.show(call)
        controller.play()
        controller.show(makeCall())
        #expect(controller.state == .stopped)

        controller.play()
        controller.show(nil)
        #expect(controller.state == .stopped)
        #expect(!controller.canPlay)

        controller.show(call)
        controller.play()
        controller.pause()
        controller.stop()
        #expect(controller.state == .stopped)
    }

    @Test("showing the call being played again does not stop it")
    func showingSameCallKeepsPlaying() {
        let (controller, _) = makeController()
        let call = makeCall()
        controller.show(call)
        controller.play()
        controller.show(call)
        #expect(controller.state == .playing)
    }

    @Test("seeking restarts the audio while Playing, moves the time while Paused and does nothing while Stopped")
    func seeking() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.seek(to: 30)
        #expect(controller.state == .stopped)
        #expect(player.starts.isEmpty)

        controller.play()
        controller.seek(to: 30)
        #expect(controller.state == .playing)
        #expect(player.starts == [0, 30])

        controller.pause()
        controller.seek(to: 45)
        #expect(controller.state == .paused)
        #expect(controller.currentTime == 45)
        controller.play()
        #expect(player.starts == [0, 30, 45])

        controller.seek(to: 500)
        #expect(player.starts.last == 60)
    }

    @Test("a call without readable audio cannot be played")
    func noAudio() {
        let (controller, player) = makeController(duration: 0)
        controller.show(makeCall())
        controller.play()
        controller.play(fromSentenceStart: 3)
        #expect(!controller.canPlay)
        #expect(controller.state == .stopped)
        #expect(player.starts.isEmpty)
    }

    @Test("a call being recorded has no audio to play until it ends")
    func recordingCall() {
        let (controller, _) = makeController()
        let call = makeCall(state: .recording)
        controller.show(call)
        controller.play()
        #expect(!controller.canPlay)
        #expect(controller.state == .stopped)

        call.state = .transcribing
        controller.show(call)
        #expect(controller.canPlay)
    }

    @Test("when the audio cannot play on the new output, Playing becomes Paused at the time reached")
    func outputChangeInterruptsPlayback() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.setTimeline([LineTiming(start: 0, end: 5), LineTiming(start: 5, end: 9)])
        controller.play()

        player.onInterrupted?(7)
        #expect(controller.state == .paused)
        #expect(controller.currentTime == 7)
        #expect(controller.currentLineIndex == 1)

        controller.play()
        #expect(controller.state == .playing)
        #expect(player.starts == [0, 7])
    }

    @Test("an interruption does not change Paused or Stopped")
    func outputChangeWhileNotPlaying() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        player.onInterrupted?(7)
        #expect(controller.state == .stopped)
        #expect(controller.currentTime == 0)

        controller.play()
        player.currentTime = 3
        controller.pause()
        player.onInterrupted?(9)
        #expect(controller.state == .paused)
        #expect(controller.currentTime == 3)
    }

    @Test("showing another call or none unloads the player")
    func unloadsThePlayer() {
        let (controller, player) = makeController()
        controller.show(makeCall())
        controller.show(nil)
        #expect(player.unloads == 1)
    }

    @Test("the line being heard follows the time of the audio")
    func currentLineFollowsAudio() async throws {
        let player = FakePlayer(duration: 60)
        let controller = PlaybackController(tickInterval: .milliseconds(10), makePlayer: { _ in player })
        controller.show(makeCall())
        controller.setTimeline([LineTiming(start: 0, end: 5), LineTiming(start: 5, end: 9)])
        controller.play()
        #expect(controller.currentLineIndex == 0)

        player.currentTime = 6
        await waitUntil { controller.currentTime == 6 }
        #expect(controller.currentLineIndex == 1)
        #expect(controller.currentTime == 6)
        controller.stop()
    }
}
