import Foundation
import Testing

@testable import LARP

@MainActor
private final class StartRecordingPlayer: TrackPlayer {
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    var speed: Double = 1
    private(set) var starts: [TimeInterval] = []

    init(duration: TimeInterval) { self.duration = duration }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) {
        starts.append(time)
        currentTime = time
    }

    func stop() {}
    func unload() {}
}

@Suite("ActionListing", .italianInterface)
@MainActor
struct ActionListingTests {
    private func makeCall(
        title: String, startedAt: TimeInterval, actions: [SummaryActionItem] = [], opening: String = "",
        participants: [(Int, String)] = []
    ) -> Call {
        let call = Call(
            title: title, startedAt: Date(timeIntervalSince1970: startedAt), duration: 60, transcriptionLanguage: "it-IT",
            state: .ready)
        for (number, name) in participants { call.participants.append(Participant(number: number, name: name)) }
        call.summary = CallSummary(opening: opening, actionItems: actions, language: "it-IT")
        return call
    }

    @Test("calls without a summary or without actions are left out")
    func leavesOutCalls() {
        let with = makeCall(title: "Con", startedAt: 10, actions: [SummaryActionItem(text: "Fare")])
        let without = makeCall(title: "Senza", startedAt: 20)
        let noSummary = Call(title: "Niente", transcriptionLanguage: "it-IT", state: .ready)
        #expect(ActionListing.groups(of: [without, noSummary, with], query: "").map(\.call) == [with])
    }

    @Test("calls are grouped with the most recent first; within a call the not done come first, each in summary order")
    func ordering() {
        let older = makeCall(
            title: "Vecchia", startedAt: 1_000,
            actions: [
                SummaryActionItem(text: "A", isDone: true), SummaryActionItem(text: "B"),
                SummaryActionItem(text: "C", isDone: true), SummaryActionItem(text: "D"),
            ])
        let newer = makeCall(title: "Nuova", startedAt: 5_000, actions: [SummaryActionItem(text: "E")])

        let groups = ActionListing.groups(of: [older, newer], query: "")

        #expect(groups.map(\.call) == [newer, older])
        #expect(groups[1].actions.map(\.text) == ["B", "D", "A", "C"])
        // The index is the place in the summary, which the tick takes.
        #expect(groups[1].actions.map(\.index) == [1, 3, 0, 2])
    }

    @Test("only the actions of the calls that match the search are listed")
    func searchFiltersCalls() {
        let budget = makeCall(title: "Budget", startedAt: 1, actions: [SummaryActionItem(text: "Fare")])
        let other = makeCall(title: "Altro", startedAt: 2, actions: [SummaryActionItem(text: "Fare")])
        #expect(ActionListing.groups(of: [budget, other], query: "budget").map(\.call) == [budget])
        #expect(ActionListing.groups(of: [budget, other], query: "xyz").isEmpty)
    }

    @Test("an owner shows with the current name of the participant, the due as said")
    func ownerAndDue() {
        let call = makeCall(
            title: "Call", startedAt: 1,
            actions: [SummaryActionItem(text: "Inviare", owner: "Partecipante 1", due: "venerdì")],
            participants: [(1, "Anna")])
        let action = ActionListing.groups(of: [call], query: "").first?.actions.first
        #expect(action?.owner == "Anna")
        #expect(action?.due == "venerdì")
        #expect(call.summary?.actionItems.first?.owner == "Partecipante 1")
    }

    @Test("a summary written before this version lists its next steps as actions without due")
    func previousSummary() throws {
        let call = makeCall(title: "Call", startedAt: 1)
        call.summary = CallSummary(actionItems: [SummaryActionItem(text: "Inviare", owner: "Io")], language: "it-IT")
        let actions = try #require(ActionListing.groups(of: [call], query: "").first).actions
        #expect(actions.map(\.due) == [nil])
        #expect(actions.map(\.isDone) == [false])
    }
}

@Suite("CallCard summary", .italianInterface)
@MainActor
struct CallCardSummaryTests {
    @Test("the line is the opening sentence as shown, else the status of the call")
    func summaryLine() {
        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        call.participants.append(Participant(number: 1, name: "Anna"))
        #expect(CallCard.summaryLine(of: call, status: "Rifinitura…") == "Rifinitura…")
        #expect(CallCard.summaryLine(of: call, status: nil) == "")
        call.summary = CallSummary(keyConcepts: ["Budget"], language: "it-IT")
        #expect(CallCard.summaryLine(of: call, status: "Sintesi…") == "Sintesi…")
        call.summary = CallSummary(opening: "Partecipante 1 apre.", openingHighlight: "apre", language: "it-IT")
        #expect(CallCard.summaryLine(of: call, status: "Sintesi…") == "Anna apre.")
    }

    @Test("the chip counts the actions not done, singular and plural, in both languages")
    func chipText() {
        #expect(CallCard.actionsChipText(1, language: .italian) == "1 azione")
        #expect(CallCard.actionsChipText(3, language: .italian) == "3 azioni")
        #expect(CallCard.actionsChipText(1, language: .english) == "1 action")
        #expect(CallCard.actionsChipText(2, language: .english) == "2 actions")
    }

    @Test("only the actions not done are counted")
    func openActionCount() {
        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        call.summary = CallSummary(
            actionItems: [
                SummaryActionItem(text: "A"), SummaryActionItem(text: "B", isDone: true), SummaryActionItem(text: "C"),
            ], language: "it-IT")
        #expect(SummaryContent(call: call)?.openActionCount == 2)
        call.summary = CallSummary(language: "it-IT")
        #expect(SummaryContent(call: call)?.openActionCount == 0)
    }
}

@Suite("PlaybackSelectDecision")
@MainActor
struct PlaybackSelectDecisionTests {
    private func makeController(duration: TimeInterval = 60) -> (PlaybackController, StartRecordingPlayer) {
        let player = StartRecordingPlayer(duration: duration)
        return (PlaybackController(makePlayer: { _ in player }), player)
    }

    private func makeCall() -> Call {
        Call(duration: 60, transcriptionLanguage: "it-IT", state: .ready)
    }

    @Test("from Stopped, Playing and Paused it plays from the start of the line of the decision")
    func fromEveryState() {
        let (controller, player) = makeController()
        controller.show(makeCall())

        controller.selectDecision(lineStart: 12)
        #expect(controller.state == .playing)

        controller.selectDecision(lineStart: 20)
        #expect(controller.state == .playing)

        controller.pause()
        controller.selectDecision(lineStart: 31)
        #expect(controller.state == .playing)
        #expect(player.starts == [12, 20, 31])
    }

    @Test("a call without audio to play stays Stopped")
    func withoutAudio() {
        let (controller, player) = makeController(duration: 0)
        controller.show(makeCall())

        controller.selectDecision(lineStart: 5)

        #expect(controller.state == .stopped)
        #expect(player.starts.isEmpty)
    }
}

@Suite("MainWindowActions")
@MainActor
struct MainWindowActionsTests {
    private func makeModel() -> MainWindowModel {
        MainWindowModel(playback: PlaybackController(makePlayer: { _ in StartRecordingPlayer(duration: 60) }))
    }

    @Test("user.SHOW_ACTIONS_VIEW shows the actions and keeps the search")
    func showActions() {
        let model = makeModel()
        model.searchText = "budget"
        model.showActionsView()
        #expect(model.libraryView == .actions)
        #expect(model.page == .library)
        #expect(model.searchText == "budget")
        model.showAllCalls()
        #expect(model.libraryView == .allCalls)
    }

    @Test("user.SHOW_ACTIONS_VIEW from the page of a call goes back to the library on the actions")
    func fromCallPage() {
        let model = makeModel()
        model.selectCall(UUID())
        model.showActionsView()
        #expect(model.page == .library)
        #expect(model.libraryView == .actions)
    }

    @Test("a call opened from the actions opens on its summary and the library comes back on the actions")
    func selectCallFromActions() {
        let model = makeModel()
        let id = UUID()
        model.showActionsView()
        model.showTab(.notes)

        model.selectCall(id)

        #expect(model.page == .call(id))
        #expect(model.callTab == .summary)
        model.showLibrary()
        #expect(model.libraryView == .actions)
    }

    @Test("closing the window brings the library back on all calls")
    func windowClosed() {
        let model = makeModel()
        model.showActionsView()
        model.windowClosed()
        #expect(model.libraryView == .allCalls)
    }
}
