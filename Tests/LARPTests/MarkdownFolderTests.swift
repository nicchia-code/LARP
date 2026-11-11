import Foundation
import SwiftData
import Synchronization
import Testing

@testable import LARP

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

/// A system panel the test answers: the folders it gives in order, `nil` for a cancelled panel.
@MainActor
private final class FakeFolderPicker: MarkdownFolderPicking {
    var answers: [String?]
    private(set) var startingPaths: [String?] = []

    init(_ answers: [String?]) {
        self.answers = answers
    }

    func chooseFolder(startingAt path: String?) async -> String? {
        startingPaths.append(path)
        return answers.isEmpty ? nil : answers.removeFirst()
    }
}

/// The machine `markdown-folder`: what is chosen, what is saved.
@Suite("Markdown folder controller", .serialized)
@MainActor
struct MarkdownFolderControllerTests {
    private func makeController(
        answers: [String?] = [], defaults: UserDefaults = makeDefaults()
    ) -> (MarkdownFolderController, FakeFolderPicker, UserDefaults) {
        let picker = FakeFolderPicker(answers)
        return (MarkdownFolderController(defaults: defaults, picker: picker), picker, defaults)
    }

    @Test("it starts Off, with nothing saved")
    func startsOff() {
        let (controller, _, _) = makeController()
        #expect(controller.state == .off)
        #expect(!controller.isOn)
        #expect(controller.folderPath == nil)
        #expect(controller.folderURL == nil)
    }

    @Test("it starts On when the folder was left on")
    func startsOnWhenLeftOn() {
        let defaults = makeDefaults()
        defaults.set("/Users/anna/Notes", forKey: SettingsKey.markdownFolder)
        let (controller, _, _) = makeController(defaults: defaults)
        #expect(controller.state == .on(folder: "/Users/anna/Notes"))
        #expect(controller.folderURL == URL(fileURLWithPath: "/Users/anna/Notes", isDirectory: true))
    }

    @Test("TURN_ON with a folder chosen: saved, On, and the folder is announced")
    func turnOnChoosingAFolder() async {
        let (controller, picker, defaults) = makeController(answers: ["/Users/anna/Notes"])
        let chosen = controller.folderChosen
        await controller.turnOn()
        #expect(controller.state == .on(folder: "/Users/anna/Notes"))
        #expect(defaults.string(forKey: SettingsKey.markdownFolder) == "/Users/anna/Notes")
        #expect(picker.startingPaths == [nil])
        var iterator = chosen.makeAsyncIterator()
        #expect(await iterator.next() == "/Users/anna/Notes")
    }

    @Test("TURN_ON with the panel cancelled: still Off, nothing saved, nothing announced")
    func turnOnCancelled() async {
        let (controller, _, defaults) = makeController(answers: [nil])
        var announced = 0
        let chosen = controller.folderChosen
        let listener = Task { for await _ in chosen { announced += 1 } }
        await controller.turnOn()
        #expect(controller.state == .off)
        #expect(defaults.string(forKey: SettingsKey.markdownFolder) == nil)
        await Task.yield()
        listener.cancel()
        #expect(announced == 0)
    }

    @Test("TURN_ON while On changes nothing and does not open the panel")
    func turnOnWhileOn() async {
        let (controller, picker, _) = makeController(answers: ["/a", "/b"])
        await controller.turnOn()
        await controller.turnOn()
        #expect(controller.folderPath == "/a")
        #expect(picker.answers == ["/b"])
    }

    @Test("CHOOSE: the panel starts in the folder in use; the new one is saved and announced")
    func chooseAnotherFolder() async {
        let (controller, picker, defaults) = makeController(answers: ["/a", "/b"])
        await controller.turnOn()
        let chosen = controller.folderChosen
        await controller.chooseAnother()
        #expect(controller.state == .on(folder: "/b"))
        #expect(defaults.string(forKey: SettingsKey.markdownFolder) == "/b")
        #expect(picker.startingPaths == [nil, "/a"])
        var iterator = chosen.makeAsyncIterator()
        #expect(await iterator.next() == "/b")
    }

    @Test("CHOOSE with the panel cancelled keeps the folder in use")
    func chooseAnotherCancelled() async {
        let (controller, _, defaults) = makeController(answers: ["/a", nil])
        await controller.turnOn()
        await controller.chooseAnother()
        #expect(controller.folderPath == "/a")
        #expect(defaults.string(forKey: SettingsKey.markdownFolder) == "/a")
    }

    @Test("CHOOSE while Off does nothing")
    func chooseWhileOff() async {
        let (controller, picker, _) = makeController(answers: ["/a"])
        await controller.chooseAnother()
        #expect(controller.state == .off)
        #expect(picker.startingPaths.isEmpty)
    }

    @Test("TURN_OFF: Off, the choice is saved as absent, and it starts Off the next time")
    func turnOff() async {
        let defaults = makeDefaults()
        let (controller, _, _) = makeController(answers: ["/a"], defaults: defaults)
        await controller.turnOn()
        controller.turnOff()
        #expect(controller.state == .off)
        #expect(defaults.string(forKey: SettingsKey.markdownFolder) == nil)
        #expect(MarkdownFolderController(defaults: defaults, picker: FakeFolderPicker([])).state == .off)
    }

    @Test("a failed write is shown until a write succeeds, and never while Off")
    func writeError() async {
        let (controller, _, _) = makeController(answers: ["/a", "/b"])
        controller.writeFailed()
        #expect(!controller.hasWriteError)
        await controller.turnOn()
        controller.writeFailed()
        #expect(controller.hasWriteError)
        controller.writeSucceeded()
        #expect(!controller.hasWriteError)
        controller.writeFailed()
        await controller.chooseAnother()
        #expect(!controller.hasWriteError, "a new folder starts clean")
        controller.writeFailed()
        controller.turnOff()
        #expect(!controller.hasWriteError)
    }
}

/// A `MarkdownFileWriting` that fails while the test says so, and otherwise writes for real.
private final class FlakyFiles: MarkdownFileWriting {
    private let failing = Mutex(false)
    private let real = MarkdownFolderFiles()

    func setFailing(_ failing: Bool) { self.failing.withLock { $0 = failing } }

    func write(_ text: String, named fileName: String, in folder: URL) async throws {
        if failing.withLock({ $0 }) { throw CocoaError(.fileWriteNoPermission) }
        try await real.write(text, named: fileName, in: folder)
    }

    func remove(named fileName: String, in folder: URL) async throws {
        try await real.remove(named: fileName, in: folder)
    }

    func exists(named fileName: String, in folder: URL) async -> Bool {
        await real.exists(named: fileName, in: folder)
    }
}

/// The effects of `markdown-folder` on the calls: which files exist, with what name and content.
@Suite("Markdown folder files", .serialized, .italianInterface)
@MainActor
struct MarkdownFolderSyncTests {
    private let container: ModelContainer
    private let files = FlakyFiles()
    private let folder: URL
    private let otherFolder: URL
    private let reports = Reports()
    private let current: CurrentFolder
    private let defaults: UserDefaults
    private let sync: MarkdownFolderSync

    @MainActor
    private final class Reports {
        var results: [Bool] = []
    }

    @MainActor
    private final class CurrentFolder {
        var url: URL?
    }

    init() throws {
        container = try ArchiveStore.makeContainer(inMemory: true)
        let root = FileManager.default.temporaryDirectory.appending(path: "LARPMarkdownFolder-\(UUID().uuidString)")
        folder = root.appending(path: "one")
        otherFolder = root.appending(path: "two")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: otherFolder, withIntermediateDirectories: true)
        let current = CurrentFolder()
        current.url = folder
        self.current = current
        let defaults = makeDefaults()
        self.defaults = defaults
        let reports = reports
        sync = MarkdownFolderSync(
            context: container.mainContext,
            folder: { current.url },
            files: files,
            report: { reports.results.append($0) },
            language: { .italian },
            defaults: defaults)
    }

    private var context: ModelContext { container.mainContext }

    private func insert(
        _ title: String, state: CallState = .ready, startedAt: TimeInterval = 1_700_000_000, lines: [String] = []
    ) throws -> Call {
        let call = Call(
            title: title, startedAt: Date(timeIntervalSince1970: startedAt), duration: 60, transcriptionLanguage: "it-IT",
            state: state)
        context.insert(call)
        for (index, text) in lines.enumerated() {
            call.lines.append(
                TranscriptLine(speakerKind: .me, start: TimeInterval(index), end: TimeInterval(index + 1), text: text))
        }
        try context.save()
        return call
    }

    private func names(in directory: URL) throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).sorted()
    }

    private func text(of name: String, in directory: URL? = nil) throws -> String {
        try String(contentsOf: (directory ?? folder).appending(path: name), encoding: .utf8)
    }

    private func export(of call: Call) -> String {
        TranscriptExport.markdown(for: call, language: .italian)
    }

    // MARK: Turning on, choosing

    @Test("every ready call is written at once, and only the ready ones")
    func writeAllReadyCalls() async throws {
        let ready = try insert("Weekly", lines: ["ciao"])
        _ = try insert("Ancora in corso", state: .transcribing)
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly.md"])
        #expect(try text(of: "Weekly.md") == export(of: ready))
        #expect(ready.markdownFileName == "Weekly.md")
        #expect(reports.results == [true])
    }

    @Test("calls with the same name get \" (2)\", \" (3)\" before .md, the oldest first")
    func sameNames() async throws {
        let first = try insert("Weekly", startedAt: 1_700_000_000)
        let second = try insert("Weekly", startedAt: 1_700_000_100)
        let third = try insert("Weekly", startedAt: 1_700_000_200)
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly (2).md", "Weekly (3).md", "Weekly.md"])
        #expect([first, second, third].map(\.markdownFileName) == ["Weekly.md", "Weekly (2).md", "Weekly (3).md"])
    }

    @Test("a slash in the title becomes a dash in the file name")
    func slashInTitle() async throws {
        _ = try insert("Q3/Q4 piano")
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Q3-Q4 piano.md"])
    }

    @Test("choosing another folder writes every ready call into it; the old files stay")
    func newFolder() async throws {
        let call = try insert("Weekly")
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        current.url = otherFolder
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly.md"])
        #expect(try names(in: otherFolder) == ["Weekly.md"])
        #expect(call.markdownFileName == "Weekly.md")
    }

    @Test("while Off nothing is written")
    func whileOff() async throws {
        let call = try insert("Weekly")
        current.url = nil
        sync.writeAllReadyCalls()
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(try names(in: folder).isEmpty)
        #expect(call.markdownFileName == nil)
        #expect(reports.results.isEmpty)
    }

    // MARK: Call events

    @Test("call.READY writes the file of the call, replacing the one it had")
    func becameReady() async throws {
        let call = try insert("Weekly", lines: ["uno"])
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == export(of: call))
        call.lines.append(TranscriptLine(speakerKind: .others, start: 5, end: 6, text: "due"))
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly.md"])
        #expect(try text(of: "Weekly.md").contains("due"))
    }

    @Test("a call that is not ready is not written until it becomes ready")
    func notReadyYet() async throws {
        let call = try insert("Weekly", state: .refiningTranscript)
        for change in [CallChange.exportChanged(call.id), .renamed(call.id)] { sync.handle(change) }
        await sync.waitUntilIdle()
        #expect(try names(in: folder).isEmpty)
        call.state = .ready
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly.md"])
    }

    @Test("a change of what the export holds writes the file again")
    func exportChanged() async throws {
        let call = try insert("Weekly", lines: ["uno"])
        sync.handle(.becameReady(call.id))
        call.notes.append(Note(text: "da ricordare", time: 3, writtenAt: .now))
        sync.handle(.exportChanged(call.id))
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly.md"])
        #expect(try text(of: "Weekly.md") == export(of: call))
    }

    @Test("renaming a ready call gives the file the new name and removes the old one")
    func renamed() async throws {
        let call = try insert("Weekly")
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        call.title = "Retrospettiva"
        sync.handle(.renamed(call.id))
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Retrospettiva.md"])
        #expect(call.markdownFileName == "Retrospettiva.md")
        #expect(try text(of: "Retrospettiva.md") == export(of: call))
    }

    @Test("a name that still fits is kept, also when another call took the plain one")
    func keptName() async throws {
        let first = try insert("Weekly", startedAt: 1_700_000_000)
        let second = try insert("Weekly", startedAt: 1_700_000_100)
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        sync.handle(.exportChanged(second.id))
        await sync.waitUntilIdle()
        #expect(second.markdownFileName == "Weekly (2).md")
        #expect(first.markdownFileName == "Weekly.md")
        #expect(try names(in: folder) == ["Weekly (2).md", "Weekly.md"])
    }

    @Test("renaming to a name another call has adds the number")
    func renamedToATakenName() async throws {
        let first = try insert("Weekly", startedAt: 1_700_000_000)
        let second = try insert("Standup", startedAt: 1_700_000_100)
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        second.title = "Weekly"
        sync.handle(.renamed(second.id))
        await sync.waitUntilIdle()
        #expect(first.markdownFileName == "Weekly.md")
        #expect(second.markdownFileName == "Weekly (2).md")
        #expect(try names(in: folder) == ["Weekly (2).md", "Weekly.md"])
    }

    @Test("a call that is deleted loses its file, whatever its state")
    func deleted() async throws {
        let call = try insert("Weekly")
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        sync.handle(.deleted(call.id, markdownFileName: call.markdownFileName))
        await sync.waitUntilIdle()
        #expect(try names(in: folder).isEmpty)
    }

    @Test("a file is never removed unless LARP wrote it for that call")
    func foreignFileStays() async throws {
        try Data("mio".utf8).write(to: folder.appending(path: "Weekly.md"))
        let call = try insert("Weekly")
        sync.handle(.deleted(call.id, markdownFileName: nil))
        await sync.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == "mio")
    }

    @Test("removing a file that is already gone is not an error")
    func removingAMissingFile() async throws {
        let call = try insert("Weekly")
        sync.handle(.deleted(call.id, markdownFileName: "Weekly.md"))
        await sync.waitUntilIdle()
        #expect(try names(in: folder).isEmpty)
    }

    // MARK: Foreign files

    @Test("a file the user put there with the name of the call is not replaced: the call gets \" (2)\"")
    func foreignFileIsNotReplaced() async throws {
        try Data("mio".utf8).write(to: folder.appending(path: "Weekly.md"))
        let call = try insert("Weekly", lines: ["ciao"])
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == "mio")
        #expect(try text(of: "Weekly (2).md") == export(of: call))
        #expect(call.markdownFileName == "Weekly (2).md")
        #expect(reports.results == [true])
    }

    @Test("the name a call kept is not trusted when a file that is not LARP's holds it now")
    func keptNameTakenByAForeignFile() async throws {
        let call = try insert("Weekly")
        call.markdownFileName = "Weekly.md"
        try Data("mio".utf8).write(to: folder.appending(path: "Weekly.md"))
        sync.handle(.exportChanged(call.id))
        await sync.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == "mio")
        #expect(try text(of: "Weekly (2).md") == export(of: call))
        #expect(call.markdownFileName == "Weekly (2).md")
    }

    @Test("every file with a taken name is skipped, whatever the case of its name")
    func foreignFilesAreSkipped() async throws {
        try Data("uno".utf8).write(to: folder.appending(path: "Weekly.md"))
        try Data("due".utf8).write(to: folder.appending(path: "weekly (2).md"))
        let call = try insert("Weekly")
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(call.markdownFileName == "Weekly (3).md")
        #expect(try text(of: "Weekly.md") == "uno")
        #expect(try text(of: "weekly (2).md") == "due")
    }

    @Test("a file LARP wrote is recognised and written again when the folder is turned on again")
    func ownFileIsReplacedAfterTurnOnAgain() async throws {
        let call = try insert("Weekly", lines: ["uno"])
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        current.url = nil
        call.lines.append(TranscriptLine(speakerKind: .others, start: 5, end: 6, text: "due"))
        current.url = folder
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(try names(in: folder) == ["Weekly.md"])
        #expect(try text(of: "Weekly.md") == export(of: call))
        #expect(call.markdownFileName == "Weekly.md")
    }

    @Test("the names LARP wrote are kept for each folder and survive a new launch")
    func writtenNamesAreKeptPerFolder() async throws {
        let call = try insert("Weekly")
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        current.url = otherFolder
        try Data("mio".utf8).write(to: otherFolder.appending(path: "Weekly.md"))
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(try text(of: "Weekly.md", in: otherFolder) == "mio")
        #expect(try text(of: "Weekly (2).md", in: otherFolder) == export(of: call))
        let relaunched = MarkdownWrittenNames(defaults: defaults)
        #expect(relaunched.names(in: folder) == ["Weekly.md"])
        #expect(relaunched.names(in: otherFolder) == ["Weekly (2).md"])
    }

    @Test("a file removed with its call is no longer one of LARP's")
    func removedNameIsForgotten() async throws {
        let call = try insert("Weekly")
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        sync.handle(.deleted(call.id, markdownFileName: call.markdownFileName))
        await sync.waitUntilIdle()
        #expect(MarkdownWrittenNames(defaults: defaults).names(in: folder).isEmpty)
        try Data("mio".utf8).write(to: folder.appending(path: "Weekly.md"))
        let next = try insert("Weekly")
        sync.handle(.becameReady(next.id))
        await sync.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == "mio")
        #expect(next.markdownFileName == "Weekly (2).md")
    }

    // MARK: Failures

    @Test("a file that cannot be written is tried again at the next change of its call")
    func failureThenRetry() async throws {
        let call = try insert("Weekly")
        files.setFailing(true)
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(reports.results == [false])
        #expect(call.markdownFileName == nil)
        #expect(try names(in: folder).isEmpty)
        files.setFailing(false)
        sync.handle(.exportChanged(call.id))
        await sync.waitUntilIdle()
        #expect(reports.results == [false, true])
        #expect(call.markdownFileName == "Weekly.md")
        #expect(try names(in: folder) == ["Weekly.md"])
    }

    @Test("a folder that is not there is a failed write, not a folder created")
    func missingFolder() async throws {
        let call = try insert("Weekly")
        current.url = folder.appending(path: "gone")
        sync.handle(.becameReady(call.id))
        await sync.waitUntilIdle()
        #expect(reports.results == [false])
        #expect(!FileManager.default.fileExists(atPath: folder.appending(path: "gone").path))
    }

    @Test("writing every call reports a failure when one of the files failed")
    func writeAllFailure() async throws {
        _ = try insert("Weekly")
        files.setFailing(true)
        sync.writeAllReadyCalls()
        await sync.waitUntilIdle()
        #expect(reports.results == [false])
    }

    // MARK: Content

    @Test("the content is the Markdown export in the interface language at the moment of writing")
    func interfaceLanguage() async throws {
        let call = try insert("Weekly", lines: ["hello"])
        var language = AppLanguage.italian
        let english = MarkdownFolderSync(
            context: context, folder: { [folder] in folder }, files: files, report: { _ in }, language: { language },
            defaults: defaults)
        english.handle(.becameReady(call.id))
        await english.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == TranscriptExport.markdown(for: call, language: .italian))
        language = .english
        english.handle(.exportChanged(call.id))
        await english.waitUntilIdle()
        #expect(try text(of: "Weekly.md") == TranscriptExport.markdown(for: call, language: .english))
        #expect(try text(of: "Weekly.md") != TranscriptExport.markdown(for: call, language: .italian))
    }

    // MARK: Names

    @Test("a name fits a title as the title, or the title with a number from 2 on")
    func nameFitsTitle() {
        #expect(MarkdownFolderSync.isName("Weekly.md", from: "Weekly"))
        #expect(MarkdownFolderSync.isName("Weekly (2).md", from: "Weekly"))
        #expect(MarkdownFolderSync.isName("Weekly (12).md", from: "Weekly"))
        #expect(!MarkdownFolderSync.isName("Weekly (1).md", from: "Weekly"))
        #expect(!MarkdownFolderSync.isName("Weekly (x).md", from: "Weekly"))
        #expect(!MarkdownFolderSync.isName("Weekly 2.md", from: "Weekly"))
        #expect(!MarkdownFolderSync.isName("Other.md", from: "Weekly"))
    }
}

/// The news `CallLifecycle` sends for the Markdown folder.
@Suite("Call changes for the Markdown folder", .serialized, .italianInterface)
@MainActor
struct CallChangeTests {
    private func next(_ stream: AsyncStream<CallChange>) async -> CallChange? {
        var iterator = stream.makeAsyncIterator()
        return await iterator.next()
    }

    @Test("a call that becomes ready")
    func becameReady() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.refiningTranscript)
        let changes = harness.lifecycle.callChanges.stream()
        harness.lifecycle.apply(.transcriptRefined, to: call)
        #expect(await next(changes) == .becameReady(call.id))
    }

    @Test("a renamed call, a renamed participant, notes and bookmarks change what the export holds")
    func exportChanged() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let participant = Participant(number: 1)
        call.participants.append(participant)
        let changes = harness.lifecycle.callChanges.stream()
        var iterator = changes.makeAsyncIterator()

        harness.lifecycle.renameCall(call, to: "Nuovo")
        #expect(await iterator.next() == .renamed(call.id))
        harness.lifecycle.renameParticipant(participant, to: "Anna")
        #expect(await iterator.next() == .exportChanged(call.id))
        let note = try #require(harness.lifecycle.addNote(to: call, text: "una nota", at: 3))
        #expect(await iterator.next() == .exportChanged(call.id))
        harness.lifecycle.editNote(note, to: "un'altra nota")
        #expect(await iterator.next() == .exportChanged(call.id))
        harness.lifecycle.deleteNote(note)
        #expect(await iterator.next() == .exportChanged(call.id))
        let bookmark = try #require(harness.lifecycle.addBookmark(to: call, at: 5))
        #expect(await iterator.next() == .exportChanged(call.id))
        harness.lifecycle.deleteBookmark(bookmark)
        #expect(await iterator.next() == .exportChanged(call.id))
    }

    @Test("a corrected line and a restored transcript end in Ready, which writes the file again")
    func lineAndRestore() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let line = TranscriptLine(speakerKind: .me, start: 1, end: 2, text: "Ciao a tuto")
        call.lines.append(line)
        line.originalText = "Ciao"
        let changes = harness.lifecycle.callChanges.stream()
        var iterator = changes.makeAsyncIterator()

        harness.lifecycle.editLine(line, of: call, to: "Ciao a tutti")
        #expect(await iterator.next() == .becameReady(call.id))
        harness.lifecycle.restoreTranscript(call)
        #expect(await iterator.next() == .becameReady(call.id))
    }

    @Test("a summary written and an action ticked or unticked change what the export holds")
    func summaryAndActions() async throws {
        let answer = """
            {"opening": "Si parte.", "openingHighlight": "Si parte", "keyConcepts": [], "decisions": [], \
            "actionItems": [{"text": "Inviare il piano"}], "openQuestions": [], "other": ""}
            """
        let harness = try CallHarness(summarizer: FakeSummarizer(.answer(answer)), summariesOn: true)
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, title: "Riunione")
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno"))
        try harness.context.save()
        let changes = harness.lifecycle.callChanges.stream()
        var iterator = changes.makeAsyncIterator()

        harness.lifecycle.summarize(call)
        #expect(await iterator.next() == .exportChanged(call.id))
        harness.lifecycle.toggleActionItem(of: call, at: 0)
        #expect(await iterator.next() == .exportChanged(call.id))
        harness.lifecycle.toggleActionItem(of: call, at: 0)
        #expect(await iterator.next() == .exportChanged(call.id))
    }

    @Test("a call that is deleted carries the name of its file")
    func deleted() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        call.markdownFileName = "Weekly.md"
        let changes = harness.lifecycle.callChanges.stream()
        let id = call.id
        harness.lifecycle.deleteCall(call)
        #expect(await next(changes) == .deleted(id, markdownFileName: "Weekly.md"))
    }
}
