import Foundation
import Synchronization

/// Why the assistant could not be asked to refine a transcript, or why there was nothing to send.
enum RefinementError: Error, Equatable {
    /// omp is not on the Mac.
    case assistantNotFound
    /// A line of the others has no participant, so it cannot be sent as "Io" or "Partecipante <numero>".
    case lineWithoutParticipant
}

/// Asks the assistant for the corrected lines of a transcript. Replaceable in tests.
protocol TranscriptRefining: Sendable {
    /// Sends `prompt` to the assistant and returns the text of its answer. Runs off
    /// the main actor. Throws when the assistant is not found, does not answer, answers
    /// with an error, or does not answer completely within the time limit; throws when
    /// the calling task is cancelled, after ending the assistant's process at once.
    @concurrent func refine(prompt: String) async throws -> String
}

/// Refines through omp: every call starts its own `omp acp` process, opens one
/// session and sends one prompt (see `Omp` and `ACPClient`).
struct OmpTranscriptRefiner: TranscriptRefining {
    /// Time omp has, from the start of its process, to answer completely.
    static let timeLimit: Duration = .seconds(600)

    var locator: any OmpLocating = LoginShellOmpLocator()
    var timeLimit: Duration = Self.timeLimit

    @concurrent
    func refine(prompt: String) async throws -> String {
        guard let executable = await locator.locate() else { throw RefinementError.assistantNotFound }
        try Task.checkCancellation()
        let limit = timeLimit
        return try await Omp.withWorkingDirectory { directory in
            let process = RunningProcess()
            return try await withTaskCancellationHandler {
                try await withThrowingTaskGroup(of: String.self) { group in
                    group.addTask {
                        do {
                            let client = try await Omp.open(
                                executable: executable, workingDirectory: directory, timeout: limit)
                            guard process.adopt(client) else { throw CancellationError() }
                            let session = try await client.newSession(workingDirectory: directory)
                            return try await client.prompt(sessionID: session, text: prompt)
                        } catch {
                            // Ending the process at the limit fails the request in flight.
                            throw process.isTimedOut ? ACPError.timedOut : error
                        }
                    }
                    group.addTask {
                        try await Task.sleep(for: limit)
                        // The limit counts from the start of the process.
                        process.timeOut()
                        throw ACPError.timedOut
                    }
                    defer {
                        group.cancelAll()
                        process.terminate()
                    }
                    guard let answer = try await group.next() else { throw ACPError.malformedResponse }
                    return answer
                }
            } onCancel: {
                process.terminate()
            }
        }
    }
}

/// The client of a refinement, ended from whichever task asks first.
private final class RunningProcess: Sendable {
    private struct State {
        var client: ACPClient?
        var terminated = false
        var timedOut = false
    }

    private let state = Mutex(State())

    /// Takes the client to be ended with `terminate()`. `false` when it was already
    /// asked to end: the client is ended here.
    func adopt(_ client: ACPClient) -> Bool {
        let adopted = state.withLock { state -> Bool in
            guard !state.terminated else { return false }
            state.client = client
            return true
        }
        if !adopted { client.terminate() }
        return adopted
    }

    var isTimedOut: Bool { state.withLock { $0.timedOut } }

    /// The time limit passed: ends the process.
    func timeOut() {
        state.withLock { $0.timedOut = true }
        terminate()
    }

    func terminate() {
        let client = state.withLock { state -> ACPClient? in
            state.terminated = true
            return state.client
        }
        client?.terminate()
    }
}
