import Foundation
import Testing

@testable import LARP

@MainActor
private final class FakeSurfaces: RecordingSurfaces {
    enum Action: Equatable { case showPill, hidePill, showLiveWindow, hideLiveWindow }
    private(set) var actions: [Action] = []
    var onLiveWindowClosed: (@MainActor () -> Void)?

    func showPill() { actions.append(.showPill) }
    func hidePill() { actions.append(.hidePill) }
    func showLiveWindow() { actions.append(.showLiveWindow) }
    func hideLiveWindow() { actions.append(.hideLiveWindow) }

    /// The user closes the window with its own button.
    func userClosesTheWindow() { onLiveWindowClosed?() }
}

/// The `recording-view` machine: exactly one of the pill and the live window during a recording.
@MainActor
struct RecordingViewMachineTests {
    private func makeController() -> (RecordingViewController, FakeSurfaces) {
        let surfaces = FakeSurfaces()
        return (RecordingViewController(state: LiveRecordingState(), surfaces: surfaces), surfaces)
    }

    @Test func theRecordingShowsThePill() {
        let (controller, surfaces) = makeController()
        controller.recordingStarted()
        #expect(controller.phase == .pill)
        #expect(surfaces.actions == [.showPill])
    }

    @Test func thePillOpensTheLiveWindowAndDisappearsWhileItIsOpen() {
        let (controller, surfaces) = makeController()
        controller.recordingStarted()
        controller.openLiveWindow()
        #expect(controller.phase == .liveWindow)
        #expect(surfaces.actions == [.showPill, .hidePill, .showLiveWindow])
    }

    @Test func theLiveWindowOpensOnlyFromThePill() {
        let (controller, surfaces) = makeController()
        controller.openLiveWindow()
        #expect(controller.phase == .hidden)
        controller.recordingStarted()
        controller.openLiveWindow()
        controller.openLiveWindow()
        #expect(surfaces.actions == [.showPill, .hidePill, .showLiveWindow])
    }

    @Test func closingTheWindowBringsThePillBack() {
        let (controller, surfaces) = makeController()
        controller.recordingStarted()
        controller.openLiveWindow()
        surfaces.userClosesTheWindow()
        #expect(controller.phase == .pill)
        #expect(surfaces.actions == [.showPill, .hidePill, .showLiveWindow, .showPill])
    }

    @Test func closingTheWindowFromTheControllerBringsThePillBackToo() {
        let (controller, surfaces) = makeController()
        controller.recordingStarted()
        controller.openLiveWindow()
        controller.closeLiveWindow()
        #expect(controller.phase == .pill)
        #expect(surfaces.actions == [.showPill, .hidePill, .showLiveWindow, .hideLiveWindow, .showPill])
    }

    @Test func endingTheRecordingHidesWhicheverSurfaceIsShown() {
        let (controller, surfaces) = makeController()
        controller.recordingStarted()
        controller.recordingStopped()
        #expect(controller.phase == .hidden)
        #expect(surfaces.actions == [.showPill, .hidePill])

        controller.recordingStarted()
        controller.openLiveWindow()
        controller.recordingStopped()
        #expect(controller.phase == .hidden)
        #expect(surfaces.actions.suffix(4) == [.showPill, .hidePill, .showLiveWindow, .hideLiveWindow])
    }

    @Test func nothingIsShownOutsideARecording() {
        let (controller, surfaces) = makeController()
        controller.recordingStopped()
        controller.closeLiveWindow()
        surfaces.userClosesTheWindow()
        #expect(controller.phase == .hidden)
        #expect(surfaces.actions.isEmpty)
    }

    @Test func thePillIsCentredOnTheScreen24PixelsAboveItsBottomEdge() {
        let visible = NSRect(x: 100, y: 80, width: 1000, height: 700)
        let origin = AppKitRecordingSurfaces.pillOrigin(in: visible)
        #expect(abs(origin.x - (600 - AppKitRecordingSurfaces.pillSize.width / 2)) < 0.001)
        #expect(abs(origin.y - 104) < 0.001)
    }
}

/// What the pill and the live window show while the recording runs.
@MainActor
struct LiveRecordingStateTests {
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var stored = Date(timeIntervalSince1970: 1_800_000_000)
        var date: Date {
            get { lock.withLock { stored } }
            set { lock.withLock { stored = newValue } }
        }
    }

    private func makeCall() -> Call {
        Call(transcriptionLanguage: "it-IT")
    }

    @Test func nothingIsKeptOutsideARecording() {
        let state = LiveRecordingState()
        state.levels(.microphone, TrackLevel(level: 1, isSpeaking: true))
        state.recognised(RecognisedText(speaker: .me, text: "ciao"))
        #expect(state.microphone == .silent)
        #expect(state.recognising == nil)
    }

    @Test func theLevelsOfEachTrackAreKept() {
        let state = LiveRecordingState()
        state.begin(call: makeCall())
        state.levels(.microphone, TrackLevel(level: 0.5, isSpeaking: true))
        state.levels(.system, TrackLevel(level: 0.2, isSpeaking: false))
        #expect(state.microphone == TrackLevel(level: 0.5, isSpeaking: true))
        #expect(state.system == TrackLevel(level: 0.2, isSpeaking: false))
        state.end()
        #expect(state.microphone == .silent && state.system == .silent && state.call == nil)
    }

    @Test func everyRecognisedResultReplacesThePreviousOne() {
        let state = LiveRecordingState()
        state.begin(call: makeCall())
        state.recognised(RecognisedText(speaker: .others, text: "buon"))
        state.recognised(RecognisedText(speaker: .others, text: "buongiorno a tutti"))
        #expect(state.recognising == RecognisedText(speaker: .others, text: "buongiorno a tutti"))
        state.recognised(RecognisedText(speaker: .me, text: "ciao"))
        #expect(state.recognising == RecognisedText(speaker: .me, text: "ciao"))
    }

    @Test func aFinalResultClearsOnlyWhatItsTrackWasRecognising() {
        let state = LiveRecordingState()
        state.begin(call: makeCall())
        state.recognised(RecognisedText(speaker: .me, text: "ciao"))
        state.recognised(RecognisedText(speaker: .others, text: ""))
        #expect(state.recognising == RecognisedText(speaker: .me, text: "ciao"))
        state.recognised(RecognisedText(speaker: .me, text: ""))
        #expect(state.recognising == nil)
    }

    @Test func theWaveformTakesTheLoudestTrackOfEvery50MillisecondsAndEverySecond() {
        let clock = Clock()
        let state = LiveRecordingState(now: { clock.date })
        state.begin(call: makeCall())

        state.levels(.microphone, TrackLevel(level: 0.3, isSpeaking: false))
        state.levels(.system, TrackLevel(level: 0.6, isSpeaking: false))
        clock.date += 0.051
        state.advance()
        #expect(state.recentBars.last == 0.6)
        #expect(state.recentBars.count == LiveRecordingState.pillBarCount)

        // The next bars are quiet; the second closes with the loudest bar.
        clock.date += 0.95
        state.advance()
        #expect(state.secondBars == [0.6])
        #expect(state.recentBars.last == 0)

        clock.date += 1
        state.advance()
        #expect(state.secondBars == [0.6, 0])
    }

    @Test func theWaveformIsFlatAgainAfterTheRecording() {
        let clock = Clock()
        let state = LiveRecordingState(now: { clock.date })
        state.begin(call: makeCall())
        state.levels(.microphone, TrackLevel(level: 1, isSpeaking: true))
        clock.date += 2
        state.advance()
        state.end()
        #expect(state.secondBars.isEmpty)
        #expect(state.recentBars.allSatisfy { $0 == 0 })
    }
}

struct LiveTranscriptRulesTests {
    @Test func aBookmarkMarksTheLineItWasMadeIn() {
        #expect(LiveTranscriptRules.isBookmarked(start: 10.4, end: 14, bookmarkTimes: [12]))
        #expect(LiveTranscriptRules.isBookmarked(start: 10.4, end: 14, bookmarkTimes: [10]))
        #expect(!LiveTranscriptRules.isBookmarked(start: 10.4, end: 14, bookmarkTimes: [14, 9]))
        #expect(!LiveTranscriptRules.isBookmarked(start: 10.4, end: 14, bookmarkTimes: []))
    }

    @Test func aLineShorterThanASecondCanBeMarked() {
        #expect(LiveTranscriptRules.isBookmarked(start: 5.2, end: 5.4, bookmarkTimes: [5]))
    }

    @Test func theLastWordsOfTheRecognisedTextAreSplitOff() {
        let parts = LiveTranscriptRules.splitRecognised("oggi parliamo del piano per il prossimo trimestre")
        #expect(parts.steady == "oggi parliamo del piano per ")
        #expect(parts.tail == "il prossimo trimestre")
    }

    @Test func aShortTextIsAllTail() {
        let parts = LiveTranscriptRules.splitRecognised("buongiorno a tutti")
        #expect(parts.steady.isEmpty)
        #expect(parts.tail == "buongiorno a tutti")
    }

    @Test func thePartsJoinedGiveTheTextAgain() {
        let text = "uno  due tre quattro cinque"
        let parts = LiveTranscriptRules.splitRecognised(text)
        #expect(parts.steady + parts.tail == text)
        #expect(parts.tail == "tre quattro cinque")
    }
}

/// The recorder's pause and the live transcription reach the call machine and the live window.
@Suite("Live recording in the call machine", .serialized, .italianInterface)
@MainActor
struct LiveRecordingLifecycleTests {
    @Test("pausing and resuming tell the capture to write silence and to take the audio again")
    func pauseReachesTheCapture() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: nil))
        await harness.lifecycle.handle(.paused)
        await harness.lifecycle.handle(.resumed)

        #expect(harness.capture.pausedStates == [true, false])
    }

    @Test("a pause outside a recording does nothing")
    func pauseWithoutRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.paused)

        #expect(harness.capture.pausedStates.isEmpty)
    }

    @Test("the live window knows the call being recorded until the recording stops")
    func liveStateFollowsTheRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: "Zoom"))
        let call = try #require(try harness.allCalls().first)
        #expect(harness.live.call === call)

        await harness.lifecycle.handle(.stopped)
        #expect(harness.live.call == nil)
    }

    @Test("the text being recognised comes from the volatile results and is never stored")
    func recognisedText() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let session = FakeLiveSession()
        harness.transcription.set { $0.liveSession = session }

        await harness.lifecycle.handle(.started(callAppName: nil))
        #expect(harness.live.isTranscribing)
        session.emitRecognised(RecognisedText(speaker: .others, text: "buongiorno a"))
        session.emitRecognised(RecognisedText(speaker: .others, text: "buongiorno a tutti"))
        let shown = await harness.eventually { harness.live.recognising?.text == "buongiorno a tutti" }
        #expect(shown)

        session.emit(TranscribedLine(speaker: .others, start: 0, end: 2, text: "Buongiorno a tutti"))
        session.emitRecognised(RecognisedText(speaker: .others, text: ""))
        let cleared = await harness.eventually { harness.live.recognising == nil }
        #expect(cleared)

        await harness.lifecycle.handle(.stopped)
        let call = try #require(try harness.allCalls().first)
        #expect(call.lines.map(\.text) == ["Buongiorno a tutti"])
    }

    @Test("without live transcription the live window says so")
    func noLiveTranscription() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }

        await harness.lifecycle.handle(.started(callAppName: nil))

        #expect(!harness.live.isTranscribing)
    }
}
