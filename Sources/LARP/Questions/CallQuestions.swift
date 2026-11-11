import Foundation
import Observation
import os

/// States of the `call-question` machine.
enum CallQuestionState: Sendable, Equatable {
    /// The field takes a question.
    case readyToAsk
    /// omp is working on the last question; the field cannot take another one.
    case answering
}

/// Events the `call-question` machine reacts to.
enum CallQuestionEvent: Sendable, Equatable {
    /// `user.ASK_CALL`; `isEmpty`: the question is empty once trimmed.
    case askCall(isEmpty: Bool)
    /// `user.DESELECT_CALL`
    case deselectCall
    /// `user.OPEN_SETTINGS`
    case openSettings
    /// `user.CLOSE_WINDOW`
    case closeWindow
    /// `call.DELETED`; `isShown`: the deleted call is the one shown.
    case callDeleted(isShown: Bool)
    /// `call-question.QUESTION_ANSWERED`
    case questionAnswered
    /// `call-question.QUESTION_FAILED`
    case questionFailed
    /// `user.TURN_OFF_QUESTIONS`
    case turnOffQuestions
}

/// The transition table of the `call-question` machine (Model `library/call-question`). Pure: it
/// only says where an event leads; `CallQuestions` performs the effects. A state that does not
/// react to an event has no entry (`nil`).
enum CallQuestionStateMachine {
    static func target(from state: CallQuestionState, on event: CallQuestionEvent) -> CallQuestionState? {
        switch (state, event) {
        // Ready to ask
        case (.readyToAsk, .askCall(let isEmpty)):
            return isEmpty ? nil : .answering
        case (.readyToAsk, .deselectCall), (.readyToAsk, .openSettings), (.readyToAsk, .closeWindow):
            return .readyToAsk
        case (.readyToAsk, .callDeleted(let isShown)):
            return isShown ? .readyToAsk : nil

        // Answering
        case (.answering, .questionAnswered), (.answering, .questionFailed):
            return .readyToAsk
        case (.answering, .deselectCall), (.answering, .openSettings), (.answering, .closeWindow),
            (.answering, .turnOffQuestions):
            return .readyToAsk
        case (.answering, .callDeleted(let isShown)):
            return isShown ? .readyToAsk : nil

        default:
            return nil
        }
    }
}

/// The `call-question` machine: the questions the user asks omp about the call shown, and their
/// answers. Questions and answers are listed in order while the page of the call stays open and are
/// never stored: leaving the page empties the list. Each question is sent to omp in a process of its
/// own, with the lines of the call as they are shown (`CallQuestionRequest`).
///
/// One instance lives with the main window (`MainWindowModel`), which tells it the events of the
/// pages; the app entry point tells it `user.TURN_OFF_QUESTIONS`.
@MainActor
@Observable
final class CallQuestions {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "call-question")

    /// What a listed question is doing.
    enum Status: Equatable, Sendable {
        /// "omp sta rispondendo…"
        case answering
        /// The answer, as omp wrote it: it names participants "Partecipante <numero>".
        case answered(String)
        /// omp could not answer: "Riprova" asks it again.
        case failed
        /// The switch was turned off while omp was answering.
        case stopped
    }

    /// A question of the list with what omp answered.
    struct Entry: Identifiable, Equatable, Sendable {
        let id: UUID
        let question: String
        var status: Status
    }

    private(set) var state: CallQuestionState = .readyToAsk
    /// The call the list belongs to; `nil` while the list is empty.
    private(set) var callID: UUID?
    private var allEntries: [Entry] = []

    @ObservationIgnored private let assistant: any TranscriptRefining
    @ObservationIgnored private let isOn: @MainActor () -> Bool
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Identifies the question being answered; an answer that comes for an older one is ignored.
    @ObservationIgnored private var generation = 0

    init(
        assistant: any TranscriptRefining = OmpTranscriptRefiner(),
        isOn: @escaping @MainActor () -> Bool = { CallQuestionsController.shared.isOn }
    ) {
        self.assistant = assistant
        self.isOn = isOn
    }

    /// The questions and answers of `callID`, in the order they were asked.
    func entries(of callID: UUID) -> [Entry] {
        self.callID == callID ? allEntries : []
    }

    /// Whether the field takes a question: questions and translations are on, the call has lines
    /// and no question is being answered.
    func canAsk(_ call: Call) -> Bool {
        isOn() && !call.lines.isEmpty && state == .readyToAsk
    }

    // MARK: Events

    /// `user.ASK_CALL`, from the field: only for a question that is not empty once trimmed; the
    /// question is added to the list and sent to omp. Returns whether it was taken.
    @discardableResult
    func ask(_ text: String, of call: Call) -> Bool {
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard canAsk(call), apply(.askCall(isEmpty: question.isEmpty)) else { return false }
        if callID != call.id { allEntries = [] }
        callID = call.id
        let entry = Entry(id: UUID(), question: question, status: .answering)
        allEntries.append(entry)
        start(entry, of: call)
        return true
    }

    /// `user.ASK_CALL`, from "Riprova" on a question that failed: it is asked again, in its place.
    @discardableResult
    func retry(_ entryID: UUID, of call: Call) -> Bool {
        guard canAsk(call), callID == call.id,
            let index = allEntries.firstIndex(where: { $0.id == entryID }), allEntries[index].status == .failed,
            apply(.askCall(isEmpty: false))
        else { return false }
        allEntries[index].status = .answering
        start(allEntries[index], of: call)
        return true
    }

    /// `user.DESELECT_CALL`: the process of omp ends at once and the list is emptied.
    func deselectCall() { leave(.deselectCall) }

    /// `user.OPEN_SETTINGS`: the process of omp ends at once and the list is emptied.
    func openSettings() { leave(.openSettings) }

    /// `user.CLOSE_WINDOW`: the process of omp ends at once and the list is emptied.
    func closeWindow() { leave(.closeWindow) }

    /// `call.DELETED`: only for the call shown, the process of omp ends and the list is emptied.
    func callDeleted(_ id: UUID) { leave(.callDeleted(isShown: callID == id)) }

    /// `user.TURN_OFF_QUESTIONS`: the process of omp ends at once and the question shows that it was
    /// stopped.
    func turnOffQuestions() {
        guard apply(.turnOffQuestions) else { return }
        stopWork()
        for index in allEntries.indices where allEntries[index].status == .answering {
            allEntries[index].status = .stopped
        }
    }

    /// Returns when the question being answered has finished.
    func waitUntilIdle() async {
        await task?.value
    }

    // MARK: Machine

    @discardableResult
    private func apply(_ event: CallQuestionEvent) -> Bool {
        guard let target = CallQuestionStateMachine.target(from: state, on: event) else { return false }
        state = target
        return true
    }

    private func leave(_ event: CallQuestionEvent) {
        guard apply(event) else { return }
        stopWork()
        allEntries = []
        callID = nil
    }

    private func stopWork() {
        task?.cancel()
        task = nil
        generation += 1
    }

    /// The work of **Answering**: sends the lines as shown and the question to omp, off the main
    /// actor, in a process of its own, and emits `QUESTION_ANSWERED` or `QUESTION_FAILED`.
    private func start(_ entry: Entry, of call: Call) {
        generation += 1
        let current = generation
        let assistant = assistant
        let request = CallQuestionRequest(call: call, question: entry.question)
        task = Task { [weak self] in
            do {
                // A line without participant is not sent: the question fails.
                guard let request else { throw RefinementError.lineWithoutParticipant }
                let reply = try await assistant.refine(prompt: request.prompt)
                try Task.checkCancellation()
                self?.finish(entry.id, reply: reply, generation: current)
            } catch {
                // Stopped (turned off, page left): never a failure.
                guard !Task.isCancelled else { return }
                Self.logger.error("Question failed: \(error.localizedDescription, privacy: .public)")
                self?.finish(entry.id, reply: nil, generation: current)
            }
        }
    }

    /// `call-question.QUESTION_ANSWERED` when `reply` is a text that is not empty,
    /// `call-question.QUESTION_FAILED` otherwise.
    private func finish(_ entryID: UUID, reply: String?, generation current: Int) {
        guard current == generation, let index = allEntries.firstIndex(where: { $0.id == entryID }) else { return }
        if let reply, let answer = CallQuestionRequest.answer(from: reply) {
            guard apply(.questionAnswered) else { return }
            allEntries[index].status = .answered(answer)
        } else {
            guard apply(.questionFailed) else { return }
            allEntries[index].status = .failed
        }
        task = nil
    }
}
