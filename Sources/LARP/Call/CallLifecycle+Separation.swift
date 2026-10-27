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
                finishSeparation(callID: id, failed: false)
            } catch is CancellationError {
                // Cancelled or deleted: not a failure.
            } catch {
                Self.logger.error("Separation failed: \(error.localizedDescription, privacy: .public)")
                finishSeparation(callID: id, failed: true)
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
    }

    /// Stops the separation of the call, if running.
    func cancelSeparation(of callID: UUID) {
        runningSeparations.removeValue(forKey: callID)?.task.cancel()
    }

    /// `macos.NETWORK_AVAILABLE`: the calls that wait to try the separation or the
    /// refinement again do.
    func networkAvailable() {
        for call in calls(in: [.awaitingSeparationRetry, .awaitingRefinementRetry]) {
            apply(.networkAvailable, to: call)
        }
    }
}
