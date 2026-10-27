import Foundation
import SwiftData
import Testing

@testable import LARP

@Suite("Call transcription from file", .serialized)
@MainActor
struct CallTranscriptionTests {
    private static let mine = [
        TranscribedLine(speaker: .me, start: 0, end: 2, text: "Ciao a tutti"),
        TranscribedLine(speaker: .me, start: 6, end: 7, text: "Va bene"),
    ]
    private static let others = [
        TranscribedLine(speaker: .others, start: 2.5, end: 5, text: "Buongiorno"),
        TranscribedLine(speaker: .others, start: 7.5, end: 9, text: "Allora iniziamo"),
    ]

    private func script(_ harness: CallHarness) {
        harness.transcription.set {
            $0.fileLines = [.me: Self.mine, .others: Self.others]
        }
    }

    // MARK: Transitions

    @Test("Awaiting language moves to Transcribing when its language is ready, and Transcribing to Separating participants")
    func transitionTable() {
        #expect(CallStateMachine.target(from: .awaitingLanguage, on: .languageReady) == .state(.transcribing))
        #expect(CallStateMachine.target(from: .transcribing, on: .transcriptionCompleted) == .state(.separatingParticipants))
        #expect(CallStateMachine.target(from: .transcribing, on: .appLaunched(languageReady: true)) == .state(.transcribing))
        #expect(CallStateMachine.target(from: .ready, on: .languageReady) == nil)
        #expect(CallStateMachine.target(from: .recording, on: .transcriptionCompleted) == nil)
    }

    @Test("a call awaiting its language is transcribed when the language becomes ready")
    func languageReadyStartsTranscription() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        script(harness)
        let call = try harness.insertCall(.awaitingLanguage)

        harness.lifecycle.languageReady("it-IT")
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(call.state == .separatingParticipants)
        #expect(call.lines.sorted { $0.start < $1.start }.map(\.text) == ["Ciao a tutti", "Buongiorno", "Va bene", "Allora iniziamo"])
    }

    @Test("a language that becomes ready leaves the calls awaiting another language alone")
    func otherLanguageIsIgnored() async throws {
        let harness = try CallHarness(readyLanguages: [])
        defer { harness.cleanUp() }
        let italian = try harness.insertCall(.awaitingLanguage, language: "it-IT")
        let english = try harness.insertCall(.awaitingLanguage, language: "en-US")
        harness.transcription.set { $0.blocksFiles = true }

        harness.lifecycle.languageReady("en-US")

        #expect(italian.state == .awaitingLanguage)
        #expect(english.state == .transcribing)
        harness.lifecycle.deleteCall(english)
        await harness.lifecycle.waitUntilTranscriptionIdle()
    }

    // MARK: Transcribing

    @Test("both tracks are transcribed from the saved audio, the microphone as Me and the system audio as Others, merged by start time")
    func bothTracksMerged() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        script(harness)
        let call = try harness.insertCall(.awaitingLanguage)

        harness.lifecycle.languageReady("it-IT")
        await harness.lifecycle.waitUntilTranscriptionIdle()

        let files = Set(harness.transcription.transcribedFiles.map(\.lastPathComponent))
        #expect(files == ["mic.caf", "system.caf"])
        let lines = call.lines.sorted { $0.start < $1.start }
        #expect(lines.map(\.speakerKind) == [.me, .others, .me, .others])
        #expect(lines.map(\.speakerName) == ["Io", "Altri", "Io", "Altri"])
        #expect(lines.map(\.start) == [0, 2.5, 6, 7.5])
        #expect(lines.map(\.end) == [2, 5, 7, 9])
        #expect(call.state == .separatingParticipants)
    }

    @Test("a call that is not awaiting does not change when its language becomes ready")
    func readyCallUnaffected() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        harness.lifecycle.languageReady("it-IT")
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(call.state == .ready)
        #expect(harness.transcription.transcribedFiles.isEmpty)
    }

    @Test("after the app was closed during the transcription it starts again from the beginning, without the partial lines")
    func restartAfterClose() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        script(harness)
        let call = try harness.insertCall(.transcribing)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "riga parziale"))
        try harness.context.save()

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(call.state == .separatingParticipants)
        #expect(call.lines.count == 4)
        #expect(!call.lines.contains { $0.text == "riga parziale" })
    }

    @Test("calls waiting are transcribed one at a time, the oldest first")
    func oneAtATimeOldestFirst() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        script(harness)
        let newest = try harness.insertCall(.transcribing, startedAt: Date(timeIntervalSince1970: 1_700_003_000))
        let oldest = try harness.insertCall(.transcribing, startedAt: Date(timeIntervalSince1970: 1_700_001_000))
        let middle = try harness.insertCall(.transcribing, startedAt: Date(timeIntervalSince1970: 1_700_002_000))

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(
            harness.transcription.startedFolders == [
                oldest.recordingsFolderURL, middle.recordingsFolderURL, newest.recordingsFolderURL,
            ])
        #expect([oldest, middle, newest].allSatisfy { $0.state == .separatingParticipants })
    }

    @Test("a transcription that fails leaves the call in Transcribing, shown as failed")
    func failureKeepsTranscribing() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.transcription.set { $0.fileFailure = FakeTranscriptionFailure() }
        let call = try harness.insertCall(.transcribing)

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(call.state == .transcribing)
        #expect(call.lines.isEmpty)
        #expect(harness.lifecycle.failedTranscriptions == [call.id])
        #expect(
            harness.lifecycle.statusLabel(of: call) == "Trascrizione non riuscita, nuovo tentativo a breve")
    }

    @Test("a call that is transcribing without having failed shows the usual label")
    func noFailureUsualLabel() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.transcribing)

        #expect(harness.lifecycle.statusLabel(of: call) == "Trascrizione…")
    }

    @Test("a failed transcription is tried again by itself after the wait and, once it succeeds, the failure is gone")
    func failureRetried() async throws {
        let harness = try CallHarness(transcriptionRetryDelay: .milliseconds(50))
        defer { harness.cleanUp() }
        harness.transcription.set { $0.fileFailure = FakeTranscriptionFailure() }
        let call = try harness.insertCall(.transcribing)

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilTranscriptionIdle()
        #expect(harness.lifecycle.failedTranscriptions == [call.id])

        script(harness)
        harness.transcription.set { $0.fileFailure = nil }
        #expect(await harness.eventually { call.state == .separatingParticipants })

        #expect(call.lines.count == 4)
        #expect(harness.lifecycle.failedTranscriptions.isEmpty)
        #expect(harness.lifecycle.statusLabel(of: call) == CallState.separatingParticipants.statusLabel)
    }

    @Test("a call that failed and was deleted is not tried again")
    func failedThenDeleted() async throws {
        let harness = try CallHarness(transcriptionRetryDelay: .milliseconds(50))
        defer { harness.cleanUp() }
        harness.transcription.set { $0.fileFailure = FakeTranscriptionFailure() }
        let call = try harness.insertCall(.transcribing)

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilTranscriptionIdle()
        harness.lifecycle.deleteCall(call)
        let attempts = harness.transcription.transcribedFiles.count
        try await Task.sleep(for: .milliseconds(200))

        #expect(harness.transcription.transcribedFiles.count == attempts)
        #expect(harness.lifecycle.failedTranscriptions.isEmpty)
    }

    @Test("a call that was deleted while transcribed does not come back")
    func deletedWhileTranscribing() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.transcription.set { $0.blocksFiles = true }
        let call = try harness.insertCall(.transcribing)

        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { harness.transcription.transcribedFiles.count == 2 })
        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(try harness.allCalls().isEmpty)
        #expect(harness.transcription.cancelledFiles == 2)
    }

    // MARK: Hand-over to the separation

    @Test("a transcribed call is handed to the separation of participants and becomes Ready")
    func separationFollows() async throws {
        let separator = FakeSeparator(.succeed)
        let harness = try CallHarness(separator: separator)
        defer { harness.cleanUp() }
        script(harness)
        let call = try harness.insertCall(.transcribing)

        await harness.lifecycle.appLaunched()
        await harness.lifecycle.waitUntilTranscriptionIdle()
        #expect(await harness.eventually { call.state == .ready })

        #expect(separator.startedCallIDs == [call.id])
    }
}
