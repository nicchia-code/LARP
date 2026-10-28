import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

/// A refiner whose answer the test controls.
private final class FakeRefiner: TranscriptRefining {
    typealias Behavior = @Sendable (String) async throws -> String

    private struct State {
        var prompts: [String] = []
        var cancellations = 0
        var behavior: Behavior
    }

    private let state: Mutex<State>

    init(_ behavior: @escaping Behavior = { _ in "[]" }) {
        state = Mutex(State(behavior: behavior))
    }

    var prompts: [String] { state.withLock { $0.prompts } }
    var cancellations: Int { state.withLock { $0.cancellations } }

    func setBehavior(_ behavior: @escaping Behavior) {
        state.withLock { $0.behavior = behavior }
    }

    /// Never answers; ends with the cancellation of the task.
    static let hangs: Behavior = { _ in
        try await Task.sleep(for: .seconds(60))
        return ""
    }

    @concurrent
    func refine(prompt: String) async throws -> String {
        let behavior = state.withLock { state -> Behavior in
            state.prompts.append(prompt)
            return state.behavior
        }
        do {
            return try await behavior(prompt)
        } catch {
            if Task.isCancelled { state.withLock { $0.cancellations += 1 } }
            throw error
        }
    }
}

private struct AssistantFailure: Error {}

/// The answer of an assistant that corrects `text` of each line given as `(number, text, speaker)`.
private func answer(_ corrections: [(Int, String, String)]) -> String {
    let rows = corrections.map { #"{"number": \#($0.0), "text": "\#($0.1)", "speaker": "\#($0.2)"}"# }
    return "[" + rows.joined(separator: ",") + "]"
}

/// A call with a line of "Me" and lines of two participants, one of them renamed by the user.
@MainActor
private func addLines(to call: Call, in context: ModelContext) {
    let anna = Participant(number: 1, name: "Anna Rossi")
    let two = Participant(number: 2)
    call.participants.append(anna)
    call.participants.append(two)
    call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno a tutti"))
    call.lines.append(TranscriptLine(speakerKind: .participant, participant: anna, start: 2.5, end: 4, text: "Il meeting e' alle tre"))
    call.lines.append(TranscriptLine(speakerKind: .participant, participant: two, start: 5, end: 7, text: "Va bene"))
}

private let validAnswer = answer([
    (1, "Buongiorno a tutti", "Io"),
    (2, "Il meeting è alle tre", "Partecipante 1"),
    (3, "Va bene, grazie", "Partecipante 1"),
])

private func texts(_ call: Call) -> [String] { call.sortedLines.map(\.text) }
private func speakers(_ call: Call) -> [String] { call.sortedLines.map(\.speakerName) }

@Suite("call machine: transcript refinement")
struct RefinementTransitionTests {
    @Test("Separating participants → Ready or Refining transcript by the refinement switch")
    func separated() {
        #expect(
            CallStateMachine.target(from: .separatingParticipants, on: .participantsSeparated(refinementOn: false))
                == .state(.ready))
        #expect(
            CallStateMachine.target(from: .separatingParticipants, on: .participantsSeparated(refinementOn: true))
                == .state(.refiningTranscript))
    }

    @Test("Refining transcript")
    func refining() {
        let state = CallState.refiningTranscript
        #expect(CallStateMachine.target(from: state, on: .transcriptRefined) == .state(.ready))
        #expect(CallStateMachine.target(from: state, on: .refinementFailed) == .state(.awaitingRefinementRetry))
        #expect(CallStateMachine.target(from: state, on: .turnOffRefinement) == .state(.ready))
        #expect(CallStateMachine.target(from: state, on: .appLaunched(languageReady: true)) == .state(.refiningTranscript))
        #expect(CallStateMachine.target(from: state, on: .renameCall) == .state(.refiningTranscript))
        #expect(CallStateMachine.target(from: state, on: .deleteCall) == .deleted)
        #expect(CallStateMachine.target(from: state, on: .renameParticipant) == nil)
        #expect(CallStateMachine.target(from: state, on: .refineTranscript(refinementOn: true)) == nil)
        #expect(CallStateMachine.target(from: state, on: .networkAvailable) == nil)
    }

    @Test("Awaiting refinement retry")
    func awaitingRetry() {
        let state = CallState.awaitingRefinementRetry
        #expect(CallStateMachine.target(from: state, on: .networkAvailable) == .state(.refiningTranscript))
        #expect(CallStateMachine.target(from: state, on: .appLaunched(languageReady: false)) == .state(.refiningTranscript))
        #expect(CallStateMachine.target(from: state, on: .refineTranscript(refinementOn: true)) == .state(.refiningTranscript))
        #expect(CallStateMachine.target(from: state, on: .turnOffRefinement) == .state(.ready))
        #expect(CallStateMachine.target(from: state, on: .renameCall) == .state(state))
        #expect(CallStateMachine.target(from: state, on: .deleteCall) == .deleted)
        #expect(CallStateMachine.target(from: state, on: .renameParticipant) == nil)
    }

    @Test("Ready: refine only when refinement is on, restore only when refined")
    func ready() {
        #expect(CallStateMachine.target(from: .ready, on: .refineTranscript(refinementOn: true)) == .state(.refiningTranscript))
        #expect(CallStateMachine.target(from: .ready, on: .refineTranscript(refinementOn: false)) == nil)
        #expect(CallStateMachine.target(from: .ready, on: .restoreTranscript(refined: true)) == .state(.ready))
        #expect(CallStateMachine.target(from: .ready, on: .restoreTranscript(refined: false)) == nil)
    }

    @Test("the states have their labels in the list")
    func labels() {
        #expect(CallState.refiningTranscript.statusLabel == "Rifinitura testo…")
        #expect(CallState.awaitingRefinementRetry.statusLabel == "Testo da rifinire")
    }
}

@Suite("RefinementRequest")
@MainActor
struct RefinementRequestTests {
    private let container: ModelContainer

    init() throws {
        container = try ArchiveStore.makeContainer(inMemory: true)
    }

    private func makeCall() -> Call {
        let call = Call(title: "Riunione segreta", callAppName: "Zoom", transcriptionLanguage: "it-IT", state: .refiningTranscript)
        container.mainContext.insert(call)
        addLines(to: call, in: container.mainContext)
        return call
    }

    @Test("sends numbered lines in order of start with original speakers and times, as JSON after fixed instructions")
    func prompt() throws {
        let call = makeCall()
        // Lines added out of order are still numbered by start time.
        call.lines.append(TranscriptLine(speakerKind: .me, start: 1, end: 2.25, text: "Una \"riga\" con / barra"))

        let prompt = try #require(RefinementRequest(call: call)).prompt

        #expect(prompt.hasPrefix(RefinementRequest.instructions))
        let json = try #require(prompt.range(of: "\n\n[\n").map { String(prompt[$0.lowerBound...]) })
        let rows = try #require(
            JSONSerialization.jsonObject(with: Data(json.utf8)) as? [[String: Any]])
        #expect(rows.map { $0["number"] as? Int } == [1, 2, 3, 4])
        #expect(rows.map { $0["speaker"] as? String } == ["Io", "Io", "Partecipante 1", "Partecipante 2"])
        #expect(rows.map { $0["start"] as? Double } == [0, 1, 2.5, 5])
        #expect(rows.map { $0["end"] as? Double } == [2, 2.25, 4, 7])
        #expect(rows[1]["text"] as? String == "Una \"riga\" con / barra")
        #expect(rows.allSatisfy { Set($0.keys) == ["number", "speaker", "start", "end", "text"] })
    }

    @Test("never sends the title, the names given by the user, the dates or the app of the call")
    func sendsNothingElse() throws {
        let call = makeCall()
        let prompt = try #require(RefinementRequest(call: call)).prompt
        for secret in ["Riunione segreta", "Anna", "Rossi", "Zoom", String(Calendar.current.component(.year, from: call.startedAt))] {
            #expect(!prompt.contains(secret), "\(secret)")
        }
    }

    @Test("a refined call is sent with its original text and speakers")
    func originalsAreSent() throws {
        let call = makeCall()
        let lines = call.sortedLines
        lines[1].originalText = "Il meeting e' alle tre"
        lines[1].originalSpeakerKind = .participant
        lines[1].originalParticipantNumber = 2
        lines[1].text = "Corretto"
        lines[1].participant = call.participants.first { $0.number == 1 }

        let request = try #require(RefinementRequest(call: call))

        #expect(request.lines[1].speaker == .participant(2))
        #expect(request.lines[1].text == "Il meeting e' alle tre")
    }

    @Test("a line of the others without participant is never sent as \"Altri\": there is no request")
    func lineWithoutParticipantIsNotSent() {
        let call = makeCall()
        call.sortedLines[1].speakerKind = .others
        call.sortedLines[1].participant = nil

        #expect(RefinementRequest(call: call) == nil)
        #expect(RefinementSpeaker(label: "Altri") == nil)
    }

    private let request = RefinementRequest(lines: [
        RefinementLine(number: 1, speaker: .me, start: 0, end: 1, text: "a"),
        RefinementLine(number: 2, speaker: .participant(1), start: 1, end: 2, text: "b"),
        RefinementLine(number: 3, speaker: .participant(2), start: 2, end: 3, text: "c"),
    ])

    @Test("a valid answer gives one correction per line, also inside a code block and in any order")
    func validAnswers() {
        let corrections = request.corrections(from: "```json\n" + answer([(3, " C ", "Partecipante 1"), (1, "A", "Io"), (2, "B", "Partecipante 2")]) + "\n```")
        #expect(corrections?.map(\.number) == [1, 2, 3])
        #expect(corrections?.map(\.text) == ["A", "B", "C"])
        #expect(corrections?.map(\.speaker) == [.me, .participant(2), .participant(1)])
    }

    @Test(
        "an answer that does not match the lines sent is not valid",
        arguments: [
            "non è JSON",
            "[]",
            #"{"number": 1}"#,
            // one line missing
            answer([(1, "A", "Io"), (2, "B", "Partecipante 1")]),
            // one line more
            answer([(1, "A", "Io"), (2, "B", "Partecipante 1"), (3, "C", "Partecipante 2"), (4, "D", "Io")]),
            // a number twice
            answer([(1, "A", "Io"), (2, "B", "Partecipante 1"), (2, "C", "Partecipante 2")]),
            // a number that was not sent
            answer([(1, "A", "Io"), (2, "B", "Partecipante 1"), (7, "C", "Partecipante 2")]),
            // empty text
            answer([(1, "A", "Io"), (2, "  ", "Partecipante 1"), (3, "C", "Partecipante 2")]),
            // a participant that does not exist in the call
            answer([(1, "A", "Io"), (2, "B", "Partecipante 3"), (3, "C", "Partecipante 2")]),
            // a name instead of a speaker
            answer([(1, "A", "Io"), (2, "B", "Anna"), (3, "C", "Partecipante 2")]),
            // a line of "Io" given to a participant
            answer([(1, "A", "Partecipante 1"), (2, "B", "Partecipante 1"), (3, "C", "Partecipante 2")]),
            // a participant line that becomes "Io"
            answer([(1, "A", "Io"), (2, "B", "Io"), (3, "C", "Partecipante 2")]),
            // a participant line that becomes "Altri", which is not a speaker of the refinement
            answer([(1, "A", "Io"), (2, "B", "Altri"), (3, "C", "Partecipante 2")]),
            // a field missing
            #"[{"number": 1, "text": "A"}, {"number": 2, "text": "B", "speaker": "Partecipante 1"}, {"number": 3, "text": "C", "speaker": "Partecipante 2"}]"#,
        ])
    func invalidAnswers(text: String) {
        #expect(request.corrections(from: text) == nil)
    }
}

@Suite("call refinement", .serialized)
@MainActor
struct CallRefinementTests {
    private func refinableCall(_ harness: CallHarness, _ state: CallState = .ready) throws -> Call {
        let call = try harness.insertCall(state, title: "Riunione")
        addLines(to: call, in: harness.context)
        try harness.context.save()
        return call
    }

    @Test("participants separated with refinement on: the original lines are refined and kept")
    func refinesAfterSeparation() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness, .separatingParticipants)

        #expect(harness.lifecycle.apply(.participantsSeparated(refinementOn: true), to: call) == .state(.refiningTranscript))
        #expect(await harness.eventually { call.state == .ready })

        #expect(refiner.prompts.count == 1)
        #expect(texts(call) == ["Buongiorno a tutti", "Il meeting è alle tre", "Va bene, grazie"])
        #expect(speakers(call) == ["Io", "Anna Rossi", "Anna Rossi"])
        #expect(call.sortedLines.map(\.originalText) == ["Buongiorno a tutti", "Il meeting e' alle tre", "Va bene"])
        #expect(call.sortedLines.map(\.originalSpeakerKind) == [.me, .participant, .participant])
        #expect(call.sortedLines.map(\.originalParticipantNumber) == [nil, 1, 2])
        #expect(call.isRefined)
    }

    @Test("with refinement off the call goes straight to Ready and the assistant is never asked")
    func refinementOffSkipsIt() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(separator: StubSeparator(), refiner: refiner, refinementOn: false)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness, .separatingParticipants)

        harness.lifecycle.startSeparation(of: call)
        #expect(await harness.eventually { call.state == .ready })

        #expect(refiner.prompts.isEmpty)
        #expect(!call.isRefined)
    }

    @Test("with refinement on the end of the separation starts the refinement")
    func separationThenRefinement() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(separator: StubSeparator(), refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness, .separatingParticipants)

        harness.lifecycle.startSeparation(of: call)

        #expect(await harness.eventually { call.state == .ready && call.isRefined })
        #expect(refiner.prompts.count == 1)
    }

    @Test(
        "an answer that is not valid applies nothing and the call awaits a retry",
        arguments: ["niente JSON", "[]", answer([(1, "A", "Io"), (2, "", "Partecipante 1"), (3, "C", "Partecipante 2")])])
    func invalidAnswerFails(text: String) async throws {
        let harness = try CallHarness(refiner: FakeRefiner { _ in text }, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)

        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .awaitingRefinementRetry })

        #expect(texts(call) == ["Buongiorno a tutti", "Il meeting e' alle tre", "Va bene"])
        #expect(speakers(call) == ["Io", "Anna Rossi", "Partecipante 2"])
        #expect(!call.isRefined)
        #expect(harness.lifecycle.statusLabel(of: call) == "Testo da rifinire")
    }

    @Test("an assistant that cannot be reached makes the refinement fail")
    func unreachableAssistantFails() async throws {
        let harness = try CallHarness(refiner: FakeRefiner { _ in throw AssistantFailure() }, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)

        harness.lifecycle.refineTranscript(call)

        #expect(await harness.eventually { call.state == .awaitingRefinementRetry })
    }

    @Test("a line of the others without participant makes the refinement fail without asking the assistant")
    func lineWithoutParticipantFails() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)
        call.sortedLines[1].speakerKind = .others
        call.sortedLines[1].participant = nil

        harness.lifecycle.refineTranscript(call)

        #expect(await harness.eventually { call.state == .awaitingRefinementRetry })
        #expect(refiner.prompts.isEmpty)
        #expect(!call.isRefined)
    }

    @Test("a failed refinement is tried again on the network, at launch and on request")
    func retries() async throws {
        let refiner = FakeRefiner { _ in throw AssistantFailure() }
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness, .awaitingRefinementRetry)
        refiner.setBehavior { _ in validAnswer }

        harness.lifecycle.networkAvailable()
        #expect(await harness.eventually { call.state == .ready && call.isRefined })

        // A refined call can be refined again, on request, from its original lines.
        refiner.setBehavior { _ in throw AssistantFailure() }
        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .awaitingRefinementRetry })
        refiner.setBehavior { _ in validAnswer }
        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { call.state == .ready })

        refiner.setBehavior { _ in throw AssistantFailure() }
        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .awaitingRefinementRetry })
        refiner.setBehavior { _ in validAnswer }
        harness.lifecycle.refineTranscript(call)
        #expect(call.state == .refiningTranscript)
        #expect(await harness.eventually { call.state == .ready })
    }

    @Test("a refinement starts from the original lines, never from an earlier refinement")
    func startsFromOriginals() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)

        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .ready })
        refiner.setBehavior { _ in
            answer([(1, "Buongiorno", "Io"), (2, "Il meeting", "Partecipante 1"), (3, "Ok", "Partecipante 2")])
        }
        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .ready && texts(call) == ["Buongiorno", "Il meeting", "Ok"] })

        #expect(refiner.prompts.count == 2)
        #expect(refiner.prompts[1].contains("Il meeting e' alle tre"))
        #expect(!refiner.prompts[1].contains("Il meeting è alle tre"))
        #expect(refiner.prompts[1].contains(#""speaker": "Partecipante 2""#))
        #expect(call.sortedLines.map(\.originalText) == ["Buongiorno a tutti", "Il meeting e' alle tre", "Va bene"])
        #expect(speakers(call) == ["Io", "Anna Rossi", "Partecipante 2"])
    }

    @Test("turning refinement off ends the process at once and leaves the text as it was")
    func turnOffStopsRefinement() async throws {
        let refiner = FakeRefiner(FakeRefiner.hangs)
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let refining = try refinableCall(harness)
        let waiting = try refinableCall(harness, .awaitingRefinementRetry)
        harness.lifecycle.refineTranscript(refining)
        #expect(await harness.eventually { refiner.prompts.count == 1 })

        harness.refinement.isOn = false
        harness.lifecycle.turnOffRefinement()

        #expect(refining.state == .ready)
        #expect(waiting.state == .ready)
        #expect(await harness.eventually { refiner.cancellations == 1 })
        #expect(!refining.isRefined)
        #expect(texts(refining) == ["Buongiorno a tutti", "Il meeting e' alle tre", "Va bene"])
        #expect(!harness.lifecycle.canRefine(refining))
    }

    @Test("deleting the call ends the refinement")
    func deleteStopsRefinement() async throws {
        let refiner = FakeRefiner(FakeRefiner.hangs)
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)
        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { refiner.prompts.count == 1 })

        harness.lifecycle.deleteCall(call)

        #expect(await harness.eventually { refiner.cancellations == 1 })
        #expect(try harness.allCalls().isEmpty)
    }

    @Test("renaming the call during the refinement keeps its state and the refinement running")
    func renameDuringRefinement() async throws {
        let refiner = FakeRefiner(FakeRefiner.hangs)
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)
        harness.lifecycle.refineTranscript(call)

        harness.lifecycle.renameCall(call, to: "Nuovo")
        let participant = try #require(call.participants.first { $0.number == 1 })
        harness.lifecycle.renameParticipant(participant, to: "Marco")

        #expect(call.title == "Nuovo")
        #expect(call.state == .refiningTranscript)
        #expect(participant.name == "Anna Rossi")
        harness.lifecycle.turnOffRefinement()
    }

    @Test("an app launched during the refinement starts it again")
    func launchRestartsRefinement() async throws {
        let refiner = FakeRefiner(FakeRefiner.hangs)
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness, .refiningTranscript)

        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { refiner.prompts.count == 1 })
        #expect(call.state == .refiningTranscript)
        refiner.setBehavior { _ in validAnswer }
        await harness.lifecycle.appLaunched()

        #expect(await harness.eventually { call.state == .ready && refiner.cancellations == 1 })
    }

    @Test("refine is offered only with refinement on, on a Ready call or one awaiting a retry")
    func canRefine() throws {
        let harness = try CallHarness(refiner: FakeRefiner(), refinementOn: true)
        defer { harness.cleanUp() }
        let states: [CallState: Bool] = [
            .ready: true, .awaitingRefinementRetry: true, .refiningTranscript: false, .transcribing: false,
            .separatingParticipants: false, .recording: false,
        ]
        for (state, expected) in states {
            let call = try harness.insertCall(state, withAudio: false)
            #expect(harness.lifecycle.canRefine(call) == expected, "\(state)")
        }
        harness.refinement.isOn = false
        for state in states.keys {
            let call = try harness.insertCall(state, withAudio: false)
            #expect(!harness.lifecycle.canRefine(call) || state == .awaitingRefinementRetry, "\(state)")
        }
        let ready = try harness.insertCall(.ready, withAudio: false)
        harness.lifecycle.refineTranscript(ready)
        #expect(ready.state == .ready)
    }

    @Test("a call recorded before refinement existed, or refined before, can be refined on request")
    func refineOnRequest() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)

        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .ready && call.isRefined })
        harness.lifecycle.refineTranscript(call)
        #expect(call.state == .refiningTranscript)
        #expect(await harness.eventually { call.state == .ready })
    }

    @Test("restoring gives every line its original text and speaker back and clears them")
    func restore() async throws {
        let refiner = FakeRefiner { _ in validAnswer }
        let harness = try CallHarness(refiner: refiner, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)
        #expect(!harness.lifecycle.canRestore(call))
        harness.lifecycle.restoreTranscript(call)
        #expect(refiner.prompts.isEmpty)

        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .ready && call.isRefined })
        harness.refinement.isOn = false
        #expect(harness.lifecycle.canRestore(call))
        harness.lifecycle.restoreTranscript(call)

        #expect(call.state == .ready)
        #expect(texts(call) == ["Buongiorno a tutti", "Il meeting e' alle tre", "Va bene"])
        #expect(speakers(call) == ["Io", "Anna Rossi", "Partecipante 2"])
        #expect(call.sortedLines.allSatisfy { $0.originalText == nil && $0.originalSpeakerKind == nil && $0.originalParticipantNumber == nil })
        #expect(!call.isRefined)
        #expect(!harness.lifecycle.canRestore(call))
        // Not refined again by itself.
        #expect(refiner.prompts.count == 1)
    }

    @Test("search and export use what the call shows: refined, then original after a restore")
    func searchAndExportFollowTheText() async throws {
        let harness = try CallHarness(refiner: FakeRefiner { _ in validAnswer }, refinementOn: true)
        defer { harness.cleanUp() }
        let call = try refinableCall(harness)
        harness.lifecycle.refineTranscript(call)
        #expect(await harness.eventually { call.state == .ready })

        #expect(CallSearch.matches(call, query: "alle tre"))
        #expect(CallSearch.matches(call, query: "grazie"))
        #expect(!CallSearch.matches(call, query: "e' alle"))
        #expect(TranscriptExport.markdown(for: call).contains("**Anna Rossi** [00:02]: Il meeting è alle tre"))
        #expect(TranscriptExport.markdown(for: call).contains("**Anna Rossi** [00:05]: Va bene, grazie"))

        harness.lifecycle.restoreTranscript(call)
        #expect(!CallSearch.matches(call, query: "grazie"))
        #expect(TranscriptExport.markdown(for: call).contains("**Partecipante 2** [00:05]: Va bene\n"))
    }
}

private struct StubSeparator: ParticipantSeparating {
    @MainActor func separate(_ call: Call) async throws {}
}

// MARK: omp

@Suite("OmpTranscriptRefiner", .serialized)
struct OmpTranscriptRefinerTests {
    private struct FixedLocator: OmpLocating {
        var url: URL?
        func locate() async -> URL? { url }
    }

    private final class Scripts {
        let directory: URL

        init() throws {
            directory = FileManager.default.temporaryDirectory
                .appending(path: "LARPRefinerTests-\(UUID().uuidString)", directoryHint: .isDirectory)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        deinit { try? FileManager.default.removeItem(at: directory) }

        var pidFile: URL { directory.appending(path: "pid") }

        /// An agent that answers the prompt with `reply` (or never does when `answers` is false).
        func agent(answers: Bool, reply: String = "[]") throws -> URL {
            let url = directory.appending(path: "agent.sh")
            let script = #"""
                #!/bin/sh
                echo $$ > "\#(pidFile.path)"
                while IFS= read -r line; do
                  id=$(printf '%s' "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
                  case "$line" in
                    *'"method":"initialize"'*)
                      printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":1}}\n' "$id" ;;
                    *'"method":"session/new"'*)
                      printf '{"jsonrpc":"2.0","id":%s,"result":{"sessionId":"s1"}}\n' "$id" ;;
                    *'"method":"session/prompt"'*)
                      if [ "\#(answers)" = "true" ]; then
                        printf '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"\#(reply)"}}}}\n'
                        printf '{"jsonrpc":"2.0","id":%s,"result":{"stopReason":"end_turn"}}\n' "$id"
                      fi ;;
                  esac
                done
                """#
            try script.write(to: url, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
            return url
        }

        /// Waits until the agent process has started and written its process ID.
        func processStarted() async -> Bool {
            for _ in 0..<400 {
                if let text = try? String(contentsOf: pidFile, encoding: .utf8),
                    Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)) != nil
                {
                    return true
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return false
        }

        func processEnded() async -> Bool {
            for _ in 0..<400 {
                if let text = try? String(contentsOf: pidFile, encoding: .utf8),
                    let pid = Int32(text.trimmingCharacters(in: .whitespacesAndNewlines)), kill(pid, 0) != 0
                {
                    return true
                }
                try? await Task.sleep(for: .milliseconds(10))
            }
            return false
        }
    }

    @Test("the answer of omp is the text of its messages")
    func answers() async throws {
        let scripts = try Scripts()
        let refiner = OmpTranscriptRefiner(locator: FixedLocator(url: try scripts.agent(answers: true, reply: "[1]")))

        #expect(try await refiner.refine(prompt: "istruzioni") == "[1]")
    }

    @Test("omp that is not found makes it fail")
    func notFound() async {
        let refiner = OmpTranscriptRefiner(locator: FixedLocator(url: nil))
        await #expect(throws: RefinementError.assistantNotFound) {
            try await refiner.refine(prompt: "x")
        }
    }

    @Test("without a complete answer within the limit the process is terminated and it fails")
    func timeLimit() async throws {
        let scripts = try Scripts()
        let refiner = OmpTranscriptRefiner(
            locator: FixedLocator(url: try scripts.agent(answers: false)), timeLimit: .milliseconds(600))

        await #expect(throws: ACPError.timedOut) {
            try await refiner.refine(prompt: "x")
        }
        #expect(await scripts.processEnded())
    }

    @Test("cancelling the refinement terminates the process at once")
    func cancellation() async throws {
        let scripts = try Scripts()
        let refiner = OmpTranscriptRefiner(locator: FixedLocator(url: try scripts.agent(answers: false)))
        let task = Task { try await refiner.refine(prompt: "x") }
        #expect(await scripts.processStarted())

        task.cancel()

        await #expect(throws: (any Error).self) { try await task.value }
        #expect(await scripts.processEnded())
    }
}
