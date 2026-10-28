import Foundation
import Synchronization
import Testing

@testable import LARP

// MARK: Fakes

/// An assistant check whose answer, and the moment of the answer, the test
/// controls.
private final class FakeAssistantCheck: AssistantChecking {
    private let reached = Mutex(true)
    private let calls = Mutex(0)
    private let completed = Mutex(0)
    private let gate = Mutex<CheckedContinuation<Void, Never>?>(nil)
    private let held = Mutex(false)

    var callCount: Int { calls.withLock { $0 } }
    /// How many checks have given their answer.
    var completedCount: Int { completed.withLock { $0 } }

    func setReached(_ value: Bool) { reached.withLock { $0 = value } }

    /// The next checks wait until `release()`.
    func hold() { held.withLock { $0 = true } }

    func release() {
        held.withLock { $0 = false }
        gate.withLock { $0 }?.resume()
        gate.withLock { $0 = nil }
    }

    func check() async -> Bool {
        calls.withLock { $0 += 1 }
        if held.withLock({ $0 }) {
            await withCheckedContinuation { continuation in
                if held.withLock({ $0 }) {
                    gate.withLock { $0 = continuation }
                } else {
                    continuation.resume()
                }
            }
        }
        completed.withLock { $0 += 1 }
        return reached.withLock { $0 }
    }
}

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
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

// MARK: Machine

@Suite("TranscriptRefinement machine", .serialized)
@MainActor
struct TranscriptRefinementMachineTests {
    @Test("refinement is off by default and no omp is looked for")
    func offByDefault() async {
        let assistant = FakeAssistantCheck()
        let controller = TranscriptRefinementController(defaults: makeDefaults(), assistant: assistant)
        #expect(controller.state == .off)
        #expect(controller.isOn == false)
        controller.appLaunched()
        controller.openSettings()
        await controller.waitUntilIdle()
        #expect(controller.state == .off)
        #expect(assistant.callCount == 0)
    }

    @Test("turning on enters Checking, then Assistant ready when omp is reached")
    func turnOnReached() async {
        let assistant = FakeAssistantCheck()
        assistant.hold()
        let defaults = makeDefaults()
        let controller = TranscriptRefinementController(defaults: defaults, assistant: assistant)
        controller.turnOn()
        #expect(controller.state == .checking)
        #expect(controller.isOn)
        #expect(defaults.bool(forKey: SettingsKey.transcriptRefinement))
        assistant.release()
        await controller.waitUntilIdle()
        #expect(controller.state == .assistantReady)
    }

    @Test("an assistant that is not reached goes to Assistant missing")
    func turnOnUnreachable() async {
        let assistant = FakeAssistantCheck()
        assistant.setReached(false)
        let controller = TranscriptRefinementController(defaults: makeDefaults(), assistant: assistant)
        controller.turnOn()
        await controller.waitUntilIdle()
        #expect(controller.state == .assistantMissing)
        #expect(controller.isOn)
    }

    @Test("turning off goes to Off, is stored and ignores the check in progress")
    func turnOff() async {
        let assistant = FakeAssistantCheck()
        assistant.hold()
        let defaults = makeDefaults()
        let controller = TranscriptRefinementController(defaults: defaults, assistant: assistant)
        controller.turnOn()
        controller.turnOff()
        #expect(controller.state == .off)
        #expect(defaults.bool(forKey: SettingsKey.transcriptRefinement) == false)
        assistant.release()
        await waitUntil { assistant.completedCount == 1 }
        #expect(controller.state == .off)
    }

    @Test("opening the settings and launching the app look for omp again while on")
    func lookForAssistantAgain() async {
        let assistant = FakeAssistantCheck()
        assistant.setReached(false)
        let controller = TranscriptRefinementController(defaults: makeDefaults(), assistant: assistant)
        controller.turnOn()
        await controller.waitUntilIdle()
        #expect(controller.state == .assistantMissing)

        assistant.setReached(true)
        controller.openSettings()
        #expect(controller.state == .checking)
        await controller.waitUntilIdle()
        #expect(controller.state == .assistantReady)

        assistant.setReached(false)
        controller.appLaunched()
        #expect(controller.state == .checking)
        await controller.waitUntilIdle()
        #expect(controller.state == .assistantMissing)
        #expect(assistant.callCount == 3)
    }

    @Test("a stored switch is on at the next launch, which checks omp")
    func storedSwitchIsRestored() async {
        let defaults = makeDefaults()
        defaults.set(true, forKey: SettingsKey.transcriptRefinement)
        let assistant = FakeAssistantCheck()
        let controller = TranscriptRefinementController(defaults: defaults, assistant: assistant)
        #expect(controller.state == .checking)
        controller.appLaunched()
        await controller.waitUntilIdle()
        #expect(controller.state == .assistantReady)
    }

    @Test("turning on while already on does nothing")
    func turnOnTwice() async {
        let assistant = FakeAssistantCheck()
        let controller = TranscriptRefinementController(defaults: makeDefaults(), assistant: assistant)
        controller.turnOn()
        await controller.waitUntilIdle()
        controller.turnOn()
        #expect(controller.state == .assistantReady)
        #expect(assistant.callCount == 1)
    }

    @Test("the status of omp is shown only while refinement is on")
    func assistantStatusTexts() {
        #expect(SettingsView.assistantText(.off) == nil)
        #expect(SettingsView.assistantText(.checking) == "Verifica in corso…")
        #expect(SettingsView.assistantText(.assistantReady) == "omp pronto")
        #expect(SettingsView.assistantText(.assistantMissing) == "omp non trovato")
    }
}

// MARK: ACP client

/// A temporary folder with fake agents written as shell scripts.
private final class FakeAgents {
    let directory: URL

    init() throws {
        directory = FileManager.default.temporaryDirectory
            .appending(path: "LARPTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: directory) }

    var log: URL { directory.appending(path: "received.log") }
    var workingDirectoryFile: URL { directory.appending(path: "cwd.txt") }

    var receivedLines: [String] {
        ((try? String(contentsOf: log, encoding: .utf8)) ?? "")
            .split(separator: "\n").map(String.init)
    }

    func script(_ name: String, _ body: String) throws -> URL {
        let url = directory.appending(path: name)
        try "#!/bin/sh\n\(body)\n".write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: url.path)
        return url
    }

    /// An agent that answers `initialize`, `session/new` and `session/prompt`
    /// like omp does. `rejectsOptions`: ends at once when given `--no-tools`.
    func agent(rejectsOptions: Bool = false) throws -> URL {
        try script(
            "agent.sh",
            #"""
            dir=$(dirname "$0")
            pwd > "$dir/cwd.txt"
            if [ "\#(rejectsOptions)" = "true" ]; then
              for a in "$@"; do [ "$a" = "--no-tools" ] && exit 2; done
            fi
            while IFS= read -r line; do
              printf '%s\n' "$line" >> "$dir/received.log"
              id=$(printf '%s' "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
              case "$line" in
                *'"method":"initialize"'*)
                  printf '{"jsonrpc":"2.0","id":50,"method":"fs/read_text_file","params":{}}\n'
                  printf '{"jsonrpc":"2.0","id":%s,"result":{"protocolVersion":1}}\n' "$id" ;;
                *'"method":"session/new"'*)
                  printf '{"jsonrpc":"2.0","id":%s,"result":{"sessionId":"s1"}}\n' "$id" ;;
                *'"method":"session/prompt"'*)
                  printf '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{"sessionUpdate":"agent_thought_chunk","content":{"type":"text","text":"pensiero"}}}}\n'
                  printf '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"Ciao "}}}}\n'
                  printf '{"jsonrpc":"2.0","id":99,"method":"session/request_permission","params":{"sessionId":"s1","options":[{"optionId":"yes","kind":"allow_once"},{"optionId":"no","kind":"reject_once"}]}}\n'
                  IFS= read -r reply
                  printf '%s\n' "$reply" >> "$dir/received.log"
                  printf '{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"s1","update":{"sessionUpdate":"agent_message_chunk","content":{"type":"text","text":"mondo"}}}}\n'
                  printf '{"jsonrpc":"2.0","id":%s,"result":{"stopReason":"end_turn"}}\n' "$id" ;;
              esac
            done
            """#)
    }

    /// An agent that reads everything and never answers.
    func silentAgent() throws -> URL {
        try script("silent.sh", #"cat >> "$(dirname "$0")/received.log""#)
    }

    /// An agent that answers `initialize` with a JSON-RPC error.
    func failingAgent() throws -> URL {
        try script(
            "failing.sh",
            #"""
            IFS= read -r line
            id=$(printf '%s' "$line" | sed -E 's/.*"id":([0-9]+).*/\1/')
            printf '{"jsonrpc":"2.0","id":%s,"error":{"code":-32000,"message":"boom"}}\n' "$id"
            cat > /dev/null
            """#)
    }
}

private struct FixedLocator: OmpLocating {
    var url: URL?
    func locate() async -> URL? { url }
}

private func waitForLog(_ agents: FakeAgents, containing text: String) async -> Bool {
    for _ in 0..<400 {
        if agents.receivedLines.contains(where: { $0.contains(text) }) { return true }
        try? await Task.sleep(for: .milliseconds(5))
    }
    return false
}

@Suite("ACPClient", .serialized)
struct ACPClientTests {
    @Test("initialize declares no file system and no terminal")
    func initializeDeclaresNoCapabilities() async throws {
        let agents = try FakeAgents()
        let client = try ACPClient.launch(
            executable: try agents.agent(), arguments: [], workingDirectory: agents.directory)
        defer { client.terminate() }
        try await client.initialize()
        let initialize = try #require(agents.receivedLines.first { $0.contains("\"method\":\"initialize\"") })
        #expect(initialize.contains("\"terminal\":false"))
        #expect(initialize.contains("\"readTextFile\":false"))
        #expect(initialize.contains("\"writeTextFile\":false"))
    }

    @Test("requests of the agent for the file system are refused")
    func fileSystemIsNotOffered() async throws {
        let agents = try FakeAgents()
        let client = try ACPClient.launch(
            executable: try agents.agent(), arguments: [], workingDirectory: agents.directory)
        defer { client.terminate() }
        try await client.initialize()
        #expect(await waitForLog(agents, containing: "-32601"))
    }

    @Test("a session is opened, the prompt collects the agent messages and permissions are refused")
    func promptCollectsText() async throws {
        let agents = try FakeAgents()
        let client = try ACPClient.launch(
            executable: try agents.agent(), arguments: [], workingDirectory: agents.directory)
        defer { client.terminate() }
        try await client.initialize()
        let session = try await client.newSession(workingDirectory: agents.directory)
        #expect(session == "s1")
        let text = try await client.prompt(sessionID: session, text: "Rispondi")
        #expect(text == "Ciao mondo")
        let reply = try #require(agents.receivedLines.first { $0.contains("\"id\":99") })
        #expect(reply.contains("\"optionId\":\"no\""))
        #expect(reply.contains("\"outcome\":\"selected\""))
        let prompt = try #require(agents.receivedLines.first { $0.contains("\"method\":\"session/prompt\"") })
        #expect(prompt.contains("Rispondi"))
        #expect(!prompt.contains("model"))
    }

    @Test("an error answer fails the request")
    func rpcErrorFails() async throws {
        let agents = try FakeAgents()
        let client = try ACPClient.launch(
            executable: try agents.failingAgent(), arguments: [], workingDirectory: agents.directory)
        defer { client.terminate() }
        await #expect(throws: ACPError.rpc(code: -32000, message: "boom")) {
            try await client.initialize()
        }
    }

    @Test("terminating the process fails the request in flight")
    func terminateFailsPendingRequest() async throws {
        let agents = try FakeAgents()
        let client = try ACPClient.launch(
            executable: try agents.silentAgent(), arguments: [], workingDirectory: agents.directory)
        let request = Task { try await client.initialize() }
        #expect(await waitForLog(agents, containing: "\"method\":\"initialize\""))
        client.terminate()
        await #expect(throws: ACPError.processEnded) {
            try await request.value
        }
        await #expect(throws: ACPError.processEnded) {
            try await client.initialize()
        }
    }

    @Test("a process that ends on its own fails the request")
    func endedProcessFailsRequest() async throws {
        let agents = try FakeAgents()
        let client = try ACPClient.launch(
            executable: try agents.script("exit.sh", "exit 3"), arguments: [],
            workingDirectory: agents.directory)
        defer { client.terminate() }
        await #expect(throws: ACPError.processEnded) {
            try await client.initialize()
        }
    }
}

// MARK: Check of omp

@Suite("OmpAssistantCheck", .serialized)
struct OmpAssistantCheckTests {
    @Test("omp that answers initialize is reached, in an empty folder deleted afterwards")
    func reached() async throws {
        let agents = try FakeAgents()
        let check = OmpAssistantCheck(locator: FixedLocator(url: try agents.agent()))
        #expect(await check.check())
        let used = try String(contentsOf: agents.workingDirectoryFile, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        #expect(used.contains("LARP-omp-"))
        #expect(!FileManager.default.fileExists(atPath: used))
    }

    @Test("omp that does not accept the options is started without them")
    func optionsNotAccepted() async throws {
        let agents = try FakeAgents()
        let check = OmpAssistantCheck(locator: FixedLocator(url: try agents.agent(rejectsOptions: true)))
        #expect(await check.check())
    }

    @Test("omp not found is unreachable")
    func notFound() async {
        #expect(await OmpAssistantCheck(locator: FixedLocator(url: nil)).check() == false)
    }

    @Test("omp that does not answer in time is unreachable")
    func noAnswer() async throws {
        let agents = try FakeAgents()
        let check = OmpAssistantCheck(
            locator: FixedLocator(url: try agents.silentAgent()), timeout: .milliseconds(300))
        #expect(await check.check() == false)
    }

    @Test("omp that answers with an error is unreachable")
    func errorAnswer() async throws {
        let agents = try FakeAgents()
        let check = OmpAssistantCheck(locator: FixedLocator(url: try agents.failingAgent()))
        #expect(await check.check() == false)
    }
}

// MARK: Login shell lookup

@Suite("LoginShellOmpLocator", .serialized)
struct LoginShellOmpLocatorTests {
    @Test("asks the login shell for command -v omp and takes the last line")
    func findsOmp() async throws {
        let agents = try FakeAgents()
        let omp = try agents.script("omp", "exit 0")
        let shell = try agents.script(
            "shell.sh",
            """
            printf '%s\\n' "$*" > "\(agents.directory.path)/shell-args.txt"
            echo "banner of the profile"
            echo "\(omp.path)"
            """)
        let found = await LoginShellOmpLocator(shell: shell).locate()
        #expect(found?.path == omp.path)
        let arguments = try String(
            contentsOf: agents.directory.appending(path: "shell-args.txt"), encoding: .utf8)
        #expect(arguments == "-l -c command -v omp\n")
    }

    @Test("a shell that finds nothing, or something that is not a file, gives nil")
    func notFound() async throws {
        let agents = try FakeAgents()
        #expect(await LoginShellOmpLocator(shell: try agents.script("none.sh", "exit 1")).locate() == nil)
        #expect(
            await LoginShellOmpLocator(shell: try agents.script("alias.sh", "echo 'alias omp=foo'")).locate()
                == nil)
        #expect(
            await LoginShellOmpLocator(shell: try agents.script("gone.sh", "echo /nonexistent/omp")).locate()
                == nil)
    }
}
