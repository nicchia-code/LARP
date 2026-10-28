import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

@Suite("Call management", .serialized)
@MainActor
struct CallManagementTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int, _ minute: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Default names

    @Test("a call from a call app without title is shown as \"Call del <giorno> <mese> <anno>, <hh:mm>\"")
    func defaultTitle() {
        let call = Call(
            startedAt: Self.date(2026, 10, 27, 10, 41), callAppName: "Teams", transcriptionLanguage: "it-IT")
        #expect(call.displayTitle(calendar: Self.utc) == "Call del 27 ottobre 2026, 10:41")
    }

    @Test("a recording without call app is shown as \"Registrazione del <giorno> <mese> <anno>, <hh:mm>\"")
    func defaultTitleWithoutCallApp() {
        let call = Call(startedAt: Self.date(2026, 10, 28, 15, 35), transcriptionLanguage: "it-IT")
        #expect(call.callAppName == nil)
        #expect(call.displayTitle(calendar: Self.utc) == "Registrazione del 28 ottobre 2026, 15:35")
    }

    @Test("a call from a call app keeps the \"Call del …\" default title")
    func defaultTitleWithCallApp() {
        let call = Call(
            startedAt: Self.date(2026, 10, 27, 10, 41), callAppName: "Zoom", transcriptionLanguage: "it-IT")
        #expect(call.displayTitle(calendar: Self.utc) == "Call del 27 ottobre 2026, 10:41")
    }

    @Test("a title given by the user wins over both default titles")
    func customTitleWinsWithoutCallApp() {
        let call = Call(title: "Weekly", startedAt: Self.date(2026, 10, 28, 15, 35), transcriptionLanguage: "it-IT")
        #expect(call.displayTitle(calendar: Self.utc) == "Weekly")
    }

    @Test("the default title uses the Italian month names and pads only the minutes and hours")
    func defaultTitleMonths() {
        let months = [
            "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
            "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre",
        ]
        for (index, name) in months.enumerated() {
            let title = Call.defaultTitle(for: Self.date(2027, index + 1, 3, 9, 5), calendar: Self.utc)
            #expect(title == "Call del 3 \(name) 2027, 09:05")
        }
    }

    @Test("a call with a title is shown with it")
    func customTitle() {
        let call = Call(title: "Weekly", transcriptionLanguage: "it-IT")
        #expect(call.displayTitle == "Weekly")
    }

    @Test("a participant without name is \"Partecipante <numero>\"; Me is \"Io\", Others \"Altri\"")
    func defaultSpeakerNames() {
        let unnamed = Participant(number: 3)
        let named = Participant(number: 1, name: "Anna")
        #expect(unnamed.displayName == "Partecipante 3")
        #expect(named.displayName == "Anna")

        let me = TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "a")
        let others = TranscriptLine(speakerKind: .others, start: 1, end: 2, text: "b")
        let participantLine = TranscriptLine(
            speakerKind: .participant, participant: unnamed, start: 2, end: 3, text: "c")
        #expect(me.speakerName == "Io")
        #expect(others.speakerName == "Altri")
        #expect(participantLine.speakerName == "Partecipante 3")
        unnamed.name = "Marco"
        #expect(participantLine.speakerName == "Marco")
    }

    // MARK: Rename call

    @Test(
        "renaming a call keeps its state",
        arguments: [
            CallState.awaitingLanguage, .transcribing, .separatingParticipants, .awaitingSeparationRetry,
            .refiningTranscript, .awaitingRefinementRetry, .ready,
        ])
    func renameCall(state: CallState) throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(state)

        harness.lifecycle.renameCall(call, to: "Riunione")

        #expect(call.title == "Riunione")
        #expect(call.displayTitle == "Riunione")
        #expect(call.state == state)
    }

    @Test("a call cannot be renamed or deleted while it is recording")
    func recordingCannotBeRenamedOrDeleted() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.recording)

        #expect(!harness.lifecycle.canRename(call))
        #expect(!harness.lifecycle.canDelete(call))
        harness.lifecycle.renameCall(call, to: "Nope")
        harness.lifecycle.deleteCall(call)

        #expect(call.title == nil)
        #expect(try harness.allCalls().count == 1)
        #expect(FileManager.default.fileExists(atPath: call.micAudioURL.path))
    }

    @Test("an empty title restores the default one")
    func emptyTitleRestoresDefault() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, title: "Weekly")

        harness.lifecycle.renameCall(call, to: "   ")

        #expect(call.title == nil)
        #expect(call.displayTitle == Call.defaultTitle(for: call.startedAt, hasCallApp: false))
    }

    @Test("an empty title of a call from a call app restores \"Call del …\"")
    func emptyTitleRestoresCallDefault() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, title: "Weekly")
        call.callAppName = "Zoom"

        harness.lifecycle.renameCall(call, to: "")

        #expect(call.title == nil)
        #expect(call.displayTitle == Call.defaultTitle(for: call.startedAt, hasCallApp: true))
        #expect(call.displayTitle.hasPrefix("Call del "))
    }

    @Test("a title is stored without surrounding whitespace")
    func titleIsTrimmed() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        harness.lifecycle.renameCall(call, to: "  Budget \n")

        #expect(call.title == "Budget")
    }

    // MARK: Rename participant

    private func readyCall(_ harness: CallHarness, names: [String?]) throws -> Call {
        let call = try harness.insertCall(.ready)
        for (index, name) in names.enumerated() {
            let participant = Participant(number: index + 1, name: name)
            call.participants.append(participant)
            call.lines.append(
                TranscriptLine(
                    speakerKind: .participant, participant: participant, start: Double(index),
                    end: Double(index) + 1, text: "riga \(index + 1)"))
        }
        call.lines.append(TranscriptLine(speakerKind: .me, start: 10, end: 11, text: "io"))
        try harness.context.save()
        return call
    }

    @Test("renaming a participant renames it in every line of the transcript")
    func renameParticipantEverywhere() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try readyCall(harness, names: [nil, nil])
        let first = try #require(call.participants.first { $0.number == 1 })
        call.lines.append(
            TranscriptLine(speakerKind: .participant, participant: first, start: 5, end: 6, text: "ancora"))

        harness.lifecycle.renameParticipant(first, to: "Anna")

        let speakers = call.lines.filter { $0.participant === first }.map(\.speakerName)
        #expect(speakers == ["Anna", "Anna"])
        let other = try #require(call.participants.first { $0.number == 2 })
        #expect(other.displayName == "Partecipante 2")
        #expect(call.state == .ready)
    }

    @Test("renaming a participant of a call does not touch the participants of other calls")
    func renameParticipantOnlyInThisCall() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let first = try readyCall(harness, names: [nil])
        let second = try readyCall(harness, names: [nil])

        harness.lifecycle.renameParticipant(try #require(first.participants.first), to: "Anna")

        #expect(first.participants.first?.displayName == "Anna")
        #expect(second.participants.first?.displayName == "Partecipante 1")
        #expect(second.lines.filter { $0.speakerKind == .participant }.map(\.speakerName) == ["Partecipante 1"])
    }

    @Test("an empty participant name restores \"Partecipante <numero>\"")
    func emptyParticipantNameRestoresDefault() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try readyCall(harness, names: ["Anna"])
        let participant = try #require(call.participants.first)

        harness.lifecycle.renameParticipant(participant, to: "")

        #expect(participant.name == nil)
        #expect(participant.displayName == "Partecipante 1")
    }

    @Test("participants are renamed only when the call is Ready")
    func renameParticipantNeedsReady() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try readyCall(harness, names: [nil])
        call.state = .separatingParticipants
        let participant = try #require(call.participants.first)

        harness.lifecycle.renameParticipant(participant, to: "Anna")

        #expect(participant.name == nil)
    }

    // MARK: Delete

    private final class Deletions: @unchecked Sendable {
        private let lock = NSLock()
        private var ids: [UUID] = []
        private var observer: NSObjectProtocol?

        var callIDs: [UUID] {
            lock.withLock { ids }
        }

        init() {
            observer = NotificationCenter.default.addObserver(forName: .callDeleted, object: nil, queue: nil) {
                [self] notification in
                if let id = notification.callID { lock.withLock { ids.append(id) } }
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }
    }

    @Test(
        "deleting a call removes the call, its lines, its participants and its audio, and emits DELETED",
        arguments: [
            CallState.awaitingLanguage, .transcribing, .separatingParticipants, .awaitingSeparationRetry,
            .refiningTranscript, .awaitingRefinementRetry, .ready,
        ])
    func deleteCall(state: CallState) throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try readyCall(harness, names: [nil, "Anna"])
        call.state = state
        let kept = try harness.insertCall(.ready, title: "Kept")
        kept.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "resta"))
        let id = call.id
        let folder = call.recordingsFolderURL
        let deletions = Deletions()

        harness.lifecycle.deleteCall(call)

        #expect(try harness.allCalls().map(\.title) == ["Kept"])
        #expect(try harness.context.fetch(FetchDescriptor<Participant>()).isEmpty)
        #expect(try harness.context.fetch(FetchDescriptor<TranscriptLine>()).count == 1)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
        #expect(FileManager.default.fileExists(atPath: kept.micAudioURL.path))
        #expect(deletions.callIDs == [id])
    }

    @Test("deleting a call that is being transcribed stops the transcription and removes everything")
    func deleteWhileTranscribing() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.transcription.set { $0.blocksFiles = true }
        let call = try harness.insertCall(.transcribing)
        let folder = call.recordingsFolderURL

        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { harness.transcription.transcribedFiles.count == 2 })

        harness.lifecycle.deleteCall(call)
        await harness.lifecycle.waitUntilTranscriptionIdle()

        #expect(harness.transcription.cancelledFiles == 2)
        #expect(try harness.allCalls().isEmpty)
        #expect(try harness.context.fetch(FetchDescriptor<TranscriptLine>()).isEmpty)
        #expect(!FileManager.default.fileExists(atPath: folder.path))
    }

    @Test("deleting a call that is being separated stops the separation")
    func deleteWhileSeparating() async throws {
        let separator = FakeSeparator(.hang)
        let harness = try CallHarness(separator: separator)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.separatingParticipants)

        await harness.lifecycle.appLaunched()
        #expect(await harness.eventually { separator.startedCallIDs == [call.id] })

        harness.lifecycle.deleteCall(call)

        #expect(await harness.eventually { separator.cancelledCount == 1 })
        #expect(try harness.allCalls().isEmpty)
    }
}
