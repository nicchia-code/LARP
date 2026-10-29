import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

/// A refiner that waits for the gate, whether or not it is cancelled, then answers or fails.
private final class GatedRefiner: TranscriptRefining {
    private let gate: WorkGate
    private let fails: Bool
    private let startedCount = Mutex(0)

    init(gate: WorkGate, fails: Bool) {
        self.gate = gate
        self.fails = fails
    }

    var started: Int { startedCount.withLock { $0 } }

    @concurrent
    func refine(prompt: String) async throws -> String {
        startedCount.withLock { $0 += 1 }
        await gate.wait()
        if fails { throw FakeTranscriptionFailure() }
        return #"[{"number": 1, "text": "Ciao", "speaker": "Io"}, {"number": 2, "text": "Buongiorno", "speaker": "Partecipante 1"}]"#
    }
}

/// Deleting a call while its transcription, the separation of its participants, its
/// refinement or its summary runs (`requirements/quality#call`). The work ends only after the call is
/// deleted, with the result or the failure the test chooses, and after the test has let
/// go of the archive: the situation that crashed the test process on the CI runner,
/// where the work of a deleted call read the archive once nothing else held it.
@Suite("deleting a call during background work", .serialized)
@MainActor
struct CallDeletionDuringWorkTests {
    /// How the work of the deleted call ends once the gate opens.
    enum Ending: String, CaseIterable, CustomTestStringConvertible {
        case succeeds
        case fails

        var testDescription: String { rawValue }
    }

    /// Waits for the effect through `harness`, without keeping hold of it afterwards.
    private func eventually(_ harness: CallHarness?, _ condition: () -> Bool) async -> Bool {
        guard let harness else { return false }
        return await harness.eventually(condition)
    }

    private func allCalls(_ lifecycle: CallLifecycle) throws -> [Call] {
        try lifecycle.context.fetch(FetchDescriptor<Call>())
    }

    @Test("transcription: the call stays deleted and nothing is read or written when the work ends", arguments: Ending.allCases)
    func transcription(ending: Ending) async throws {
        let gate = WorkGate()
        var harness: CallHarness? = try CallHarness()
        let lifecycle = try #require(harness).lifecycle
        let transcription = try #require(harness).transcription
        transcription.set {
            $0.fileGate = gate
            $0.fileFailure = ending == .fails ? FakeTranscriptionFailure() : nil
            $0.fileLines = [.me: [TranscribedLine(speaker: .me, start: 0, end: 1, text: "Ciao")]]
        }
        let call = try #require(harness).insertCall(.transcribing)
        let folder = call.recordingsFolderURL
        defer { try? FileManager.default.removeItem(at: folder) }

        await lifecycle.appLaunched()
        #expect(await eventually(harness) { transcription.transcribedFiles.count == 2 })

        lifecycle.deleteCall(call)
        harness = nil
        gate.open()
        await lifecycle.waitUntilTranscriptionIdle()

        #expect(try allCalls(lifecycle).isEmpty)
        #expect(lifecycle.failedTranscriptions.isEmpty)
        #expect(lifecycle.transcriptionRetries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("separation: the call stays deleted and nothing is read or written when the work ends", arguments: Ending.allCases)
    func separation(ending: Ending) async throws {
        let gate = WorkGate()
        let separator = FakeSeparator(.held(gate, fails: ending == .fails))
        var harness: CallHarness? = try CallHarness(separator: separator)
        let lifecycle = try #require(harness).lifecycle
        let call = try #require(harness).insertCall(.separatingParticipants)
        let folder = call.recordingsFolderURL
        defer { try? FileManager.default.removeItem(at: folder) }

        await lifecycle.appLaunched()
        #expect(await eventually(harness) { separator.startedCallIDs.count == 1 })

        lifecycle.deleteCall(call)
        harness = nil
        gate.open()
        await lifecycle.waitUntilSeparationIdle()

        #expect(try allCalls(lifecycle).isEmpty)
        #expect(lifecycle.runningSeparations.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("refinement: the call stays deleted and nothing is read or written when the work ends", arguments: Ending.allCases)
    func refinement(ending: Ending) async throws {
        let gate = WorkGate()
        let refiner = GatedRefiner(gate: gate, fails: ending == .fails)
        var harness: CallHarness? = try CallHarness(refiner: refiner, refinementOn: true)
        let lifecycle = try #require(harness).lifecycle
        let call = try #require(harness).insertCall(.refiningTranscript)
        let participant = Participant(number: 1)
        call.participants.append(participant)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "Ciao"))
        call.lines.append(TranscriptLine(speakerKind: .participant, participant: participant, start: 1, end: 2, text: "Buongiorno"))
        try lifecycle.context.save()
        let folder = call.recordingsFolderURL
        defer { try? FileManager.default.removeItem(at: folder) }

        await lifecycle.appLaunched()
        #expect(await eventually(harness) { refiner.started == 1 })

        lifecycle.deleteCall(call)
        harness = nil
        gate.open()
        await lifecycle.waitUntilRefinementIdle()

        #expect(try allCalls(lifecycle).isEmpty)
        #expect(lifecycle.runningRefinements.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("summary: the process is ended, the call stays deleted and nothing is saved when the work ends", arguments: Ending.allCases)
    func summary(ending: Ending) async throws {
        let gate = WorkGate()
        let answer = #"{"keyConcepts": ["Budget"], "decisions": [], "nextSteps": [{"text": "Scrivere", "owner": "Partecipante 1"}], "other": ""}"#
        let summarizer = FakeSummarizer(.held(gate, answer: ending == .fails ? nil : answer))
        var harness: CallHarness? = try CallHarness(summarizer: summarizer, summariesOn: true)
        let lifecycle = try #require(harness).lifecycle
        let call = try #require(harness).insertCall(.ready)
        let participant = Participant(number: 1)
        call.participants.append(participant)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "Ciao"))
        call.lines.append(TranscriptLine(speakerKind: .participant, participant: participant, start: 1, end: 2, text: "Buongiorno"))
        try lifecycle.context.save()
        let folder = call.recordingsFolderURL
        defer { try? FileManager.default.removeItem(at: folder) }

        lifecycle.summarize(call)
        #expect(await eventually(harness) { summarizer.prompts.count == 1 })

        lifecycle.deleteCall(call)
        harness = nil
        gate.open()
        await lifecycle.waitUntilSummaryIdle()

        // The summary was cancelled, which ends its process, before it came to an end.
        #expect(summarizer.endedCancelledCount == 1)
        #expect(try allCalls(lifecycle).isEmpty)
        #expect(try lifecycle.context.fetch(FetchDescriptor<CallSummary>()).isEmpty)
        #expect(lifecycle.runningSummaries.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }
}
