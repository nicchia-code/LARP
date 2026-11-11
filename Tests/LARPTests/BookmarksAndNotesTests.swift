import Foundation
import SwiftData
import Testing

@testable import LARP

@Suite("Bookmarks and notes", .serialized)
@MainActor
struct BookmarksAndNotesTests {
    // MARK: Bookmarks

    @Test("a bookmark during a recording belongs to the call being recorded, at the whole second elapsed")
    func bookmarkDuringRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: nil))
        let call = try #require(try harness.allCalls().first)

        let bookmark = harness.lifecycle.addBookmarkToActiveRecording(atSeconds: 12.7)

        #expect(bookmark?.time == 12)
        #expect(call.bookmarks.map(\.time) == [12])
        #expect(bookmark?.call === call)
    }

    @Test("a bookmark with no recording in progress is not created")
    func bookmarkWithoutRecording() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        #expect(harness.lifecycle.addBookmarkToActiveRecording(atSeconds: 3) == nil)
        #expect(call.bookmarks.isEmpty)
    }

    @Test("a bookmark at the same second as another of the call is not created again")
    func bookmarkSameSecond() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let other = try harness.insertCall(.ready)

        #expect(harness.lifecycle.addBookmark(to: call, at: 30.1) != nil)
        #expect(harness.lifecycle.addBookmark(to: call, at: 30.9) == nil)
        #expect(harness.lifecycle.addBookmark(to: call, at: 31) != nil)
        #expect(harness.lifecycle.addBookmark(to: other, at: 30) != nil)

        #expect(call.sortedBookmarks.map(\.time) == [30, 31])
        #expect(other.bookmarks.map(\.time) == [30])
    }

    @Test("the time of a bookmark is never below zero")
    func bookmarkNeverNegative() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        let bookmark = harness.lifecycle.addBookmark(to: call, at: -4)

        #expect(bookmark?.time == 0)
    }

    @Test("deleting a bookmark removes it from its call and from the archive")
    func deleteBookmark() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let first = try #require(harness.lifecycle.addBookmark(to: call, at: 5))
        harness.lifecycle.addBookmark(to: call, at: 9)

        harness.lifecycle.deleteBookmark(first)

        #expect(call.bookmarks.map(\.time) == [9])
        #expect(try harness.context.fetch(FetchDescriptor<Bookmark>()).map(\.time) == [9])
    }

    // MARK: Notes

    @Test("a note is trimmed, and one that is empty once trimmed is not created")
    func noteText() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        let note = harness.lifecycle.addNote(to: call, text: "  Chiedere il budget \n", at: 10)
        #expect(harness.lifecycle.addNote(to: call, text: " \n\t ", at: 11) == nil)

        #expect(note?.text == "Chiedere il budget")
        #expect(call.notes.count == 1)
    }

    @Test("notes are ordered by time, those without time after the others in the order they were written")
    func noteOrder() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        harness.lifecycle.addNote(to: call, text: "senza tempo 1", at: nil)
        harness.advanceClock(by: 1)
        harness.lifecycle.addNote(to: call, text: "al 40", at: 40)
        harness.advanceClock(by: 1)
        harness.lifecycle.addNote(to: call, text: "senza tempo 2", at: nil)
        harness.advanceClock(by: 1)
        harness.lifecycle.addNote(to: call, text: "al 7", at: 7)

        #expect(call.sortedNotes.map(\.text) == ["al 7", "al 40", "senza tempo 1", "senza tempo 2"])
        #expect(call.sortedNotes.map(\.time) == [7, 40, nil, nil])
    }

    @Test("a note written during a recording takes the time elapsed")
    func noteDuringRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: nil))
        let call = try #require(try harness.allCalls().first)

        let note = harness.lifecycle.addNoteToActiveRecording("Idea", atSeconds: 95)

        #expect(note?.time == 95)
        #expect(call.notes.map(\.text) == ["Idea"])
        #expect(harness.lifecycle.addNoteToActiveRecording("   ", atSeconds: 96) == nil)
    }

    @Test("editing a note with a text that is not empty replaces it and keeps its time")
    func editNote() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let note = try #require(harness.lifecycle.addNote(to: call, text: "Vecchio", at: 22))
        let untimed = try #require(harness.lifecycle.addNote(to: call, text: "Senza", at: nil))

        harness.lifecycle.editNote(note, to: "  Nuovo ")
        harness.lifecycle.editNote(untimed, to: "Ancora senza")

        #expect(note.text == "Nuovo")
        #expect(note.time == 22)
        #expect(untimed.text == "Ancora senza")
        #expect(untimed.time == nil)
    }

    @Test("editing a note to an empty text deletes it")
    func editNoteToEmpty() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let note = try #require(harness.lifecycle.addNote(to: call, text: "Da togliere", at: 3))
        harness.lifecycle.addNote(to: call, text: "Resta", at: 4)

        harness.lifecycle.editNote(note, to: " \n ")

        #expect(call.notes.map(\.text) == ["Resta"])
        #expect(try harness.context.fetch(FetchDescriptor<Note>()).map(\.text) == ["Resta"])
    }

    @Test("deleting a note removes it")
    func deleteNote() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let note = try #require(harness.lifecycle.addNote(to: call, text: "Via", at: nil))

        harness.lifecycle.deleteNote(note)

        #expect(call.notes.isEmpty)
        #expect(try harness.context.fetch(FetchDescriptor<Note>()).isEmpty)
    }

    // MARK: The call

    @Test("deleting a call deletes its bookmarks and notes, and only its own")
    func deletingTheCall() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let doomed = try harness.insertCall(.ready)
        let kept = try harness.insertCall(.ready)
        harness.lifecycle.addBookmark(to: doomed, at: 5)
        harness.lifecycle.addNote(to: doomed, text: "Sparisce", at: 5)
        harness.lifecycle.addBookmark(to: kept, at: 6)
        harness.lifecycle.addNote(to: kept, text: "Resta", at: nil)

        harness.lifecycle.deleteCall(doomed)

        #expect(try harness.context.fetch(FetchDescriptor<Bookmark>()).map(\.time) == [6])
        #expect(try harness.context.fetch(FetchDescriptor<Note>()).map(\.text) == ["Resta"])
    }

    @Test("bookmarks and notes stay when the live lines of the call are discarded")
    func survivesDiscardedLines() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.recording)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "Ciao"))
        harness.lifecycle.addBookmark(to: call, at: 1)
        harness.lifecycle.addNote(to: call, text: "Nota", at: 1)

        harness.lifecycle.discardLines(of: call)

        #expect(call.lines.isEmpty)
        #expect(call.bookmarks.count == 1)
        #expect(call.notes.count == 1)
    }

    @Test("a store holds seven kinds of record, and a call made before bookmarks and notes has none")
    func schemaAndEmptyCall() throws {
        #expect(ArchiveStore.schema.entities.count == 7)
        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        #expect(call.bookmarks.isEmpty)
        #expect(call.notes.isEmpty)
    }

    // MARK: Never sent to omp

    @Test("notes and bookmarks are never in the request of the refinement or of the summary")
    func neverSentToTheAssistant() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        call.lines.append(TranscriptLine(speakerKind: .me, start: 0, end: 2, text: "Buongiorno a tutti"))
        harness.lifecycle.addNote(to: call, text: "Parola segretissima", at: 1)
        harness.lifecycle.addBookmark(to: call, at: 1)

        let refinement = try #require(RefinementRequest(call: call)).prompt
        let summary = try #require(SummaryRequest(call: call, languageChoice: .sameAsCall)).prompt

        #expect(!refinement.contains("segretissima"))
        #expect(!summary.contains("segretissima"))
        #expect(refinement.contains("Buongiorno a tutti"))
    }

    // MARK: Bookmark shortcut

    @Test("the shortcut during a recording adds a bookmark at the time elapsed")
    func shortcutDuringRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: nil))
        let call = try #require(try harness.allCalls().first)
        let playback = PlaybackController()

        BookmarkShortcut.perform(
            recordingElapsedSeconds: 41, playback: playback, lifecycle: harness.lifecycle)

        #expect(call.bookmarks.map(\.time) == [41])
    }

    @Test("the shortcut on a call loaded and playing or paused adds a bookmark at the time reached; stopped it does nothing")
    func shortcutWhileListening() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        let playback = PlaybackController(makePlayer: { _ in StaticPlayer(duration: 60) })
        playback.show(call)

        BookmarkShortcut.perform(recordingElapsedSeconds: nil, playback: playback, lifecycle: harness.lifecycle)
        #expect(call.bookmarks.isEmpty)

        playback.play()
        playback.seek(to: 20.6)
        BookmarkShortcut.perform(recordingElapsedSeconds: nil, playback: playback, lifecycle: harness.lifecycle)
        playback.pause()
        playback.seek(to: 33.2)
        BookmarkShortcut.perform(recordingElapsedSeconds: nil, playback: playback, lifecycle: harness.lifecycle)

        #expect(call.sortedBookmarks.map(\.time) == [20, 33])
    }

    @Test("the shortcut with nothing recorded and no call listened to does nothing")
    func shortcutDoesNothing() throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        BookmarkShortcut.perform(
            recordingElapsedSeconds: nil, playback: PlaybackController(), lifecycle: harness.lifecycle)

        #expect(call.bookmarks.isEmpty)
    }
}

/// A player that plays nothing and stays where it is told.
@MainActor
private final class StaticPlayer: TrackPlayer {
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    var speed: Double = 1

    init(duration: TimeInterval) { self.duration = duration }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) { currentTime = time }
    func stop() {}
    func unload() {}
}
