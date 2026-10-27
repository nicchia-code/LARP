import Foundation
import Synchronization

/// Why a request to the agent did not complete.
enum ACPError: Error, Equatable {
    /// The agent process ended, or was terminated, before answering.
    case processEnded
    /// The agent did not answer in time.
    case timedOut
    /// The agent answered with a JSON-RPC error.
    case rpc(code: Int, message: String)
    /// The answer of the agent does not have the expected shape.
    case malformedResponse
}

/// A client of the Agent Client Protocol (JSON-RPC 2.0, one message per line on
/// the standard input and output of the agent), spoken directly with
/// `Foundation.Process`.
///
/// The client declares no file system and no terminal capability, refuses every
/// `session/request_permission` and never chooses a model: the agent uses its
/// own default. `terminate()` ends the process at any time and fails every
/// request in flight.
final class ACPClient: @unchecked Sendable {
    private struct State {
        var nextID = 0
        var pending: [Int: CheckedContinuation<JSONValue, any Error>] = [:]
        /// Text of the agent messages of the prompt running, by session.
        var texts: [String: String] = [:]
        /// Bytes received that do not end a line yet.
        var buffer = Data()
        var isClosed = false
    }

    /// An incoming JSON-RPC message: a response, a request or a notification.
    private struct Incoming: Decodable {
        var id: JSONValue?
        var method: String?
        var params: JSONValue?
        var result: JSONValue?
        var error: JSONValue?
    }

    private let process: Process
    private let input: FileHandle
    private let state = Mutex(State())
    /// Serializes the writes to the agent's standard input.
    private let writeLock = Mutex(())

    private init(process: Process, input: FileHandle) {
        self.process = process
        self.input = input
    }

    /// Starts the agent `executable` with `arguments` in `workingDirectory`.
    static func launch(executable: URL, arguments: [String], workingDirectory: URL) throws -> ACPClient {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.currentDirectoryURL = workingDirectory
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        // A write to an agent that already ended must fail, not kill the app.
        _ = fcntl(stdin.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)

        let client = ACPClient(process: process, input: stdin.fileHandleForWriting)
        stdout.fileHandleForReading.readabilityHandler = { [weak client] handle in
            let data = handle.availableData
            if data.isEmpty {
                handle.readabilityHandler = nil
                client?.close(with: ACPError.processEnded)
            } else {
                client?.receive(data)
            }
        }
        try process.run()
        return client
    }

    // MARK: Protocol

    /// `initialize`: declares no file system and no terminal capability.
    func initialize() async throws {
        _ = try await request(
            "initialize",
            [
                "protocolVersion": .number(1),
                "clientCapabilities": .object([
                    "fs": .object(["readTextFile": .bool(false), "writeTextFile": .bool(false)]),
                    "terminal": .bool(false),
                ]),
                "clientInfo": .object(["name": .string("LARP"), "title": .string("LARP")]),
            ])
    }

    /// `session/new` in `workingDirectory`; returns the session identifier.
    func newSession(workingDirectory: URL) async throws -> String {
        let result = try await request(
            "session/new",
            [
                "cwd": .string(workingDirectory.path),
                "mcpServers": .array([]),
            ])
        guard let sessionID = result["sessionId"]?.stringValue else { throw ACPError.malformedResponse }
        return sessionID
    }

    /// `session/prompt`: sends `text` and returns the text of the agent's
    /// messages (`session/update`) received until the prompt ends.
    func prompt(sessionID: String, text: String) async throws -> String {
        state.withLock { $0.texts[sessionID] = "" }
        do {
            _ = try await request(
                "session/prompt",
                [
                    "sessionId": .string(sessionID),
                    "prompt": .array([.object(["type": .string("text"), "text": .string(text)])]),
                ])
        } catch {
            state.withLock { _ = $0.texts.removeValue(forKey: sessionID) }
            throw error
        }
        return state.withLock { $0.texts.removeValue(forKey: sessionID) ?? "" }
    }

    /// Ends the agent at any time: requests in flight fail with
    /// `ACPError.processEnded`. Safe to call more than once.
    func terminate() {
        close(with: ACPError.processEnded)
        try? input.close()
        guard process.isRunning else { return }
        process.terminate()
        let pid = process.processIdentifier
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [self] in
            if process.isRunning { kill(pid, SIGKILL) }
        }
    }

    // MARK: Requests

    private func request(_ method: String, _ params: [String: JSONValue]) async throws -> JSONValue {
        let id = state.withLock { state -> Int in
            state.nextID += 1
            return state.nextID
        }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let registered = state.withLock { state -> Bool in
                    guard !state.isClosed else { return false }
                    state.pending[id] = continuation
                    return true
                }
                guard registered else {
                    continuation.resume(throwing: ACPError.processEnded)
                    return
                }
                if Task.isCancelled {
                    fail(id, with: CancellationError())
                    return
                }
                do {
                    try send([
                        "jsonrpc": .string("2.0"), "id": .number(Double(id)),
                        "method": .string(method), "params": .object(params),
                    ])
                } catch {
                    fail(id, with: error)
                }
            }
        } onCancel: {
            fail(id, with: CancellationError())
        }
    }

    private func fail(_ id: Int, with error: any Error) {
        let continuation = state.withLock { $0.pending.removeValue(forKey: id) }
        continuation?.resume(throwing: error)
    }

    /// Marks the connection closed and fails every request in flight.
    private func close(with error: any Error) {
        let continuations = state.withLock { state -> [CheckedContinuation<JSONValue, any Error>] in
            state.isClosed = true
            defer { state.pending = [:] }
            return Array(state.pending.values)
        }
        for continuation in continuations {
            continuation.resume(throwing: error)
        }
    }

    private func send(_ message: [String: JSONValue]) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        var line = try encoder.encode(JSONValue.object(message))
        line.append(0x0A)
        try writeLock.withLock { _ in try input.write(contentsOf: line) }
    }

    // MARK: Incoming

    private func receive(_ data: Data) {
        let lines = state.withLock { state -> [Data] in
            state.buffer.append(data)
            var lines: [Data] = []
            while let newline = state.buffer.firstIndex(of: 0x0A) {
                lines.append(Data(state.buffer[state.buffer.startIndex..<newline]))
                state.buffer = Data(state.buffer[state.buffer.index(after: newline)...])
            }
            return lines
        }
        for line in lines where !line.isEmpty {
            handle(line)
        }
    }

    private func handle(_ line: Data) {
        guard let message = try? JSONDecoder().decode(Incoming.self, from: line) else { return }
        if let method = message.method {
            if let id = message.id {
                answer(request: method, id: id, params: message.params)
            } else if method == "session/update", let params = message.params {
                collect(update: params)
            }
        } else if let id = message.id, case .number(let number) = id {
            let continuation = state.withLock { $0.pending.removeValue(forKey: Int(number)) }
            if let error = message.error {
                continuation?.resume(
                    throwing: ACPError.rpc(
                        code: Int(error["code"]?.numberValue ?? 0),
                        message: error["message"]?.stringValue ?? ""))
            } else {
                continuation?.resume(returning: message.result ?? .null)
            }
        }
    }

    /// Adds the text of an agent message to the prompt running in its session.
    private func collect(update params: JSONValue) {
        guard let sessionID = params["sessionId"]?.stringValue,
            let update = params["update"],
            update["sessionUpdate"]?.stringValue == "agent_message_chunk",
            let content = update["content"],
            content["type"]?.stringValue == "text",
            let text = content["text"]?.stringValue
        else { return }
        state.withLock { state in
            if state.texts[sessionID] != nil { state.texts[sessionID]?.append(text) }
        }
    }

    /// Answers a request of the agent: every permission is refused, every other
    /// method (file system, terminal) is not offered.
    private func answer(request method: String, id: JSONValue, params: JSONValue?) {
        var reply: [String: JSONValue] = ["jsonrpc": .string("2.0"), "id": id]
        if method == "session/request_permission" {
            reply["result"] = .object(["outcome": Self.refusal(of: params?["options"]?.arrayValue ?? [])])
        } else {
            reply["error"] = .object(["code": .number(-32601), "message": .string("Method not found")])
        }
        try? send(reply)
    }

    /// The outcome refusing a permission: the option of kind `reject_once` or
    /// `reject_always` when there is one, otherwise the request is cancelled.
    private static func refusal(of options: [JSONValue]) -> JSONValue {
        for kind in ["reject_once", "reject_always"] {
            if let option = options.first(where: { $0["kind"]?.stringValue == kind }),
                let optionID = option["optionId"]?.stringValue
            {
                return .object(["outcome": .string("selected"), "optionId": .string(optionID)])
            }
        }
        return .object(["outcome": .string("cancelled")])
    }
}
