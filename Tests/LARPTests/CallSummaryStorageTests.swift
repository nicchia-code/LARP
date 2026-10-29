import Foundation
import SwiftData
import Testing

@testable import LARP

/// The store as it was saved before summaries existed: the same three entities, without
/// `CallSummary` and without the summary state of the call.
private enum LegacyStore {
    @Model
    final class Call {
        @Attribute(.unique) var id: UUID
        var title: String?
        var startedAt: Date
        var endedAt: Date?
        var duration: TimeInterval
        var callAppName: String?
        var transcriptionLanguage: String
        var stateRawValue: String
        var micAudioPath: String
        var systemAudioPath: String

        @Relationship(deleteRule: .cascade, inverse: \TranscriptLine.call)
        var lines: [TranscriptLine] = []

        @Relationship(deleteRule: .cascade, inverse: \Participant.call)
        var participants: [Participant] = []

        init(id: UUID, title: String?, state: String) {
            self.id = id
            self.title = title
            self.startedAt = .now
            self.duration = 60
            self.transcriptionLanguage = "it-IT"
            self.stateRawValue = state
            self.micAudioPath = "Recordings/\(id.uuidString)/mic.caf"
            self.systemAudioPath = "Recordings/\(id.uuidString)/system.caf"
        }
    }

    @Model
    final class TranscriptLine {
        var speakerKindRawValue: String
        var participant: Participant?
        var start: TimeInterval
        var end: TimeInterval
        var text: String
        var call: Call?
        var originalText: String?
        var originalSpeakerKindRawValue: String?
        var originalParticipantNumber: Int?

        init(text: String) {
            self.speakerKindRawValue = "me"
            self.start = 0
            self.end = 1
            self.text = text
        }
    }

    @Model
    final class Participant {
        var number: Int
        var name: String?
        var call: Call?

        @Relationship(deleteRule: .nullify, inverse: \TranscriptLine.participant)
        var lines: [TranscriptLine] = []

        init(number: Int) {
            self.number = number
        }
    }

    static let schema = Schema([Call.self, TranscriptLine.self, Participant.self])
}

@Suite("Call summary storage", .serialized)
@MainActor
struct CallSummaryStorageTests {
    @Test("a new call has no summary and its summary state is none")
    func newCallHasNoSummary() throws {
        let call = Call(transcriptionLanguage: "it-IT")
        #expect(call.summary == nil)
        #expect(call.summaryState == .none)
    }

    @Test("a summary is stored on the call as the assistant wrote it, in order")
    func storesSummary() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let writtenAt = Date(timeIntervalSince1970: 1_700_000_000)

        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        call.summary = CallSummary(
            keyConcepts: ["Budget", "Scadenze"],
            decisions: ["Si parte a marzo", "Assumere due persone"],
            nextSteps: [
                SummaryNextStep(text: "Inviare il piano", owner: "Io"),
                SummaryNextStep(text: "Prenotare la sala", owner: "Partecipante 2"),
                SummaryNextStep(text: "Rivedere il contratto"),
            ],
            text: "Riunione sul lancio.",
            language: "it-IT",
            writtenAt: writtenAt
        )
        call.summaryState = .written
        context.insert(call)
        try context.save()

        let stored = try #require(try context.fetch(FetchDescriptor<Call>()).first)
        #expect(stored.summaryState == .written)
        let summary = try #require(stored.summary)
        #expect(summary.keyConcepts == ["Budget", "Scadenze"])
        #expect(summary.decisions == ["Si parte a marzo", "Assumere due persone"])
        #expect(summary.nextSteps.map(\.text) == ["Inviare il piano", "Prenotare la sala", "Rivedere il contratto"])
        #expect(summary.nextSteps.map(\.owner) == ["Io", "Partecipante 2", nil])
        #expect(summary.text == "Riunione sul lancio.")
        #expect(summary.language == "it-IT")
        #expect(summary.writtenAt == writtenAt)
        #expect(summary.call === stored)
    }

    @Test("every summary state is kept apart from the call state")
    func summaryStateIsSeparateFromCallState() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext

        for summaryState in SummaryState.allCases {
            let call = Call(transcriptionLanguage: "it-IT", state: .refiningTranscript)
            call.summaryState = summaryState
            context.insert(call)
        }
        try context.save()

        let calls = try context.fetch(FetchDescriptor<Call>())
        #expect(calls.count == SummaryState.allCases.count)
        #expect(calls.allSatisfy { $0.state == .refiningTranscript })
        #expect(Set(calls.map(\.summaryState)) == Set(SummaryState.allCases))
    }

    @Test("replacing the summary leaves one summary on the call")
    func replacingSummaryKeepsOne() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext

        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        call.summary = CallSummary(text: "Prima", language: "it-IT")
        context.insert(call)
        try context.save()

        if let old = call.summary {
            call.summary = nil
            context.delete(old)
        }
        call.summary = CallSummary(text: "Seconda", language: "it-IT")
        try context.save()

        let summaries = try context.fetch(FetchDescriptor<CallSummary>())
        #expect(summaries.map(\.text) == ["Seconda"])
        #expect(call.summary?.text == "Seconda")
    }

    @Test("deleting a call deletes its summary and keeps the summary of other calls")
    func deleteRemovesSummary() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext

        let doomed = Call(transcriptionLanguage: "it-IT", state: .ready)
        doomed.summary = CallSummary(text: "Da eliminare", language: "it-IT")
        doomed.summaryState = .written
        let kept = Call(transcriptionLanguage: "it-IT", state: .ready)
        kept.summary = CallSummary(text: "Da tenere", language: "it-IT")
        kept.summaryState = .written
        context.insert(doomed)
        context.insert(kept)
        try context.save()

        try ArchiveStore.delete(doomed, in: context)

        #expect(try context.fetch(FetchDescriptor<Call>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CallSummary>()).map(\.text) == ["Da tenere"])
    }

    @Test("a store saved before summaries existed opens, with its calls without summary")
    func legacyStoreOpens() throws {
        let folder = FileManager.default.temporaryDirectory
            .appending(path: "LARPTests-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let storeURL = folder.appending(path: "LARP.store")
        let callID = UUID()

        do {
            let legacy = try ModelContainer(
                for: LegacyStore.schema,
                configurations: [ModelConfiguration(schema: LegacyStore.schema, url: storeURL)]
            )
            let context = legacy.mainContext
            let call = LegacyStore.Call(id: callID, title: "Vecchia", state: "ready")
            call.lines.append(LegacyStore.TranscriptLine(text: "Ciao"))
            call.participants.append(LegacyStore.Participant(number: 1))
            context.insert(call)
            try context.save()
        }

        let container = try ModelContainer(
            for: ArchiveStore.schema,
            configurations: [ModelConfiguration(schema: ArchiveStore.schema, url: storeURL)]
        )
        let calls = try container.mainContext.fetch(FetchDescriptor<Call>())
        let call = try #require(calls.first)
        #expect(calls.count == 1)
        #expect(call.id == callID)
        #expect(call.title == "Vecchia")
        #expect(call.state == .ready)
        #expect(call.lines.map(\.text) == ["Ciao"])
        #expect(call.participants.map(\.number) == [1])
        #expect(call.summary == nil)
        #expect(call.summaryState == .none)
    }
}
