import Foundation

/// Starting omp as an ACP agent.
enum Omp {
    /// Time omp has to answer `initialize`.
    static let initializeTimeout: Duration = .seconds(10)

    /// Runs `body` with a new empty temporary folder, deleted afterwards. omp
    /// starts there, so it cannot see any other file.
    static func withWorkingDirectory<T>(_ body: (URL) async throws -> T) async throws -> T {
        let directory = FileManager.default.temporaryDirectory
            .appending(path: "LARP-omp-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        return try await body(directory)
    }

    /// Starts `omp acp` in `workingDirectory` with the built-in tools disabled
    /// and no saved session (`--no-tools`, `--no-session`), or without those
    /// options when omp does not accept them, and waits for the answer to
    /// `initialize`. Returns the client ready to open a session; the caller
    /// terminates it. Nothing is left running when this throws:
    /// `ACPError.timedOut` when omp does not answer in `timeout`.
    static func open(
        executable: URL, workingDirectory: URL, timeout: Duration = initializeTimeout
    ) async throws -> ACPClient {
        let deadline = ContinuousClock.now + timeout
        do {
            return try await start(
                executable, ["acp", "--no-tools", "--no-session"], workingDirectory, deadline)
        } catch ACPError.processEnded {
            // omp ended at once: it does not accept the options.
            return try await start(executable, ["acp"], workingDirectory, deadline)
        }
    }

    private static func start(
        _ executable: URL, _ arguments: [String], _ workingDirectory: URL,
        _ deadline: ContinuousClock.Instant
    ) async throws -> ACPClient {
        let client = try ACPClient.launch(
            executable: executable, arguments: arguments, workingDirectory: workingDirectory)
        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await client.initialize() }
                group.addTask {
                    try await Task.sleep(until: deadline, clock: ContinuousClock())
                    throw ACPError.timedOut
                }
                try await group.next()
                group.cancelAll()
            }
        } catch {
            client.terminate()
            throw error
        }
        return client
    }
}

/// Finds out whether the assistant (omp) can be reached. Replaceable in tests.
protocol AssistantChecking: Sendable {
    /// `true` when omp is found and answers: `assistant.REACHED`; `false`
    /// otherwise: `assistant.UNREACHABLE`.
    func check() async -> Bool
}

/// Looks omp up, starts it, sends `initialize` and ends the process: an answer
/// within 10 seconds means omp is reached; omp not found, an error or no answer
/// in time mean it is unreachable.
struct OmpAssistantCheck: AssistantChecking {
    var locator: any OmpLocating = LoginShellOmpLocator()
    var timeout: Duration = Omp.initializeTimeout

    func check() async -> Bool {
        guard let executable = await locator.locate() else { return false }
        let reached = try? await Omp.withWorkingDirectory { directory in
            let client = try await Omp.open(
                executable: executable, workingDirectory: directory, timeout: timeout)
            client.terminate()
            return true
        }
        return reached == true
    }
}
