import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

// MARK: Fakes

/// An assistant whose answer the test controls.
private final class FakeAssistant: TranscriptRefining {
    typealias Behavior = @Sendable (String) async throws -> String

    private struct State {
        var prompts: [String] = []
        var cancellations = 0
        var behavior: Behavior
    }

    private let state: Mutex<State>

    init(_ behavior: @escaping Behavior = { _ in "" }) {
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

private struct ReachableAssistant: AssistantChecking {
    func check() async -> Bool { true }
}

@MainActor
private final class Switch {
    var isOn: Bool
    init(_ isOn: Bool = true) { self.isOn = isOn }
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

/// A call with a line of "Me" and lines of two participants, one of them renamed by the user, and
/// the container that keeps it alive.
@MainActor
private struct CallFixture {
    /// The containers of the fixtures: a call is not usable once its container is gone, and the
    /// compiler may release a fixture after its last use.
    private static var containers: [ModelContainer] = []

    let container: ModelContainer
    let call: Call

    init(language: String = "it-IT", state: CallState = .ready, withLines: Bool = true) throws {
        container = try ArchiveStore.makeContainer(inMemory: true)
        Self.containers.append(container)
        call = Call(
            title: "Riunione riservata", startedAt: Date(timeIntervalSince1970: 1_700_000_000), callAppName: "Zoom",
            transcriptionLanguage: language, state: state)
        container.mainContext.insert(call)
        guard withLines else { return }
        let anna = Participant(number: 1, name: "Anna Rossi")
        let two = Participant(number: 2)
        call.participants.append(anna)
        call.participants.append(two)
        // Inserted out of order: the lines are sent sorted by start and then by end.
        call.lines.append(TranscriptLine(speakerKind: .participant, participant: two, start: 5, end: 7, text: "Va bene"))
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno a tutti"))
        let refined = TranscriptLine(
            speakerKind: .participant, participant: anna, start: 2.5, end: 4, text: "Il meeting è alle tre")
        refined.originalText = "Il meeting e' alle tre"
        refined.originalSpeakerKind = .participant
        refined.originalParticipantNumber = 1
        call.lines.append(refined)
        try container.mainContext.save()
    }
}

private func translationAnswer(_ items: [(Int, String)]) -> String {
    "[" + items.map { #"{"number": \#($0.0), "text": "\#($0.1)"}"# }.joined(separator: ",") + "]"
}

private let englishAnswer = translationAnswer([(1, "Good morning"), (2, "The meeting is at three"), (3, "Fine")])

// MARK: Switch and omp status

@MainActor
private struct Machines {
    let defaults: UserDefaults
    let assistant: FakeAssistantCheck
    let status: AssistantStatusController
    let questions: CallQuestionsController
    let summaries: CallSummariesController
    let refinement: TranscriptRefinementController

    init(questionsStored: Bool = false, summaryStored: Bool = false, refinementStored: Bool = false) {
        let defaults = UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
        defaults.set(questionsStored, forKey: SettingsKey.callQuestions)
        defaults.set(summaryStored, forKey: SettingsKey.callSummaries)
        defaults.set(refinementStored, forKey: SettingsKey.transcriptRefinement)
        self.defaults = defaults
        assistant = FakeAssistantCheck()
        status = AssistantStatusController(defaults: defaults, assistant: assistant)
        questions = CallQuestionsController(defaults: defaults, assistantStatus: status)
        summaries = CallSummariesController(defaults: defaults, assistantStatus: status)
        refinement = TranscriptRefinementController(defaults: defaults, assistantStatus: status)
    }
}

/// An assistant check that always answers the same, counting how often it is asked.
private final class FakeAssistantCheck: AssistantChecking {
    private let count = Mutex(0)
    var callCount: Int { count.withLock { $0 } }
    func check() async -> Bool {
        count.withLock { $0 += 1 }
        return true
    }
}

@Suite("CallQuestions switch", .serialized)
@MainActor
struct CallQuestionsSwitchTests {
    @Test("questions and translations are off by default")
    func offByDefault() {
        let machines = Machines()
        #expect(machines.questions.state == .off)
        #expect(machines.questions.isOn == false)
        #expect(machines.defaults.bool(forKey: SettingsKey.callQuestions) == false)
        #expect(machines.status.state == .notNeeded)
    }

    @Test("turning on is stored and makes omp looked for, whether or not it is reached")
    func turnOn() async {
        let machines = Machines()
        machines.questions.turnOn()
        #expect(machines.questions.state == .on)
        #expect(machines.questions.isOn)
        #expect(machines.defaults.bool(forKey: SettingsKey.callQuestions))
        #expect(machines.status.state == .checking)
        await machines.status.waitUntilIdle()
        #expect(machines.status.state == .assistantReady)
        #expect(machines.assistant.callCount == 1)
    }

    @Test("turning off is stored, signals the call page and leaves omp not needed when the others are off")
    func turnOff() async {
        let machines = Machines(questionsStored: true)
        let events = machines.questions.turnOffEvents
        machines.questions.turnOff()
        #expect(machines.questions.state == .off)
        #expect(machines.defaults.bool(forKey: SettingsKey.callQuestions) == false)
        #expect(machines.status.state == .notNeeded)
        var iterator = events.makeAsyncIterator()
        #expect(await iterator.next() != nil)
    }

    @Test("a stored switch is on at the next launch, Checking until the app has launched")
    func storedSwitchIsRestored() async {
        let machines = Machines(questionsStored: true)
        #expect(machines.questions.state == .on)
        #expect(machines.status.state == .checking)
        #expect(machines.assistant.callCount == 0)
        machines.status.appLaunched()
        await machines.status.waitUntilIdle()
        #expect(machines.status.state == .assistantReady)
        #expect(machines.assistant.callCount == 1)
    }

    @Test("turning on or off twice does nothing the second time")
    func twice() async {
        let machines = Machines()
        machines.questions.turnOff()
        #expect(machines.defaults.bool(forKey: SettingsKey.callQuestions) == false)
        machines.questions.turnOn()
        await machines.status.waitUntilIdle()
        machines.questions.turnOn()
        #expect(machines.assistant.callCount == 1)
    }

    @Test("omp stays needed while another of the three switches is on")
    func statusTakesAllThreeSwitchesIntoAccount() async {
        let machines = Machines(questionsStored: true, summaryStored: true)
        machines.status.openSettings()
        await machines.status.waitUntilIdle()
        machines.questions.turnOff()
        #expect(machines.status.state == .assistantReady)
        machines.questions.turnOn()
        // Ready stays ready when another switch is turned on: omp is not looked for again.
        #expect(machines.status.state == .assistantReady)
        #expect(machines.assistant.callCount == 1)
        machines.summaries.turnOff()
        #expect(machines.status.state == .assistantReady)
        machines.questions.turnOff()
        #expect(machines.status.state == .notNeeded)

        let refinementOnly = Machines(refinementStored: true)
        refinementOnly.questions.turnOn()
        refinementOnly.refinement.turnOff()
        #expect(refinementOnly.status.isNeeded)
        await refinementOnly.status.waitUntilIdle()
        refinementOnly.questions.turnOff()
        #expect(refinementOnly.status.state == .notNeeded)
    }

    @Test("turning questions off abandons the check in progress and ignores its result")
    func turnOffAbandonsCheck() async {
        let machines = Machines()
        machines.questions.turnOn()
        #expect(machines.status.state == .checking)
        machines.questions.turnOff()
        #expect(machines.status.state == .notNeeded)
        await machines.status.waitUntilIdle()
        #expect(machines.status.state == .notNeeded)
    }
}

// MARK: What omp receives

@Suite("CallQuestionRequest and TranscriptTranslationRequest", .italianInterface)
@MainActor
struct CallAssistanceRequestTests {
    @Test("the lines are sent as shown, sorted, numbered from 1, with Io and Partecipante and no names")
    func shownLines() throws {
        let fixture = try CallFixture()
        let lines = try #require(RefinementLine.shownLines(of: fixture.call))
        #expect(lines.map(\.number) == [1, 2, 3])
        #expect(lines.map(\.speaker) == [.me, .participant(1), .participant(2)])
        #expect(lines.map(\.start) == [0, 2.5, 5])
        #expect(lines.map(\.end) == [2, 4, 7])
        // The refined text, not the original one.
        #expect(lines.map(\.text) == ["Buongiorno a tutti", "Il meeting è alle tre", "Va bene"])
    }

    @Test("a line without participant is not sent")
    func lineWithoutParticipant() throws {
        let fixture = try CallFixture()
        fixture.call.lines.append(TranscriptLine(speakerKind: .others, start: 8, end: 9, text: "Boh"))
        #expect(RefinementLine.shownLines(of: fixture.call) == nil)
        #expect(CallQuestionRequest(call: fixture.call, question: "Chi c'era?") == nil)
        #expect(TranscriptTranslationRequest(call: fixture.call) == nil)
    }

    @Test("the question prompt has the instructions, the lines as JSON and the trimmed question, and nothing else of the call")
    func questionPrompt() throws {
        let fixture = try CallFixture()
        let request = try #require(CallQuestionRequest(call: fixture.call, question: "  Quando è la riunione?\n"))
        #expect(request.question == "Quando è la riunione?")
        let prompt = request.prompt
        #expect(prompt.hasPrefix(CallQuestionRequest.instructions))
        #expect(prompt.hasSuffix("Domanda: Quando è la riunione?"))
        #expect(prompt.contains(#""speaker": "Partecipante 1""#))
        #expect(prompt.contains(#""speaker": "Io""#))
        #expect(prompt.contains(#""text": "Il meeting è alle tre""#))
        #expect(prompt.contains(#"{"number": 1, "speaker": "Io", "start": 0, "end": 2, "text": "Buongiorno a tutti"}"#))
        // Never the names given, the title, the app or the dates.
        #expect(!prompt.contains("Anna"))
        #expect(!prompt.contains("Rossi"))
        #expect(!prompt.contains("Riunione riservata"))
        #expect(!prompt.contains("Zoom"))
        #expect(!prompt.contains("2023"))
        #expect(!prompt.contains("Il meeting e' alle tre"))
    }

    @Test("the instructions ask to answer from the lines, in the language of the question, naming people Io and Partecipante")
    func questionInstructions() {
        let text = CallQuestionRequest.instructions
        #expect(text.contains("solo in base alle righe"))
        #expect(text.contains("nella lingua della domanda"))
        #expect(text.contains(#""Io""#))
        #expect(text.contains(#""Partecipante <numero>""#))
        #expect(text.contains("la call non lo dice"))
    }

    @Test("the answer is the whole reply, trimmed; an empty reply is none")
    func questionAnswer() {
        #expect(CallQuestionRequest.answer(from: "\n  Alle tre.\n") == "Alle tre.")
        #expect(CallQuestionRequest.answer(from: "Riga 1\nRiga 2") == "Riga 1\nRiga 2")
        #expect(CallQuestionRequest.answer(from: " \n\t ") == nil)
        #expect(CallQuestionRequest.answer(from: "") == nil)
    }

    @Test("the translation goes into the other language of the two")
    func translationTarget() throws {
        #expect(TranscriptTranslationRequest.Target(callLanguage: "it-IT") == .english)
        #expect(TranscriptTranslationRequest.Target(callLanguage: "en-US") == .italian)
        let italian = try CallFixture(language: "it-IT")
        let english = try CallFixture(language: "en-US")
        let toEnglish = try #require(TranscriptTranslationRequest(call: italian.call))
        let toItalian = try #require(TranscriptTranslationRequest(call: english.call))
        #expect(toEnglish.prompt.hasSuffix("Lingua di destinazione: inglese"))
        #expect(toItalian.prompt.hasSuffix("Lingua di destinazione: italiano"))
        #expect(toEnglish.prompt.hasPrefix(TranscriptTranslationRequest.instructions))
        #expect(toEnglish.prompt.contains(#""speaker": "Partecipante 2""#))
        #expect(!toEnglish.prompt.contains("Anna"))
        #expect(TranscriptTranslationRequest.instructions.contains("Non unire, non dividere, non aggiungere e non togliere righe"))
    }

    @Test("a valid translation has every number once and a text that is not empty, from the first [ to the last ]")
    func validTranslation() throws {
        let request = try #require(TranscriptTranslationRequest(call: try CallFixture().call))
        let valid = translationAnswer([(2, " Meeting at three "), (1, "Good morning"), (3, "Fine")])
        #expect(request.translations(from: valid) == [1: "Good morning", 2: "Meeting at three", 3: "Fine"])
        // Words around the array and a code block are ignored.
        #expect(request.translations(from: "Ecco:\n```json\n\(valid)\n```\nFatto") != nil)
    }

    @Test(
        "an invalid translation is none",
        arguments: [
            "niente JSON",
            "[]",
            #"[{"number": 1, "text": "A"}, {"number": 2, "text": "B"}]"#,
            #"[{"number": 1, "text": "A"}, {"number": 2, "text": "B"}, {"number": 3, "text": "C"}, {"number": 4, "text": "D"}]"#,
            #"[{"number": 1, "text": "A"}, {"number": 1, "text": "B"}, {"number": 3, "text": "C"}]"#,
            #"[{"number": 1, "text": "A"}, {"number": 2, "text": "B"}, {"number": 4, "text": "C"}]"#,
            #"[{"number": 1, "text": "A"}, {"number": 2, "text": "  "}, {"number": 3, "text": "C"}]"#,
            #"[{"number": 1, "text": "A"}, {"number": 2}, {"number": 3, "text": "C"}]"#,
            #"{"number": 1, "text": "A"}"#,
        ])
    func invalidTranslation(answer: String) throws {
        let request = try #require(TranscriptTranslationRequest(call: try CallFixture().call))
        #expect(request.translations(from: answer) == nil)
    }
}

// MARK: Machines

@Suite("call-question machine table")
struct CallQuestionStateMachineTests {
    @Test("Ready to ask takes a question that is not empty and the page events keep it there")
    func readyToAsk() {
        let table = CallQuestionStateMachine.self
        #expect(table.target(from: .readyToAsk, on: .askCall(isEmpty: false)) == .answering)
        #expect(table.target(from: .readyToAsk, on: .askCall(isEmpty: true)) == nil)
        for event in [CallQuestionEvent.deselectCall, .openSettings, .closeWindow, .callDeleted(isShown: true)] {
            #expect(table.target(from: .readyToAsk, on: event) == .readyToAsk)
        }
        #expect(table.target(from: .readyToAsk, on: .callDeleted(isShown: false)) == nil)
        #expect(table.target(from: .readyToAsk, on: .turnOffQuestions) == nil)
        #expect(table.target(from: .readyToAsk, on: .questionAnswered) == nil)
    }

    @Test("Answering goes back to Ready to ask on every event but a new question")
    func answering() {
        let table = CallQuestionStateMachine.self
        for event in [
            CallQuestionEvent.questionAnswered, .questionFailed, .deselectCall, .openSettings, .closeWindow,
            .turnOffQuestions, .callDeleted(isShown: true),
        ] {
            #expect(table.target(from: .answering, on: event) == .readyToAsk)
        }
        #expect(table.target(from: .answering, on: .askCall(isEmpty: false)) == nil)
        #expect(table.target(from: .answering, on: .callDeleted(isShown: false)) == nil)
    }
}

@Suite("call-question machine", .serialized, .italianInterface)
@MainActor
struct CallQuestionsTests {
    private func machine(
        _ assistant: FakeAssistant, on: Bool = true
    ) -> (questions: CallQuestions, switch: Switch) {
        let toggle = Switch(on)
        return (CallQuestions(assistant: assistant, isOn: { toggle.isOn }), toggle)
    }

    @Test("a question goes to the list with a line saying omp is answering, and the field waits")
    func askWaits() async throws {
        let assistant = FakeAssistant(FakeAssistant.hangs)
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        #expect(questions.canAsk(fixture.call))

        #expect(questions.ask("  Quando è la riunione? ", of: fixture.call))
        #expect(questions.state == .answering)
        let entries = questions.entries(of: fixture.call.id)
        #expect(entries.map(\.question) == ["Quando è la riunione?"])
        #expect(entries.map(\.status) == [.answering])
        // The field does not take another question.
        #expect(!questions.canAsk(fixture.call))
        #expect(!questions.ask("Un'altra?", of: fixture.call))
        #expect(questions.entries(of: fixture.call.id).count == 1)
        await waitUntil { assistant.prompts.count == 1 }
        #expect(assistant.prompts.count == 1)
        questions.closeWindow()
    }

    @Test("a valid answer appears under its question and the field takes the next one, in order")
    func answers() async throws {
        let assistant = FakeAssistant { prompt in
            prompt.hasSuffix("Domanda: Prima?") ? "  Alle tre, dice Partecipante 1.\n" : "La call non lo dice."
        }
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()

        questions.ask("Prima?", of: fixture.call)
        await questions.waitUntilIdle()
        #expect(questions.state == .readyToAsk)
        #expect(questions.canAsk(fixture.call))
        questions.ask("Seconda?", of: fixture.call)
        await questions.waitUntilIdle()

        let entries = questions.entries(of: fixture.call.id)
        #expect(entries.map(\.question) == ["Prima?", "Seconda?"])
        #expect(
            entries.map(\.status) == [.answered("Alle tre, dice Partecipante 1."), .answered("La call non lo dice.")])
        // Earlier questions are not sent again.
        #expect(assistant.prompts.count == 2)
        #expect(!assistant.prompts[1].contains("Prima?"))
        #expect(assistant.prompts[1].contains(#""text": "Il meeting è alle tre""#))
    }

    @Test("an empty question, a call without lines or the switch off take nothing")
    func notAvailable() async throws {
        let assistant = FakeAssistant { _ in "ok" }
        let (questions, toggle) = machine(assistant)
        let fixture = try CallFixture()
        #expect(!questions.ask("  \n ", of: fixture.call))
        #expect(questions.state == .readyToAsk)
        #expect(questions.entries(of: fixture.call.id).isEmpty)

        let empty = try CallFixture(withLines: false)
        #expect(!questions.canAsk(empty.call))
        #expect(!questions.ask("Che si dice?", of: empty.call))

        toggle.isOn = false
        #expect(!questions.canAsk(fixture.call))
        #expect(!questions.ask("Che si dice?", of: fixture.call))
        #expect(assistant.prompts.isEmpty)
    }

    @Test(
        "omp that is not found, ends, answers with an error or with nothing makes the question fail, and Riprova asks it again",
        arguments: [0, 1])
    func failureAndRetry(kind: Int) async throws {
        let assistant = FakeAssistant { _ in
            if kind == 0 { throw RefinementError.assistantNotFound }
            return " \n"
        }
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()

        questions.ask("Chi parla?", of: fixture.call)
        await questions.waitUntilIdle()
        #expect(questions.entries(of: fixture.call.id).map(\.status) == [.failed])
        #expect(questions.state == .readyToAsk)

        assistant.setBehavior { _ in "Io e Partecipante 1." }
        let failed = try #require(questions.entries(of: fixture.call.id).first)
        #expect(questions.retry(failed.id, of: fixture.call))
        #expect(questions.entries(of: fixture.call.id).map(\.status) == [.answering])
        await questions.waitUntilIdle()
        let entries = questions.entries(of: fixture.call.id)
        // The question is asked again in its place.
        #expect(entries.map(\.id) == [failed.id])
        #expect(entries.map(\.status) == [.answered("Io e Partecipante 1.")])
        #expect(assistant.prompts.count == 2)
    }

    @Test("a line without participant makes the question fail without asking omp")
    func lineWithoutParticipant() async throws {
        let assistant = FakeAssistant { _ in "ok" }
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        fixture.call.lines.append(TranscriptLine(speakerKind: .others, start: 8, end: 9, text: "Boh"))
        questions.ask("Che si dice?", of: fixture.call)
        await questions.waitUntilIdle()
        #expect(questions.entries(of: fixture.call.id).map(\.status) == [.failed])
        #expect(assistant.prompts.isEmpty)
    }

    @Test("only a failed question can be retried")
    func retryOnlyFailed() async throws {
        let assistant = FakeAssistant { _ in "Sì." }
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        questions.ask("Va bene?", of: fixture.call)
        await questions.waitUntilIdle()
        let answered = try #require(questions.entries(of: fixture.call.id).first)
        #expect(!questions.retry(answered.id, of: fixture.call))
        #expect(!questions.retry(UUID(), of: fixture.call))
        #expect(assistant.prompts.count == 1)
    }

    @Test("turning the switch off ends the process at once and the question shows that it was stopped, never a failure")
    func turnOff() async throws {
        let assistant = FakeAssistant(FakeAssistant.hangs)
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        questions.ask("Quanto dura?", of: fixture.call)
        await waitUntil { assistant.prompts.count == 1 }

        questions.turnOffQuestions()
        #expect(questions.state == .readyToAsk)
        #expect(questions.entries(of: fixture.call.id).map(\.status) == [.stopped])
        await waitUntil { assistant.cancellations == 1 }
        // Nothing arrives afterwards.
        try await Task.sleep(for: .milliseconds(30))
        #expect(questions.entries(of: fixture.call.id).map(\.status) == [.stopped])
    }

    @Test("turning the switch off with nothing in progress changes nothing, the list stays")
    func turnOffIdle() async throws {
        let assistant = FakeAssistant { _ in "Sì." }
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        questions.ask("Va bene?", of: fixture.call)
        await questions.waitUntilIdle()
        questions.turnOffQuestions()
        #expect(questions.entries(of: fixture.call.id).map(\.status) == [.answered("Sì.")])
    }

    @Test("leaving the page empties the list and ends the process at once, whatever the gesture")
    func leavingThePage() async throws {
        let gestures: [(String, @MainActor (CallQuestions, UUID) -> Void)] = [
            ("deselect", { questions, _ in questions.deselectCall() }),
            ("settings", { questions, _ in questions.openSettings() }),
            ("close", { questions, _ in questions.closeWindow() }),
            ("deleted", { questions, id in questions.callDeleted(id) }),
        ]
        for (name, gesture) in gestures {
            let assistant = FakeAssistant { prompt in
                prompt.hasSuffix("Domanda: Finita?") ? "Sì." : try await FakeAssistant.hangs(prompt)
            }
            let (questions, _) = machine(assistant)
            let fixture = try CallFixture()
            questions.ask("Finita?", of: fixture.call)
            await questions.waitUntilIdle()
            questions.ask("In corso?", of: fixture.call)
            await waitUntil { assistant.prompts.count == 2 }

            gesture(questions, fixture.call.id)
            #expect(questions.entries(of: fixture.call.id).isEmpty, "\(name)")
            #expect(questions.state == .readyToAsk, "\(name)")
            await waitUntil { assistant.cancellations == 1 }
            // A failure never shows up for a question that was stopped.
            try await Task.sleep(for: .milliseconds(20))
            #expect(questions.entries(of: fixture.call.id).isEmpty, "\(name)")
        }
    }

    @Test("the deletion of another call changes nothing")
    func otherCallDeleted() async throws {
        let assistant = FakeAssistant(FakeAssistant.hangs)
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        questions.ask("Quanto dura?", of: fixture.call)
        questions.callDeleted(UUID())
        #expect(questions.state == .answering)
        #expect(questions.entries(of: fixture.call.id).count == 1)
        questions.closeWindow()
    }

    @Test("the list of a call is never shown for another one")
    func listBelongsToItsCall() async throws {
        let assistant = FakeAssistant { _ in "Sì." }
        let (questions, _) = machine(assistant)
        let fixture = try CallFixture()
        questions.ask("Va bene?", of: fixture.call)
        await questions.waitUntilIdle()
        #expect(questions.entries(of: UUID()).isEmpty)
    }
}

@Suite("transcript-translation machine table")
struct TranscriptTranslationStateMachineTests {
    private typealias Table = TranscriptTranslationStateMachine

    @Test("Original goes to Translating on Traduci and reacts to nothing else")
    func original() {
        #expect(Table.target(from: .original, on: .translateTranscript) == .translating)
        for event in [
            TranscriptTranslationEvent.showOriginal, .transcriptTranslated, .translationFailed, .deselectCall,
            .openSettings, .closeWindow, .turnOffQuestions, .editLine, .transcriptRefined(isShown: true),
            .callDeleted(isShown: true),
        ] {
            #expect(Table.target(from: .original, on: event) == nil)
        }
    }

    @Test("Translating ends in Translated or back in Original")
    func translating() {
        #expect(Table.target(from: .translating, on: .transcriptTranslated) == .translated)
        for event in [
            TranscriptTranslationEvent.translationFailed, .deselectCall, .openSettings, .closeWindow,
            .turnOffQuestions, .editLine, .callDeleted(isShown: true),
        ] {
            #expect(Table.target(from: .translating, on: event) == .original)
        }
        #expect(Table.target(from: .translating, on: .callDeleted(isShown: false)) == nil)
        #expect(Table.target(from: .translating, on: .showOriginal) == nil)
        #expect(Table.target(from: .translating, on: .transcriptRefined(isShown: true)) == nil)
    }

    @Test("Translated goes back to Original, the switch turned off and a second Traduci aside")
    func translated() {
        for event in [
            TranscriptTranslationEvent.showOriginal, .editLine, .deselectCall, .openSettings, .closeWindow,
            .transcriptRefined(isShown: true), .callDeleted(isShown: true),
        ] {
            #expect(Table.target(from: .translated, on: event) == .original)
        }
        #expect(Table.target(from: .translated, on: .transcriptRefined(isShown: false)) == nil)
        #expect(Table.target(from: .translated, on: .callDeleted(isShown: false)) == nil)
        #expect(Table.target(from: .translated, on: .turnOffQuestions) == nil)
        #expect(Table.target(from: .translated, on: .translateTranscript) == nil)
    }
}

@Suite("transcript-translation machine", .serialized, .italianInterface)
@MainActor
struct TranscriptTranslationTests {
    private func machine(
        _ assistant: FakeAssistant, on: Bool = true
    ) -> (translation: TranscriptTranslation, switch: Switch) {
        let toggle = Switch(on)
        return (TranscriptTranslation(assistant: assistant, isOn: { toggle.isOn }), toggle)
    }

    private func texts(_ translation: TranscriptTranslation, _ call: Call) -> [String?] {
        call.sortedLines.map { translation.text(of: $0) }
    }

    @Test("Traduci sends the lines as shown and every line then shows its translation instead of its text")
    func translates() async throws {
        let assistant = FakeAssistant { _ in englishAnswer }
        let (translation, _) = machine(assistant)
        let fixture = try CallFixture()
        #expect(translation.canTranslate(fixture.call))
        #expect(texts(translation, fixture.call) == [nil, nil, nil])

        #expect(translation.translate(fixture.call))
        #expect(translation.state == .translating)
        #expect(translation.isTranslating(fixture.call.id))
        #expect(!translation.canTranslate(fixture.call))
        await translation.waitUntilIdle()

        #expect(translation.state == .translated)
        #expect(translation.isTranslated(fixture.call.id))
        #expect(translation.target == .english)
        #expect(texts(translation, fixture.call) == ["Good morning", "The meeting is at three", "Fine"])
        #expect(assistant.prompts.count == 1)
        #expect(assistant.prompts[0].hasSuffix("Lingua di destinazione: inglese"))
        // Nothing of the call is stored: the lines keep their text.
        #expect(fixture.call.sortedLines.map(\.text) == ["Buongiorno a tutti", "Il meeting è alle tre", "Va bene"])

        translation.showOriginal()
        #expect(translation.state == .original)
        #expect(texts(translation, fixture.call) == [nil, nil, nil])
        #expect(translation.canTranslate(fixture.call))
    }

    @Test("a call in English is translated into Italian")
    func englishCall() async throws {
        let assistant = FakeAssistant { _ in englishAnswer }
        let (translation, _) = machine(assistant)
        let fixture = try CallFixture(language: "en-US")
        translation.translate(fixture.call)
        await translation.waitUntilIdle()
        #expect(translation.target == .italian)
        #expect(assistant.prompts[0].hasSuffix("Lingua di destinazione: italiano"))
    }

    @Test("Traduci is available only with the switch on and the call ready with lines")
    func availability() throws {
        let assistant = FakeAssistant { _ in englishAnswer }
        let (translation, toggle) = machine(assistant)
        let ready = try CallFixture()
        #expect(translation.canTranslate(ready.call))
        toggle.isOn = false
        #expect(!translation.canTranslate(ready.call))
        #expect(!translation.translate(ready.call))
        toggle.isOn = true
        #expect(!translation.canTranslate(try CallFixture(withLines: false).call))
        for state in [CallState.recording, .transcribing, .refiningTranscript, .separatingParticipants] {
            #expect(!translation.canTranslate(try CallFixture(state: state).call))
        }
        #expect(assistant.prompts.isEmpty)
    }

    @Test(
        "omp that is not found, answers with an error or with an answer that does not match the lines sent makes it fail: the original comes back and the panel says so",
        arguments: [
            "throws", "niente JSON", "[]", translationAnswer([(1, "A"), (2, "B")]),
            translationAnswer([(1, "A"), (2, "B"), (4, "C")]), translationAnswer([(1, "A"), (2, " "), (3, "C")]),
        ])
    func failure(answer: String) async throws {
        let assistant = FakeAssistant { _ in
            if answer == "throws" { throw RefinementError.assistantNotFound }
            return answer
        }
        let (translation, _) = machine(assistant)
        let fixture = try CallFixture()
        translation.translate(fixture.call)
        await translation.waitUntilIdle()

        #expect(translation.state == .original)
        #expect(translation.hasFailed(fixture.call.id))
        #expect(texts(translation, fixture.call) == [nil, nil, nil])

        // A new try starts clean and the failure of the earlier one goes away.
        assistant.setBehavior { _ in englishAnswer }
        #expect(translation.translate(fixture.call))
        #expect(!translation.hasFailed(fixture.call.id))
        await translation.waitUntilIdle()
        #expect(translation.state == .translated)
    }

    @Test("a failure shown is forgotten when the page is left")
    func failureForgotten() async throws {
        let assistant = FakeAssistant { _ in "niente" }
        let (translation, _) = machine(assistant)
        let fixture = try CallFixture()
        translation.translate(fixture.call)
        await translation.waitUntilIdle()
        #expect(translation.hasFailed(fixture.call.id))
        translation.deselectCall()
        #expect(!translation.hasFailed(fixture.call.id))
    }

    @Test("a translation in progress ends at once, the process is closed and the original stays, with every gesture that stops it")
    func stopsWhenTranslating() async throws {
        let gestures: [(String, @MainActor (TranscriptTranslation, UUID) -> Void)] = [
            ("deselect", { translation, _ in translation.deselectCall() }),
            ("settings", { translation, _ in translation.openSettings() }),
            ("close", { translation, _ in translation.closeWindow() }),
            ("off", { translation, _ in translation.turnOffQuestions() }),
            ("edit", { translation, _ in translation.editLine() }),
            ("deleted", { translation, id in translation.callDeleted(id) }),
        ]
        for (name, gesture) in gestures {
            let assistant = FakeAssistant(FakeAssistant.hangs)
            let (translation, _) = machine(assistant)
            let fixture = try CallFixture()
            translation.translate(fixture.call)
            await waitUntil { assistant.prompts.count == 1 }

            gesture(translation, fixture.call.id)
            #expect(translation.state == .original, "\(name)")
            #expect(!translation.hasFailed(fixture.call.id), "\(name)")
            #expect(texts(translation, fixture.call) == [nil, nil, nil], "\(name)")
            await waitUntil { assistant.cancellations == 1 }
            try await Task.sleep(for: .milliseconds(20))
            // Never a failure for a translation that was stopped.
            #expect(!translation.hasFailed(fixture.call.id), "\(name)")
            #expect(translation.state == .original, "\(name)")
        }
    }

    @Test("a translation shown is dropped by the page gestures, a line corrected and a refinement of the call shown")
    func dropsWhenTranslated() async throws {
        let gestures: [(String, @MainActor (TranscriptTranslation, UUID) -> Void)] = [
            ("deselect", { translation, _ in translation.deselectCall() }),
            ("settings", { translation, _ in translation.openSettings() }),
            ("close", { translation, _ in translation.closeWindow() }),
            ("edit", { translation, _ in translation.editLine() }),
            ("refined", { translation, id in translation.transcriptRefined(id) }),
            ("deleted", { translation, id in translation.callDeleted(id) }),
        ]
        for (name, gesture) in gestures {
            let assistant = FakeAssistant { _ in englishAnswer }
            let (translation, _) = machine(assistant)
            let fixture = try CallFixture()
            translation.translate(fixture.call)
            await translation.waitUntilIdle()
            #expect(translation.state == .translated, "\(name)")

            gesture(translation, fixture.call.id)
            #expect(translation.state == .original, "\(name)")
            #expect(texts(translation, fixture.call) == [nil, nil, nil], "\(name)")
        }
    }

    @Test("the refinement or the deletion of another call, and the switch turned off, leave a translation shown")
    func keepsWhenTranslated() async throws {
        let assistant = FakeAssistant { _ in englishAnswer }
        let (translation, _) = machine(assistant)
        let fixture = try CallFixture()
        translation.translate(fixture.call)
        await translation.waitUntilIdle()

        translation.transcriptRefined(UUID())
        translation.callDeleted(UUID())
        translation.turnOffQuestions()
        #expect(translation.state == .translated)
        #expect(texts(translation, fixture.call) == ["Good morning", "The meeting is at three", "Fine"])
    }

    @Test("the interface names the language of a translation shown")
    func eyebrow() {
        #expect(TranscriptTranslationBar.eyebrow(.english, language: .italian) == "Tradotto in inglese")
        #expect(TranscriptTranslationBar.eyebrow(.italian, language: .italian) == "Tradotto in italiano")
        #expect(TranscriptTranslationBar.eyebrow(.english, language: .english) == "Translated to English")
        #expect(TranscriptTranslationBar.eyebrow(.italian, language: .english) == "Translated to Italian")
    }
}

// MARK: Main window

@MainActor
private final class SilentPlayer: TrackPlayer {
    var duration: TimeInterval = 60
    var currentTime: TimeInterval = 0
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    var speed: Double = 1
    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) { currentTime = time }
    func stop() {}
    func unload() {}
}

@Suite("questions and translation in the main window", .serialized, .italianInterface)
@MainActor
struct QuestionsInTheMainWindowTests {
    @MainActor private struct Window {
        let assistant: FakeAssistant
        let model: MainWindowModel
        let fixture: CallFixture

        init(hangs: Bool = true) throws {
            let answering: FakeAssistant.Behavior = { _ in "Risposta" }
            assistant = FakeAssistant(hangs ? FakeAssistant.hangs : answering)
            let player = SilentPlayer()
            model = MainWindowModel(
                playback: PlaybackController(makePlayer: { _ in player }),
                questions: CallQuestions(assistant: assistant, isOn: { true }),
                translation: TranscriptTranslation(assistant: assistant, isOn: { true }))
            fixture = try CallFixture()
            model.selectCall(fixture.call.id)
        }
    }

    /// Asks a question and translates, both being worked on.
    private func busy(_ window: Window) async {
        window.model.questions.ask("Quanto dura?", of: window.fixture.call)
        window.model.translation.translate(window.fixture.call)
        await waitUntil { window.assistant.prompts.count == 2 }
    }

    @Test("the gestures that leave the page of the call stop both processes at once and empty the list")
    func leaving() async throws {
        let gestures: [(String, @MainActor (MainWindowModel, Call) -> Void)] = [
            ("archive", { model, _ in model.showLibrary() }),
            ("all calls", { model, _ in model.showAllCalls() }),
            ("bookmarks", { model, _ in model.showBookmarksView() }),
            ("settings", { model, _ in model.showSettings() }),
            ("close window", { model, _ in model.windowClosed() }),
            ("deleted", { model, call in model.callDeleted(call.id) }),
        ]
        for (name, gesture) in gestures {
            let window = try Window()
            await busy(window)
            let id = window.fixture.call.id

            gesture(window.model, window.fixture.call)
            #expect(window.model.questions.entries(of: id).isEmpty, "\(name)")
            #expect(window.model.questions.state == .readyToAsk, "\(name)")
            #expect(window.model.translation.state == .original, "\(name)")
            await waitUntil { window.assistant.cancellations == 2 }
            #expect(window.model.translation.hasFailed(id) == false, "\(name)")
        }
    }

    @Test("the deletion of another call leaves the page of the call shown as it is")
    func otherCallDeleted() async throws {
        let window = try Window()
        await busy(window)
        window.model.callDeleted(UUID())
        #expect(window.model.page == .call(window.fixture.call.id))
        #expect(window.model.questions.state == .answering)
        #expect(window.model.translation.state == .translating)
        window.model.windowClosed()
    }

    @Test("turning the switch off stops the question, which shows it was stopped, and the translation")
    func switchOff() async throws {
        let window = try Window()
        await busy(window)
        window.model.questionsTurnedOff()
        #expect(window.model.questions.entries(of: window.fixture.call.id).map(\.status) == [.stopped])
        #expect(window.model.translation.state == .original)
        #expect(window.model.page == .call(window.fixture.call.id))
        await waitUntil { window.assistant.cancellations == 2 }
    }

    @Test("a refinement arrived for the call shown drops the translation")
    func refined() async throws {
        let window = try Window(hangs: false)
        window.assistant.setBehavior { _ in translationAnswer([(1, "A"), (2, "B"), (3, "C")]) }
        window.model.translation.translate(window.fixture.call)
        await window.model.translation.waitUntilIdle()
        #expect(window.model.translation.state == .translated)
        window.model.transcriptRefined(UUID())
        #expect(window.model.translation.state == .translated)
        window.model.transcriptRefined(window.fixture.call.id)
        #expect(window.model.translation.state == .original)
    }

    @Test("correcting a line drops a translation shown, or ends the one in progress, and the line takes the typed text")
    func editLine() async throws {
        for translated in [true, false] {
            let harness = try CallHarness()
            defer { harness.cleanUp() }
            let call = try harness.insertCall(.ready)
            call.participants.append(Participant(number: 1))
            call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno"))
            call.lines.append(
                TranscriptLine(speakerKind: .participant, participant: call.participants[0], start: 3, end: 4, text: "Ciao"))
            try harness.context.save()

            let answering: FakeAssistant.Behavior = { _ in translationAnswer([(1, "Good morning"), (2, "Hi")]) }
            let assistant = FakeAssistant(translated ? answering : FakeAssistant.hangs)
            let player = SilentPlayer()
            let model = MainWindowModel(
                playback: PlaybackController(makePlayer: { _ in player }),
                questions: CallQuestions(assistant: assistant, isOn: { true }),
                translation: TranscriptTranslation(assistant: assistant, isOn: { true }))
            model.selectCall(call.id)
            model.translation.translate(call)
            if translated {
                await model.translation.waitUntilIdle()
                #expect(model.translation.state == .translated)
            } else {
                await waitUntil { assistant.prompts.count == 1 }
            }

            let line = try #require(call.sortedLines.first)
            model.editLine(line, of: call, to: "  Buonasera ", lifecycle: harness.lifecycle)

            #expect(model.translation.state == .original)
            #expect(call.sortedLines.map { model.translation.text(of: $0) } == [String?.none, .none])
            #expect(line.text == "Buonasera")
            if !translated { await waitUntil { assistant.cancellations == 1 } }
        }
    }
}
