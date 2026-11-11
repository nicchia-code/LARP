import Foundation
import Testing

@testable import LARP

@MainActor
private final class RecordingPlayer: TrackPlayer {
    let duration: TimeInterval
    var currentTime: TimeInterval = 0
    var onInterrupted: (@MainActor (TimeInterval) -> Void)?
    var speed: Double = 1
    private(set) var starts: [TimeInterval] = []

    init(duration: TimeInterval) { self.duration = duration }

    func start(at time: TimeInterval, onFinished: @escaping @MainActor () -> Void) {
        starts.append(time)
        currentTime = time
    }

    func stop() {}
    func unload() {}
}

@Suite("BookmarkListing", .italianInterface)
@MainActor
struct BookmarkListingTests {
    private func makeCall(
        title: String? = "Call", startedAt: Date = Date(timeIntervalSince1970: 1_000_000),
        bookmarks: [TimeInterval] = [], lines: [(TimeInterval, TimeInterval, String)] = []
    ) -> Call {
        let call = Call(title: title, startedAt: startedAt, duration: 600, transcriptionLanguage: "it-IT", state: .ready)
        for time in bookmarks { call.bookmarks.append(Bookmark(time: time)) }
        for (start, end, text) in lines {
            call.lines.append(TranscriptLine(speakerKind: .others, start: start, end: end, text: text))
        }
        return call
    }

    @Test("a call without bookmarks is left out")
    func leavesOutCallsWithoutBookmarks() {
        let with = makeCall(title: "Con", bookmarks: [5])
        let without = makeCall(title: "Senza")
        #expect(BookmarkListing.groups(of: [without, with], query: "").map(\.call) == [with])
    }

    @Test("calls are grouped with the most recent call first, bookmarks in order of time within a call")
    func ordering() {
        let older = makeCall(title: "Vecchia", startedAt: Date(timeIntervalSince1970: 1_000), bookmarks: [90, 10, 50])
        let newer = makeCall(title: "Nuova", startedAt: Date(timeIntervalSince1970: 5_000), bookmarks: [20, 3])

        let groups = BookmarkListing.groups(of: [older, newer], query: "")

        #expect(groups.map(\.call) == [newer, older])
        #expect(groups[0].rows.map(\.time) == [3, 20])
        #expect(groups[1].rows.map(\.time) == [10, 50, 90])
    }

    @Test("only the bookmarks of the calls that match the search are listed")
    func searchFiltersCalls() {
        let budget = makeCall(title: "Budget", bookmarks: [5], lines: [(0, 10, "Parliamo del preventivo")])
        let other = makeCall(title: "Altro", bookmarks: [5], lines: [(0, 10, "Niente di rilevante")])

        #expect(BookmarkListing.groups(of: [budget, other], query: "PREVENTIVO").map(\.call) == [budget])
        #expect(BookmarkListing.groups(of: [budget, other], query: "  ").count == 2)
        #expect(BookmarkListing.groups(of: [budget, other], query: "inesistente").isEmpty)
    }

    @Test("the search also matches the text of the notes of a call")
    func searchMatchesNotes() {
        let call = makeCall(title: "Budget", bookmarks: [5])
        call.notes.append(Note(text: "Chiedere il preventivo a Marta"))
        let other = makeCall(title: "Altro", bookmarks: [5])

        #expect(BookmarkListing.groups(of: [call, other], query: "MARTA").map(\.call) == [call])
    }

    @Test("a bookmark shows the text of the line heard at its time")
    func lineText() {
        let call = makeCall(
            bookmarks: [4, 12, 25],
            lines: [(0, 5, "Buongiorno a tutti"), (5, 10, "Iniziamo"), (20, 30, "Chiudiamo qui")])

        let rows = BookmarkListing.rows(of: call)

        #expect(rows.map(\.lineText) == ["Buongiorno a tutti", nil, "Chiudiamo qui"])
    }

    @Test("the end of a line belongs to what follows, and the line that started last wins when lines overlap")
    func lineBoundaries() {
        let call = makeCall(
            bookmarks: [5, 8],
            lines: [(0, 10, "Lunga"), (5, 9, "Dentro")])

        let rows = BookmarkListing.rows(of: call)

        #expect(rows.map(\.lineText) == ["Dentro", "Dentro"])
    }

    @Test("a call without lines lists its bookmarks with no text")
    func noLines() {
        let call = makeCall(bookmarks: [7])
        #expect(BookmarkListing.rows(of: call).map(\.lineText) == [nil])
    }

    @Test("the ticks of the playback bar are the times of the bookmarks in order")
    func ticks() {
        let call = makeCall(bookmarks: [30, 5, 12])
        #expect(BookmarkListing.times(of: call) == [5, 12, 30])
    }

    @Test("the lines that carry the bookmark mark are those heard at a bookmark time")
    func bookmarkedLines() {
        let call = makeCall(
            bookmarks: [2, 7, 40],
            lines: [(0, 5, "Uno"), (5, 10, "Due"), (10, 20, "Tre")])

        // Sorted lines: 0 "Uno", 1 "Due", 2 "Tre"; the bookmark at 40 falls in silence.
        #expect(BookmarkListing.bookmarkedLineIndexes(of: call) == [0, 1])
    }
}

@Suite("PlaybackSelectBookmark")
@MainActor
struct PlaybackSelectBookmarkTests {
    private func makeCall(state: CallState = .ready) -> Call {
        Call(duration: 60, transcriptionLanguage: "it-IT", state: state)
    }

    private func makeController(duration: TimeInterval = 60) -> (PlaybackController, RecordingPlayer) {
        let player = RecordingPlayer(duration: duration)
        return (PlaybackController(makePlayer: { _ in player }), player)
    }

    @Test("from Stopped, a bookmark of a call that is not loaded loads its audio and plays from the bookmark")
    func fromStoppedLoadsTheCall() {
        let (controller, player) = makeController()
        let call = makeCall()

        controller.selectBookmark(at: 17, of: call)

        #expect(controller.callID == call.id)
        #expect(controller.state == .playing)
        #expect(player.starts == [17])
    }

    @Test("while Playing it goes on from the time of the bookmark")
    func whilePlaying() {
        let (controller, player) = makeController()
        let call = makeCall()
        controller.show(call)
        controller.play()

        controller.selectBookmark(at: 30, of: call)

        #expect(controller.state == .playing)
        #expect(player.starts == [0, 30])
    }

    @Test("while Paused it plays from the time of the bookmark")
    func whilePaused() {
        let (controller, player) = makeController()
        let call = makeCall()
        controller.show(call)
        controller.play()
        controller.pause()

        controller.selectBookmark(at: 45, of: call)

        #expect(controller.state == .playing)
        #expect(player.starts == [0, 45])
    }

    @Test("a call without audio to play stays Stopped")
    func withoutAudio() {
        let (controller, player) = makeController(duration: 0)

        controller.selectBookmark(at: 10, of: makeCall())

        #expect(controller.state == .stopped)
        #expect(player.starts.isEmpty)
    }

    @Test("a bookmark of another call stops the audio of the call that was loaded")
    func otherCall() {
        let first = RecordingPlayer(duration: 60)
        let second = RecordingPlayer(duration: 60)
        let players = [first, second]
        var made = 0
        let controller = PlaybackController(makePlayer: { _ in
            defer { made += 1 }
            return players[made]
        })
        let one = makeCall()
        let two = makeCall()
        controller.show(one)
        controller.play()

        controller.selectBookmark(at: 8, of: two)

        #expect(controller.callID == two.id)
        #expect(second.starts == [8])
        #expect(controller.state == .playing)
    }
}

@Suite("MainWindowBookmarks")
@MainActor
struct MainWindowBookmarksTests {
    private func makeModel() -> (MainWindowModel, RecordingPlayer) {
        let player = RecordingPlayer(duration: 60)
        let playback = PlaybackController(makePlayer: { _ in player })
        return (MainWindowModel(playback: playback), player)
    }

    private func makeCall() -> Call {
        Call(duration: 60, transcriptionLanguage: "it-IT", state: .ready)
    }

    @Test("the library starts on all calls and a call opens on its summary")
    func initialViews() {
        let (model, _) = makeModel()
        #expect(model.libraryView == .allCalls)
        model.selectCall(UUID())
        #expect(model.callTab == .summary)
    }

    @Test("user.SHOW_BOOKMARKS_VIEW and user.SHOW_ALL_CALLS switch the view of the library")
    func switchViews() {
        let (model, _) = makeModel()
        model.showBookmarksView()
        #expect(model.libraryView == .bookmarks)
        #expect(model.page == .library)
        model.showAllCalls()
        #expect(model.libraryView == .allCalls)
    }

    @Test("the search stays when the view of the library changes")
    func searchStays() {
        let (model, _) = makeModel()
        model.searchText = "budget"
        model.showBookmarksView()
        #expect(model.searchText == "budget")
    }

    @Test("user.SELECT_BOOKMARK opens the page of the call on its bookmarks and plays from the bookmark")
    func selectBookmark() {
        let (model, player) = makeModel()
        let call = makeCall()
        let bookmark = Bookmark(time: 25)
        call.bookmarks.append(bookmark)
        model.showBookmarksView()

        model.selectBookmark(bookmark, of: call)

        #expect(model.page == .call(call.id))
        #expect(model.callTab == .bookmarks)
        #expect(player.starts == [25])
    }

    @Test("coming back from a call the library shows the view it was opened from")
    func returnsToTheView() {
        let (model, _) = makeModel()
        let call = makeCall()
        let bookmark = Bookmark(time: 3)
        call.bookmarks.append(bookmark)
        model.showBookmarksView()
        model.selectBookmark(bookmark, of: call)

        model.showLibrary()

        #expect(model.page == .library)
        #expect(model.libraryView == .bookmarks)

        // The same after the call is deleted while it is shown.
        model.selectBookmark(bookmark, of: call)
        model.callDeleted(call.id)
        #expect(model.libraryView == .bookmarks)
    }

    @Test("user.SHOW_NOTES and user.SHOW_BOOKMARKS change the tab; another call opens on its summary again")
    func tabs() {
        let (model, _) = makeModel()
        model.selectCall(UUID())
        model.showTab(.notes)
        #expect(model.callTab == .notes)
        model.showTab(.bookmarks)
        #expect(model.callTab == .bookmarks)
        model.showLibrary()
        model.selectCall(UUID())
        #expect(model.callTab == .summary)
    }

    @Test("closing the window or the settings brings the library back on all calls")
    func resets() {
        let (model, _) = makeModel()
        model.showBookmarksView()
        model.windowClosed()
        #expect(model.libraryView == .allCalls)
        model.showBookmarksView()
        model.showSettings()
        model.closeSettings()
        #expect(model.libraryView == .allCalls)
    }
}
