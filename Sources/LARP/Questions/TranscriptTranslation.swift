import Foundation
import Observation
import SwiftData
import os

/// States of the `transcript-translation` machine.
enum TranscriptTranslationState: Sendable, Equatable {
    /// The lines show their own text.
    case original
    /// omp is translating the lines.
    case translating
    /// The lines show their translation.
    case translated
}

/// Events the `transcript-translation` machine reacts to.
enum TranscriptTranslationEvent: Sendable, Equatable {
    /// `user.TRANSLATE_TRANSCRIPT`
    case translateTranscript
    /// `user.SHOW_ORIGINAL`
    case showOriginal
    /// `transcript-translation.TRANSCRIPT_TRANSLATED`
    case transcriptTranslated
    /// `transcript-translation.TRANSLATION_FAILED`
    case translationFailed
    /// `user.DESELECT_CALL`
    case deselectCall
    /// `user.OPEN_SETTINGS`
    case openSettings
    /// `user.CLOSE_WINDOW`
    case closeWindow
    /// `user.TURN_OFF_QUESTIONS`
    case turnOffQuestions
    /// `user.EDIT_LINE`
    case editLine
    /// `call.TRANSCRIPT_REFINED`; `isShown`: the refined call is the one shown.
    case transcriptRefined(isShown: Bool)
    /// `call.DELETED`; `isShown`: the deleted call is the one shown.
    case callDeleted(isShown: Bool)
}

/// The transition table of the `transcript-translation` machine (Model
/// `library/transcript-translation`). Pure: it only says where an event leads;
/// `TranscriptTranslation` performs the effects. A state that does not react to an event has no
/// entry (`nil`).
enum TranscriptTranslationStateMachine {
    static func target(
        from state: TranscriptTranslationState, on event: TranscriptTranslationEvent
    ) -> TranscriptTranslationState? {
        switch (state, event) {
        // Original
        case (.original, .translateTranscript):
            return .translating

        // Translating
        case (.translating, .transcriptTranslated):
            return .translated
        case (.translating, .translationFailed):
            return .original
        case (.translating, .deselectCall), (.translating, .openSettings), (.translating, .closeWindow),
            (.translating, .turnOffQuestions), (.translating, .editLine):
            return .original
        case (.translating, .callDeleted(let isShown)):
            return isShown ? .original : nil

        // Translated
        case (.translated, .showOriginal), (.translated, .editLine), (.translated, .deselectCall),
            (.translated, .openSettings), (.translated, .closeWindow):
            return .original
        case (.translated, .transcriptRefined(let isShown)), (.translated, .callDeleted(let isShown)):
            return isShown ? .original : nil

        default:
            return nil
        }
    }
}

/// The `transcript-translation` machine: the translation of the transcript of the call shown, made
/// by omp into the other language of the two. The lines are sent in a process of their own as they
/// are shown (`TranscriptTranslationRequest`); the translation is shown in place of the text of the
/// lines and never stored.
///
/// One instance lives with the main window (`MainWindowModel`), which tells it the events of the
/// pages; the app entry point tells it `user.TURN_OFF_QUESTIONS`.
@MainActor
@Observable
final class TranscriptTranslation {
    private static let logger = Logger(subsystem: "com.larp.LARP", category: "transcript-translation")

    private(set) var state: TranscriptTranslationState = .original
    /// The last translation could not be made: the panel says so until the next try or the next
    /// change of page.
    private(set) var hasFailed = false
    /// The call the translation belongs to; `nil` in Original.
    private(set) var callID: UUID?
    /// The language the lines are translated into, while translating or translated.
    private(set) var target: TranscriptTranslationRequest.Target?
    private var translations: [PersistentIdentifier: String] = [:]

    @ObservationIgnored private let assistant: any TranscriptRefining
    @ObservationIgnored private let isOn: @MainActor () -> Bool
    @ObservationIgnored private var task: Task<Void, Never>?
    /// Identifies the translation in progress; an answer that comes for an older one is ignored.
    @ObservationIgnored private var generation = 0

    init(
        assistant: any TranscriptRefining = OmpTranscriptRefiner(),
        isOn: @escaping @MainActor () -> Bool = { CallQuestionsController.shared.isOn }
    ) {
        self.assistant = assistant
        self.isOn = isOn
    }

    /// Whether "Traduci" is available: questions and translations are on, the call is ready, has
    /// lines and is not being translated or shown translated.
    func canTranslate(_ call: Call) -> Bool {
        isOn() && call.state == .ready && !call.lines.isEmpty && state == .original
    }

    /// The translation of `line`, `nil` when the lines show their own text.
    func text(of line: TranscriptLine) -> String? {
        state == .translated ? translations[line.persistentModelID] : nil
    }

    /// Whether the lines of `callID` show their translation.
    func isTranslated(_ callID: UUID) -> Bool {
        state == .translated && self.callID == callID
    }

    /// Whether `callID` is being translated.
    func isTranslating(_ callID: UUID) -> Bool {
        state == .translating && self.callID == callID
    }

    /// Whether the last translation of `callID` failed.
    func hasFailed(_ callID: UUID) -> Bool {
        hasFailed && self.callID == callID
    }

    // MARK: Events

    /// `user.TRANSLATE_TRANSCRIPT`: the lines are sent to omp. Returns whether it started.
    @discardableResult
    func translate(_ call: Call) -> Bool {
        guard canTranslate(call), apply(.translateTranscript) else { return false }
        hasFailed = false
        callID = call.id
        let request = TranscriptTranslationRequest(call: call)
        target = request?.target ?? TranscriptTranslationRequest.Target(callLanguage: call.transcriptionLanguage)
        let ids = call.sortedLines.map(\.persistentModelID)
        generation += 1
        let current = generation
        let assistant = assistant
        task = Task { [weak self] in
            do {
                // A line without participant is not sent: the translation fails.
                guard let request else { throw RefinementError.lineWithoutParticipant }
                let reply = try await assistant.refine(prompt: request.prompt)
                try Task.checkCancellation()
                self?.finish(request: request, ids: ids, reply: reply, generation: current)
            } catch {
                // Stopped (page left, turned off, line edited): never a failure.
                guard !Task.isCancelled else { return }
                Self.logger.error("Translation failed: \(error.localizedDescription, privacy: .public)")
                self?.finish(request: nil, ids: ids, reply: nil, generation: current)
            }
        }
        return true
    }

    /// `user.SHOW_ORIGINAL`: the translation is dropped.
    func showOriginal() { move(.showOriginal) }

    /// `user.EDIT_LINE`: the translation is dropped, or the one in progress ended, and the line takes
    /// the text typed over its original text (the editor of the transcript does that).
    func editLine() { move(.editLine, forgetsFailure: true) }

    /// `user.DESELECT_CALL`
    func deselectCall() { move(.deselectCall, forgetsFailure: true) }

    /// `user.OPEN_SETTINGS`
    func openSettings() { move(.openSettings, forgetsFailure: true) }

    /// `user.CLOSE_WINDOW`
    func closeWindow() { move(.closeWindow, forgetsFailure: true) }

    /// `user.TURN_OFF_QUESTIONS`: a translation in progress ends at once.
    func turnOffQuestions() { move(.turnOffQuestions) }

    /// `call.TRANSCRIPT_REFINED`: only for the call shown, the translation is dropped.
    func transcriptRefined(_ id: UUID) { move(.transcriptRefined(isShown: callID == id), forgetsFailure: callID == id) }

    /// `call.DELETED`: only for the call shown.
    func callDeleted(_ id: UUID) { move(.callDeleted(isShown: callID == id), forgetsFailure: callID == id) }

    /// Returns when the translation in progress has finished.
    func waitUntilIdle() async {
        await task?.value
    }

    // MARK: Machine

    /// A change of state: going back to Original ends the process of omp at once, if running, and
    /// drops the translation. `forgetsFailure`: the failure the panel shows is forgotten too.
    private func move(_ event: TranscriptTranslationEvent, forgetsFailure: Bool = false) {
        if let target = TranscriptTranslationStateMachine.target(from: state, on: event) {
            state = target
            if target == .original { forget() }
        }
        if forgetsFailure { hasFailed = false }
    }

    private func forget() {
        task?.cancel()
        task = nil
        generation += 1
        translations = [:]
        target = nil
        callID = nil
        hasFailed = false
    }

    /// `transcript-translation.TRANSCRIPT_TRANSLATED` when `reply` is a valid translation of every
    /// line sent, `transcript-translation.TRANSLATION_FAILED` otherwise.
    private func finish(
        request: TranscriptTranslationRequest?, ids: [PersistentIdentifier], reply: String?, generation current: Int
    ) {
        guard current == generation, state == .translating else { return }
        task = nil
        guard let request, let reply, let byNumber = request.translations(from: reply) else {
            Self.logger.error("The answer of the assistant is not a valid translation")
            // `TRANSLATION_FAILED`: the original comes back and the panel says it did not work.
            let id = callID
            apply(.translationFailed)
            forget()
            callID = id
            hasFailed = true
            return
        }
        var shown: [PersistentIdentifier: String] = [:]
        for (index, id) in ids.enumerated() {
            shown[id] = byNumber[index + 1]
        }
        apply(.transcriptTranslated)
        translations = shown
    }

    @discardableResult
    private func apply(_ event: TranscriptTranslationEvent) -> Bool {
        guard let target = TranscriptTranslationStateMachine.target(from: state, on: event) else { return false }
        state = target
        return true
    }
}
