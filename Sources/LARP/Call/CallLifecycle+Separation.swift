import Foundation
import os

extension CallLifecycle {
    private static var logger: Logger { Logger(subsystem: "com.larp.LARP", category: "separation") }

    /// The work of **Separating participants**: tells the participants apart and
    /// emits `PARTICIPANTS_SEPARATED`, or `SEPARATION_FAILED` when it could not be done.
    /// Starting again for a call replaces the separation in progress.
    func startSeparation(of call: Call) {
        guard let separator else { return }
        let id = call.id
        runningSeparations[id]?.task.cancel()
        separationCounter += 1
        let token = separationCounter
        let task = Task {
            do {
                try await separator.separate(call)
                try Task.checkCancellation()
                finishSeparation(callID: id, failed: false)
            } catch {
                // Stopped (deleted, replaced): not a failure, and the call is left alone.
                if !Task.isCancelled && !(error is CancellationError) {
                    Self.logger.error("Separation failed: \(error.localizedDescription, privacy: .public)")
                    finishSeparation(callID: id, failed: true)
                }
            }
            if runningSeparations[id]?.token == token {
                runningSeparations[id] = nil
            }
        }
        runningSeparations[id] = (token, task)
    }

    private func finishSeparation(callID: UUID, failed: Bool) {
        guard let call = call(id: callID), call.state == .separatingParticipants else { return }
        apply(failed ? .separationFailed : .participantsSeparated(refinementOn: refinementIsOn()), to: call)
        // The summary starts alongside the refinement, never waiting for it.
        if !failed {
            participantsSeparatedForSummary(call)
        }
    }

    /// Stops the separation of the call, if running. Its task stays registered until
    /// it has ended, so `waitUntilSeparationIdle()` covers it.
    func cancelSeparation(of callID: UUID) {
        runningSeparations[callID]?.task.cancel()
    }

    /// Resolves when no separation is running any more, the cancelled ones included.
    func waitUntilSeparationIdle() async {
        while let running = runningSeparations.values.first {
            await running.task.value
        }
    }

    /// `macos.NETWORK_AVAILABLE`: the calls that wait to try the separation, the
    /// refinement or the summary again do.
    func networkAvailable() {
        for call in calls(in: [.awaitingSeparationRetry, .awaitingRefinementRetry]) {
            apply(.networkAvailable, to: call)
        }
        for call in calls(summaryIn: [.awaitingRetry]) {
            applySummary(.networkAvailable, to: call)
        }
    }
}
