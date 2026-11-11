import Foundation
import SwiftData
import Testing

@testable import LARP

@Suite("Folders", .serialized, .italianInterface)
@MainActor
struct FolderTests {
    // MARK: The name

    @Test(
        "a folder name is trimmed, not empty and at most 60 characters",
        arguments: [
            ("  Clienti  ", "Clienti"), ("Progetti 2026", "Progetti 2026"),
            (String(repeating: "a", count: 60), String(repeating: "a", count: 60)),
        ])
    func cleaned(typed: String, expected: String) {
        #expect(FolderName.cleaned(typed) == expected)
    }

    @Test("an empty name or one longer than 60 characters is not a name", arguments: ["", "   ", "\n"])
    func notAName(typed: String) {
        #expect(FolderName.cleaned(typed) == nil)
        #expect(FolderName.cleaned(String(repeating: "a", count: 61)) == nil)
    }

    @Test("two names are the same ignoring case and accents")
    func sameName() {
        #expect(FolderName.same("Città", "citta"))
        #expect(FolderName.same("CLIENTI", "clienti"))
        #expect(!FolderName.same("Clienti", "Clienti 2"))
    }

    @Test("folders are listed in alphabetical order, ignoring case and accents")
    func alphabetical() {
        let folders = ["zeta", "Èlite", "Alfa", "beta"].map { Folder(name: $0) }
        #expect(FolderName.sorted(folders).map(\.name) == ["Alfa", "beta", "Èlite", "zeta"])
    }

    // MARK: user.CREATE_FOLDER

    @Test("user.CREATE_FOLDER creates a folder with the trimmed name")
    func create() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let folder = harness.lifecycle.createFolder(named: "  Clienti ")
        #expect(folder?.name == "Clienti")
        #expect(harness.lifecycle.folders().map(\.name) == ["Clienti"])
    }

    @Test("user.CREATE_FOLDER creates nothing for an empty name, a long one or one another folder has")
    func createRefused() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.lifecycle.createFolder(named: "Città")
        #expect(harness.lifecycle.createFolder(named: "   ") == nil)
        #expect(harness.lifecycle.createFolder(named: String(repeating: "x", count: 61)) == nil)
        #expect(harness.lifecycle.createFolder(named: "CITTA") == nil)
        #expect(harness.lifecycle.folders().map(\.name) == ["Città"])
    }

    // MARK: user.RENAME_FOLDER

    @Test("user.RENAME_FOLDER renames with the same rules; otherwise the folder keeps its name")
    func rename() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let clienti = try #require(harness.lifecycle.createFolder(named: "Clienti"))
        harness.lifecycle.createFolder(named: "Interni")

        #expect(harness.lifecycle.renameFolder(clienti, to: " Fornitori "))
        #expect(clienti.name == "Fornitori")
        #expect(!harness.lifecycle.renameFolder(clienti, to: "interni"))
        #expect(!harness.lifecycle.renameFolder(clienti, to: "  "))
        #expect(!harness.lifecycle.renameFolder(clienti, to: String(repeating: "y", count: 61)))
        #expect(clienti.name == "Fornitori")
    }

    @Test("user.RENAME_FOLDER may change only the case of the name it has")
    func renameCaseOnly() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let folder = try #require(harness.lifecycle.createFolder(named: "clienti"))
        #expect(harness.lifecycle.renameFolder(folder, to: "Clienti"))
        #expect(folder.name == "Clienti")
    }

    // MARK: user.MOVE_TO_FOLDER

    @Test("user.MOVE_TO_FOLDER: the call leaves its previous folder and joins the new one; none takes it out")
    func move() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let a = try #require(harness.lifecycle.createFolder(named: "A"))
        let b = try #require(harness.lifecycle.createFolder(named: "B"))

        harness.lifecycle.moveCall(call, to: a)
        #expect(call.folder?.id == a.id)
        #expect(a.calls.map(\.id) == [call.id])

        harness.lifecycle.moveCall(call, to: b)
        #expect(call.folder?.id == b.id)
        #expect(a.calls.isEmpty)
        #expect(b.calls.map(\.id) == [call.id])

        harness.lifecycle.moveCall(call, to: nil)
        #expect(call.folder == nil)
        #expect(b.calls.isEmpty)
    }

    // MARK: user.DELETE_FOLDER

    @Test("user.DELETE_FOLDER leaves the calls in the archive without folder")
    func deleteFolder() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let first = try harness.insertCall(.ready)
        let second = try harness.insertCall(.ready)
        let other = try harness.insertCall(.ready)
        let folder = try #require(harness.lifecycle.createFolder(named: "Clienti"))
        let kept = try #require(harness.lifecycle.createFolder(named: "Interni"))
        harness.lifecycle.moveCall(first, to: folder)
        harness.lifecycle.moveCall(second, to: folder)
        harness.lifecycle.moveCall(other, to: kept)

        harness.lifecycle.deleteFolder(folder)

        #expect(harness.lifecycle.folders().map(\.name) == ["Interni"])
        #expect(try harness.allCalls().count == 3)
        #expect(first.folder == nil)
        #expect(second.folder == nil)
        #expect(other.folder?.id == kept.id)
    }

    @Test("deleting a call takes it out of its folder without deleting the folder")
    func folderDoesNotOwnTheCall() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let folder = try #require(harness.lifecycle.createFolder(named: "Clienti"))
        harness.lifecycle.moveCall(call, to: folder)

        harness.lifecycle.deleteCall(call)

        #expect(harness.lifecycle.folders().count == 1)
        #expect(folder.calls.isEmpty)
    }

    // MARK: Main window

    private func makeModel() -> MainWindowModel {
        MainWindowModel()
    }

    @Test("user.SHOW_FOLDER shows the folder; user.DELETE_FOLDER goes back to all calls only for the folder shown")
    func showAndDelete() {
        let model = makeModel()
        let shown = UUID()
        let other = UUID()
        model.showFolder(shown)
        #expect(model.libraryView == .folder(shown))
        #expect(model.page == .library)

        model.folderDeleted(other)
        #expect(model.libraryView == .folder(shown))
        model.folderDeleted(shown)
        #expect(model.libraryView == .allCalls)
    }

    @Test("the folder and the filter stay when a call is opened and the library comes back")
    func staysWhenACallIsOpened() {
        let model = makeModel()
        let folder = UUID()
        model.showFolder(folder)
        model.filterByApp(.app("Zoom"))
        model.searchText = "budget"
        model.selectCall(UUID())
        model.showLibrary()
        #expect(model.libraryView == .folder(folder))
        #expect(model.appFilter == .app("Zoom"))
        #expect(model.searchText == "budget")
    }
}

@Suite("Filters by call app", .serialized)
@MainActor
struct LibraryFilterTests {
    private func call(app: String? = nil, imported: Bool = false) -> Call {
        let call = Call(callAppName: app, transcriptionLanguage: "it-IT", state: .ready)
        call.isImported = imported
        return call
    }

    @Test("the chips: Tutte, the call apps in alphabetical order, Manuali, Importate")
    func chips() {
        let calls = [
            call(app: "Zoom"), call(app: "Google Meet"), call(app: "Zoom"), call(), call(imported: true),
        ]
        #expect(
            LibraryFilter.chips(for: calls) == [.all, .app("Google Meet"), .app("Zoom"), .manual, .imported])
    }

    @Test("Manuali and Importate are offered only when there is such a call")
    func optionalChips() {
        #expect(LibraryFilter.chips(for: []) == [.all])
        #expect(LibraryFilter.chips(for: [call(app: "Zoom")]) == [.all, .app("Zoom")])
        #expect(LibraryFilter.chips(for: [call()]) == [.all, .manual])
        #expect(LibraryFilter.chips(for: [call(imported: true)]) == [.all, .imported])
    }

    @Test("a chip shows only its calls and Tutte shows every call")
    func apply() {
        let zoom = call(app: "Zoom")
        let meet = call(app: "Google Meet")
        let manual = call()
        let imported = call(imported: true)
        let all = [zoom, meet, manual, imported]
        #expect(LibraryFilter.apply(.all, to: all).count == 4)
        #expect(LibraryFilter.apply(.app("Zoom"), to: all).map(\.id) == [zoom.id])
        #expect(LibraryFilter.apply(.manual, to: all).map(\.id) == [manual.id])
        #expect(LibraryFilter.apply(.imported, to: all).map(\.id) == [imported.id])
    }

    @Test("the search applies on top of the filter")
    func searchOverFilter() {
        let a = call(app: "Zoom")
        a.title = "Budget"
        let b = call(app: "Zoom")
        b.title = "Roadmap"
        let c = call(app: "Teams")
        c.title = "Budget"
        let shown = CallSearch.filter(LibraryFilter.apply(.app("Zoom"), to: [a, b, c]), query: "budget")
        #expect(shown.map(\.id) == [a.id])
    }

    @Test("a filter whose call app has no call any more goes back to Tutte")
    func resolved() {
        let calls = [call(app: "Zoom")]
        #expect(LibraryFilter.resolved(.app("Zoom"), among: calls) == .app("Zoom"))
        #expect(LibraryFilter.resolved(.app("Teams"), among: calls) == .all)
        #expect(LibraryFilter.resolved(.manual, among: calls) == .all)
        #expect(LibraryFilter.resolved(.imported, among: calls) == .all)
    }

    @Test("the card shows Manuale for a recording by hand and Importata for an imported file")
    func appLabel() {
        #expect(call(app: "Zoom").appLabel(language: .italian) == "Zoom")
        #expect(call().appLabel(language: .italian) == "Manuale")
        #expect(call(imported: true).appLabel(language: .italian) == "Importata")
        #expect(call(imported: true).appLabel(language: .english) == "Imported")
    }

    @Test("a folder holds its own calls and every call stays in the archive")
    func folderScope() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let inFolder = try harness.insertCall(.ready)
        let outside = try harness.insertCall(.ready)
        let folder = try #require(harness.lifecycle.createFolder(named: "Clienti"))
        harness.lifecycle.moveCall(inFolder, to: folder)

        let all = try harness.allCalls()
        #expect(all.count == 2)
        #expect(all.filter { $0.folder?.id == folder.id }.map(\.id) == [inFolder.id])
        #expect(outside.folder == nil)
    }
}

@Suite("Find a word", .serialized)
struct TranscriptFindTests {
    private let texts = ["Buongiorno a tutti", "Parliamo del budget", "Il BUDGET è approvato", "Ciao", "Budget finale"]

    @Test("the text is trimmed and matched ignoring case, accents and width; empty finds nothing")
    func matching() {
        let find = TranscriptFind(typed: "  bùdget ", in: texts, heard: nil)
        #expect(find.query == "bùdget")
        #expect(find.found == [1, 2, 4])
        #expect(!TranscriptFind(typed: "   ", in: texts, heard: nil).isActive)
        #expect(TranscriptFind(typed: "   ", in: texts, heard: nil).found.isEmpty)
        #expect(TranscriptFind(typed: "è appróvato", in: texts, heard: nil).found == [2])
        #expect(TranscriptFind(typed: "ＢＵＤＧＥＴ", in: texts, heard: nil).found == [1, 2, 4])
    }

    @Test("the first line shown is the first found one after the line being heard")
    func firstAfterTheLineHeard() {
        #expect(TranscriptFind(typed: "budget", in: texts, heard: nil).currentLine == 1)
        #expect(TranscriptFind(typed: "budget", in: texts, heard: 0).currentLine == 1)
        #expect(TranscriptFind(typed: "budget", in: texts, heard: 1).currentLine == 2)
        #expect(TranscriptFind(typed: "budget", in: texts, heard: 3).currentLine == 4)
        // Nothing after the line heard: the first found line.
        #expect(TranscriptFind(typed: "budget", in: texts, heard: 4).currentLine == 1)
    }

    @Test("the arrows go round from the last to the first, and the other way")
    func arrows() {
        var find = TranscriptFind(typed: "budget", in: texts, heard: 3)
        #expect(find.currentLine == 4)
        #expect(find.counter == (3, 3))
        find.next()
        #expect(find.currentLine == 1)
        #expect(find.counter == (1, 3))
        find.previous()
        #expect(find.currentLine == 4)
        find.previous()
        #expect(find.currentLine == 2)
    }

    @Test("nothing found: no line, a counter of zero and arrows that do nothing")
    func nothingFound() {
        var find = TranscriptFind(typed: "zzz", in: texts, heard: 1)
        #expect(find.isActive)
        #expect(find.currentLine == nil)
        #expect(find.counter == (0, 0))
        find.next()
        find.previous()
        #expect(find.currentLine == nil)
    }

    @Test("the words found are marked, ignoring case and accents")
    func ranges() {
        let text = "Il Budget, il budget e il BÙDGET"
        let ranges = TranscriptFind.ranges(of: "budget", in: text)
        #expect(ranges.map { String(text[$0]) } == ["Budget", "budget", "BÙDGET"])
        #expect(TranscriptFind.ranges(of: "  ", in: text).isEmpty)
    }
}

@Suite("Copy of summary and transcript", .serialized, .italianInterface)
@MainActor
struct CopyTests {
    private func makeCall(in harness: CallHarness) throws -> Call {
        let call = try harness.insertCall(.ready, title: "Riunione", withAudio: false)
        call.lines = [
            TranscriptLine(speakerKind: .me, start: 5, end: 8, text: "Secondo"),
            TranscriptLine(speakerKind: .others, start: 1, end: 4, text: "Primo"),
        ]
        return call
    }

    @Test("the transcript is copied as the export has it, without its heading")
    func transcript() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try makeCall(in: harness)
        let text = try #require(TranscriptExport.transcriptText(for: call, language: .italian))
        #expect(text == "**Altri** [00:01]: Primo\n\n**Io** [00:05]: Secondo")
        #expect(TranscriptExport.markdown(for: call, language: .italian).contains(text))
        #expect(!text.contains("## "))
    }

    @Test("a call without lines has no transcript to copy and one without summary has no summary")
    func nothingToCopy() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready, withAudio: false)
        #expect(TranscriptExport.transcriptText(for: call, language: .italian) == nil)
        #expect(TranscriptExport.summaryText(for: call, language: .italian) == nil)
    }

    @Test("the summary is copied as the export has it, without its heading")
    func summary() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try makeCall(in: harness)
        let summary = CallSummary(keyConcepts: ["Budget"], language: "it-IT")
        call.summary = summary
        let text = try #require(TranscriptExport.summaryText(for: call, language: .italian))
        let markdown = TranscriptExport.markdown(for: call, language: .italian)
        #expect(markdown.contains(text))
        #expect(!text.hasPrefix("## "))
        #expect(text.contains("Budget"))
    }
}
