import Foundation
import os

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "refinement") }

    // MARK: Work of Refining transcript

    /// The work of **Refining transcript**: sends the original lines of the call to the
    /// assistant, off the main actor, and emits `TRANSCRIPT_REFINED` once a valid answer
    /// has been applied, or `REFINEMENT_FAILED` when it could not be done. Starting again
    /// for a call ends the refinement in progress.
    func startRefinement(of call: Call) {
        guard let refiner else { return }
        let id = call.id
        runningRefinements[id]?.task.cancel()
        refinementCounter += 1
        let token = refinementCounter
        let request = RefinementRequest(call: call)
        let task = Task {
            do {
                // A line without participant is not sent: the refinement fails.
                guard let request else { throw RefinementError.lineWithoutParticipant }
                let answer = try await refiner.refine(prompt: request.prompt)
                try Task.checkCancellation()
                finishRefinement(callID: id, request: request, answer: answer)
            } catch {
                // Stopped (turned off, deleted, replaced): not a failure.
                if !Task.isCancelled {
                    Self.logger.error("Refinement failed: \(error.localizedDescription, privacy: .public)")
                    failRefinement(callID: id)
                }
            }
            if runningRefinements[id]?.token == token {
                runningRefinements[id] = nil
            }
        }
        runningRefinements[id] = (token, task)
    }

    private func finishRefinement(callID: UUID, request: RefinementRequest, answer: String) {
        guard let call = call(id: callID), call.state == .refiningTranscript else { return }
        guard let corrections = request.corrections(from: answer), applyRefinement(corrections, to: call) else {
            Self.logger.error("The answer of the assistant does not match the lines sent")
            apply(.refinementFailed, to: call)
            return
        }
        apply(.transcriptRefined, to: call)
    }

    private func failRefinement(callID: UUID) {
        guard let call = call(id: callID), call.state == .refiningTranscript else { return }
        apply(.refinementFailed, to: call)
    }

    /// Gives every line its corrected text and speaker, keeping its original text and
    /// speaker (the ones already kept when the call was refined before), in a single
    /// save. Nothing is changed and `false` is returned when a correction names a
    /// participant the call does not have.
    private func applyRefinement(_ corrections: [RefinementCorrection], to call: Call) -> Bool {
        let lines = call.sortedLines
        guard lines.count == corrections.count else { return false }
        let participants = Dictionary(call.participants.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
        var speakers: [(kind: SpeakerKind, participant: Participant?)] = []
        for correction in corrections {
            switch correction.speaker {
            case .me: speakers.append((.me, nil))
            case .participant(let number):
                guard let participant = participants[number] else { return false }
                speakers.append((.participant, participant))
            }
        }
        for (index, line) in lines.enumerated() {
            if line.originalText == nil {
                line.originalText = line.text
                line.originalSpeakerKind = line.speakerKind
                line.originalParticipantNumber = line.speakerKind == .participant ? line.participant?.number : nil
            }
            line.text = corrections[index].text
            line.speakerKind = speakers[index].kind
            line.participant = speakers[index].participant
        }
        return true
    }

    /// Ends the refinement of the call at once, if running: its process is terminated.
    func cancelRefinement(of callID: UUID) {
        runningRefinements.removeValue(forKey: callID)?.task.cancel()
    }

    // MARK: Events

    /// `user.TURN_OFF_REFINEMENT`: the calls being refined or waiting to be refined
    /// again become ready with their transcript as it was; the refinements in
    /// progress end at once.
    func turnOffRefinement() {
        for call in calls(in: [.refiningTranscript, .awaitingRefinementRetry]) {
            cancelRefinement(of: call.id)
            apply(.turnOffRefinement, to: call)
        }
    }

    // MARK: User actions

    /// Whether "Rifinisci testo" applies: refinement is on and the call is Ready or
    /// waiting to be refined again.
    func canRefine(_ call: Call) -> Bool {
        CallStateMachine.target(from: call.state, on: .refineTranscript(refinementOn: refinementIsOn())) != nil
    }

    /// Whether "Ripristina originale" applies: the call has been refined, also while
    /// refinement is off.
    func canRestore(_ call: Call) -> Bool {
        CallStateMachine.target(from: call.state, on: .restoreTranscript(refined: call.isRefined)) != nil
    }

    /// `user.REFINE_TRANSCRIPT`.
    func refineTranscript(_ call: Call) {
        apply(.refineTranscript(refinementOn: refinementIsOn()), to: call)
    }

    /// `user.RESTORE_TRANSCRIPT`: every line gets back its original text and speaker,
    /// which are cleared; the call is refined again only when the user asks.
    func restoreTranscript(_ call: Call) {
        let event = CallEvent.restoreTranscript(refined: call.isRefined)
        guard CallStateMachine.target(from: call.state, on: event) != nil else { return }
        restoreOriginals(of: call)
        apply(event, to: call)
    }

    /// The effect of `RESTORE_TRANSCRIPT`.
    private func restoreOriginals(of call: Call) {
        let participants = Dictionary(call.participants.map { ($0.number, $0) }, uniquingKeysWith: { first, _ in first })
        for line in call.lines {
            guard let text = line.originalText else { continue }
            line.text = text
            let kind = line.originalSpeakerKind ?? line.speakerKind
            line.speakerKind = kind
            line.participant = kind == .participant ? line.originalParticipantNumber.flatMap { participants[$0] } : nil
            line.originalText = nil
            line.originalSpeakerKind = nil
            line.originalParticipantNumber = nil
        }
    }
}

extension Call {
    /// A call is refined when its lines hold an original.
    var isRefined: Bool {
        lines.contains { $0.originalText != nil }
    }
}
