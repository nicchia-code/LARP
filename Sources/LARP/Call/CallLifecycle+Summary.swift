import Foundation
import SwiftData
import os

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "summary") }

    // MARK: Transitions

    /// Applies `event` to the summary of `call` following `CallSummaryStateMachine`: the new
    /// state is saved and, when the summary is being written, the work starts. Returns the
    /// new state, `nil` when the state does not react to the event (nothing changes).
    @discardableResult
    func applySummary(_ event: SummaryEvent, to call: Call) -> SummaryState? {
        guard let target = CallSummaryStateMachine.target(from: call.summaryState, on: event) else { return nil }
        call.summaryState = target
        save()
        if target == .writing {
            startSummary(of: call)
        }
        return target
    }

    // MARK: Work of Summarising

    /// The work of **Summarising**: sends the original lines of the call to the assistant,
    /// off the main actor, with its own process, and emits `SUMMARY_WRITTEN` once a valid
    /// summary has been saved, or `SUMMARY_FAILED` when it could not be written. Starting
    /// again for a call ends the summary in progress.
    func startSummary(of call: Call) {
        guard let summarizer else { return }
        let id = call.id
        runningSummaries[id]?.task.cancel()
        summaryCounter += 1
        let token = summaryCounter
        let request = SummaryRequest(call: call)
        let task = Task {
            do {
                // A line without participant is not sent: the summary fails.
                guard let request else { throw RefinementError.lineWithoutParticipant }
                let answer = try await summarizer.refine(prompt: request.prompt)
                try Task.checkCancellation()
                finishSummary(callID: id, answer: answer)
            } catch {
                // Stopped (turned off, deleted, replaced): not a failure.
                if !Task.isCancelled {
                    Self.logger.error("Summary failed: \(error.localizedDescription, privacy: .public)")
                    failSummary(callID: id)
                }
            }
            if runningSummaries[id]?.token == token {
                runningSummaries[id] = nil
            }
        }
        runningSummaries[id] = (token, task)
    }

    private func finishSummary(callID: UUID, answer: String) {
        guard let call = call(id: callID), call.summaryState == .writing else { return }
        let participants = Set(call.participants.map(\.number))
        guard let summary = SummaryRequest.summary(from: answer, participants: participants) else {
            Self.logger.error("The answer of the assistant is not a valid summary")
            applySummary(.summaryFailed, to: call)
            return
        }
        // The new summary replaces the earlier one in the same save as the new state.
        if let old = call.summary {
            call.summary = nil
            context.delete(old)
        }
        call.summary = CallSummary(
            keyConcepts: summary.keyConcepts,
            decisions: summary.decisions,
            nextSteps: summary.nextSteps,
            text: summary.text,
            language: call.transcriptionLanguage,
            writtenAt: now())
        applySummary(.summaryWritten, to: call)
    }

    private func failSummary(callID: UUID) {
        guard let call = call(id: callID), call.summaryState == .writing else { return }
        applySummary(.summaryFailed, to: call)
    }

    /// Ends the summary of the call at once, if running: its process is terminated. Its
    /// task stays registered until it has ended, so `waitUntilSummaryIdle()` covers it.
    func cancelSummary(of callID: UUID) {
        runningSummaries[callID]?.task.cancel()
    }

    /// Resolves when no summary is running any more, the cancelled ones included.
    func waitUntilSummaryIdle() async {
        while let running = runningSummaries.values.first {
            await running.task.value
        }
    }

    // MARK: Events

    /// The calls whose summary is in one of `states`, oldest first.
    func calls(summaryIn states: Set<SummaryState>) -> [Call] {
        let all = (try? context.fetch(FetchDescriptor<Call>(sortBy: [SortDescriptor(\.startedAt)]))) ?? []
        return all.filter { states.contains($0.summaryState) }
    }

    /// `call.PARTICIPANTS_SEPARATED`, for the summary: it starts on its own when call
    /// summaries are on and the transcript has at least one line.
    func participantsSeparatedForSummary(_ call: Call) {
        applySummary(.participantsSeparated(summariesOn: summariesAreOn(), hasLines: !call.lines.isEmpty), to: call)
    }

    /// `user.TURN_OFF_SUMMARY`: the summaries in progress end at once; the calls being
    /// summarised or waiting to be summarised again go back to what they were before, with
    /// their earlier summary when they had one.
    func turnOffSummary() {
        for call in calls(summaryIn: [.writing, .awaitingRetry]) {
            cancelSummary(of: call.id)
            applySummary(.turnOffSummary(hadSummary: call.summary != nil), to: call)
        }
    }

    // MARK: User actions

    /// Whether "Sintetizza" applies: the transcript has at least one line and the state
    /// of the summary allows it (summaries on, participants told apart, or a retry).
    func canSummarize(_ call: Call) -> Bool {
        CallSummaryStateMachine.target(from: call.summaryState, on: summarizeEvent(for: call)) != nil
    }

    /// `user.SUMMARIZE_CALL`.
    func summarize(_ call: Call) {
        applySummary(summarizeEvent(for: call), to: call)
    }

    private func summarizeEvent(for call: Call) -> SummaryEvent {
        .summarizeCall(
            summariesOn: summariesAreOn(),
            hasLines: !call.lines.isEmpty,
            participantsTold: call.participantsAreTold)
    }
}

extension Call {
    /// The participants have been told apart: the call is past the separation.
    var participantsAreTold: Bool {
        switch state {
        case .ready, .refiningTranscript, .awaitingRefinementRetry: true
        case .recording, .awaitingLanguage, .transcribing, .separatingParticipants, .awaitingSeparationRetry: false
        }
    }
}
