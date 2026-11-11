import Foundation
import Testing

@testable import LARP

@MainActor
private final class SilentPlayer: TrackPlayer {
    var duration: TimeInterval = 60
    var currentTime: TimeInterval = 0
    private(set) var unloads = 0
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    var speed: Double = 1
    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) { currentTime = time }
    func stop() {}
    func unload() { unloads += 1 }
}

@Suite("Main window", .italianInterface)
@MainActor
struct MainWindowTests {
    @MainActor private struct Fixture {
        let player = SilentPlayer()
        let playback: PlaybackController
        let model: MainWindowModel

        init() {
            let player = player
            playback = PlaybackController(makePlayer: { _ in player })
            model = MainWindowModel(playback: playback)
        }
    }

    private func makeCall(id: UUID = UUID()) -> Call {
        Call(id: id, transcriptionLanguage: "it-IT", state: .ready)
    }

    // MARK: Pages

    @Test("the window opens on the library")
    func opensOnTheLibrary() {
        let f = Fixture()
        #expect(f.model.page == .library)
        f.model.showSettings()
        f.model.windowOpened()
        #expect(f.model.page == .library)
    }

    @Test("user.SELECT_CALL opens the page of the call and user.DESELECT_CALL goes back to the library, unloading the audio")
    func selectAndDeselect() {
        let f = Fixture()
        let call = makeCall()
        f.model.selectCall(call.id)
        #expect(f.model.page == .call(call.id))
        #expect(f.model.shownCallID == call.id)
        // The page of the call loads its audio.
        f.playback.show(call)
        #expect(f.playback.callID == call.id)
        f.model.showLibrary()
        #expect(f.model.page == .library)
        #expect(f.playback.callID == nil)
        #expect(f.player.unloads == 1)
    }

    @Test("the search stays when a call is opened and the library comes back")
    func searchStays() {
        let f = Fixture()
        f.model.searchText = "budget"
        f.model.selectCall(UUID())
        f.model.showLibrary()
        #expect(f.model.searchText == "budget")
    }

    @Test("user.OPEN_SETTINGS leaves the page shown and unloads the audio; user.CLOSE_SETTINGS goes back to the library")
    func settings() {
        let f = Fixture()
        let call = makeCall()
        f.model.selectCall(call.id)
        f.playback.show(call)
        f.model.showSettings()
        #expect(f.model.page == .settings)
        #expect(f.playback.callID == nil)
        f.model.closeSettings()
        #expect(f.model.page == .library)
    }

    @Test("call.DELETED brings the library back only when the call shown is the deleted one")
    func callDeleted() {
        let f = Fixture()
        let call = makeCall()
        let other = makeCall()
        f.model.selectCall(call.id)
        f.playback.show(call)
        f.model.callDeleted(other.id)
        #expect(f.model.page == .call(call.id))
        f.model.callDeleted(call.id)
        #expect(f.model.page == .library)
        #expect(f.playback.callID == nil)
    }

    @Test("user.CLOSE_WINDOW stops the playback and the next opening shows the library")
    func closeWindow() {
        let f = Fixture()
        let call = makeCall()
        f.model.selectCall(call.id)
        f.playback.show(call)
        f.playback.play()
        #expect(f.playback.state == .playing)
        f.model.windowClosed()
        #expect(f.playback.state == .stopped)
        #expect(f.playback.callID == nil)
        #expect(f.model.page == .library)
    }

    // MARK: Cards

    @Test("a card shows the opening sentence of the summary, else the status")
    func cardSummaryLine() {
        let call = makeCall()
        #expect(CallCard.summaryLine(of: call, status: "Trascrizione…", language: .italian) == "Trascrizione…")
        #expect(CallCard.summaryLine(of: call, status: nil, language: .italian) == "")
        call.summary = CallSummary(opening: "Partecipante 1 apre.", keyConcepts: ["Altro"], decisionItems: [SummaryDecision(text: "Sì")], language: "it-IT")
        call.participants.append(Participant(number: 1, name: "Anna"))
        #expect(CallCard.summaryLine(of: call, status: "Sintesi…", language: .italian) == "Anna apre.")
        call.summary = CallSummary(keyConcepts: ["Altro"], decisionItems: [SummaryDecision(text: "Sì")], language: "it-IT")
        #expect(CallCard.summaryLine(of: call, status: "Sintesi…", language: .italian) == "Sintesi…")
    }

    // MARK: Speakers

    @Test("speakers are ordered by their share of the speaking time, whole percentages rounded to the nearest")
    func speakerShares() {
        let call = makeCall()
        let anna = Participant(number: 1, name: "Anna")
        let second = Participant(number: 2)
        call.participants = [anna, second]
        call.lines = [
            TranscriptLine(speakerKind: .me, start: 0, end: 14, text: "a"),
            TranscriptLine(speakerKind: .participant, participant: anna, start: 14, end: 52, text: "b"),
            TranscriptLine(speakerKind: .participant, participant: second, start: 52, end: 79, text: "c"),
            TranscriptLine(speakerKind: .participant, participant: second, start: 80, end: 81, text: "d"),
        ]
        let speakers = CallSpeakers.speakers(of: call, language: .italian)
        #expect(speakers.map(\.name) == ["Anna", "Partecipante 2", "Io"])
        #expect(speakers.map(\.percent) == [48, 35, 18])
        #expect(speakers.map(\.initial) == ["A", "2", "I"])
        #expect(speakers.map(\.participantNumber) == [1, 2, nil])
    }

    @Test("Io has a chip only when it has lines, and the others as a whole while they are not told apart")
    func speakerChips() {
        let call = makeCall()
        #expect(CallSpeakers.speakers(of: call).isEmpty)
        call.lines = [TranscriptLine(speakerKind: .others, start: 0, end: 10, text: "a")]
        #expect(CallSpeakers.speakers(of: call, language: .english).map(\.name) == ["Others"])
        call.lines.append(TranscriptLine(speakerKind: .me, start: 10, end: 20, text: "b"))
        let speakers = CallSpeakers.speakers(of: call, language: .english)
        #expect(speakers.map(\.name) == ["Me", "Others"])
        #expect(speakers.map(\.percent) == [50, 50])
    }
}
