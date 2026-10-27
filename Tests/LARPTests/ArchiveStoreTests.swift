import Foundation
import SwiftData
import Testing

@testable import LARP

@Suite("ArchiveStore", .serialized)
@MainActor
struct ArchiveStoreTests {
    @Test("a call is stored with its lines and participants")
    func storesCallWithLinesAndParticipants() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext

        let call = Call(title: "Weekly", transcriptionLanguage: "it-IT", state: .ready)
        let participant = Participant(number: 1, name: "Anna")
        call.participants.append(participant)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Ciao a tutti"))
        call.lines.append(
            TranscriptLine(
                speakerKind: .participant, participant: participant, start: 2, end: 4, text: "Buongiorno"
            ))
        context.insert(call)
        try context.save()

        let calls = try context.fetch(FetchDescriptor<Call>())
        #expect(calls.count == 1)
        let stored = try #require(calls.first)
        #expect(stored.id == call.id)
        #expect(stored.title == "Weekly")
        #expect(stored.state == .ready)
        #expect(stored.lines.count == 2)
        #expect(stored.participants.map(\.name) == ["Anna"])
        #expect(participant.lines.map(\.text) == ["Buongiorno"])
    }

    @Test("audio paths are relative to the LARP folder and keyed by call id")
    func audioPaths() throws {
        let call = Call(transcriptionLanguage: "it-IT")
        #expect(call.micAudioPath == "Recordings/\(call.id.uuidString)/mic.caf")
        #expect(call.systemAudioPath == "Recordings/\(call.id.uuidString)/system.caf")
        #expect(call.recordingsFolderURL == AppPaths.recordingsFolder(callID: call.id))
    }

    @Test("deleting a call removes its lines, participants and recordings folder")
    func deleteCascades() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext

        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        let participant = Participant(number: 1)
        call.participants.append(participant)
        call.lines.append(
            TranscriptLine(
                speakerKind: .participant, participant: participant, start: 0, end: 1, text: "Test"
            ))
        context.insert(call)
        try context.save()

        let folder = call.recordingsFolderURL
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("audio".utf8).write(to: call.micAudioURL)
        defer { try? FileManager.default.removeItem(at: folder) }

        try ArchiveStore.delete(call, in: context)

        #expect(try context.fetch(FetchDescriptor<Call>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<TranscriptLine>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Participant>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("deleting a call leaves the other calls untouched")
    func deleteKeepsOthers() throws {
        let container = try ArchiveStore.makeContainer(inMemory: true)
        let context = container.mainContext

        let doomed = Call(title: "Doomed", transcriptionLanguage: "it-IT", state: .ready)
        let kept = Call(title: "Kept", transcriptionLanguage: "en-US", state: .ready)
        kept.lines.append(TranscriptLine(speakerKind: .others, start: 0, end: 1, text: "Hello"))
        context.insert(doomed)
        context.insert(kept)
        try context.save()

        try ArchiveStore.delete(doomed, in: context)

        let calls = try context.fetch(FetchDescriptor<Call>())
        #expect(calls.map(\.title) == ["Kept"])
        #expect(try context.fetch(FetchDescriptor<TranscriptLine>()).count == 1)
    }
}
