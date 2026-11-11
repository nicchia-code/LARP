import Foundation
import Observation

/// What the main window shows (machine `main-window`): one page at a time. It lives as long as the
/// app, so that the library comes back as it was when a call is closed.
@MainActor
@Observable
final class MainWindowModel {
    /// The pages of the window: the library of the recorded calls, the page of one call, the settings.
    enum Page: Equatable {
        case library
        case call(UUID)
        case settings
    }

    /// The text typed in the search field of the library: it stays when a call is opened and the
    /// library comes back.
    var searchText = ""
    private(set) var page: Page = .library
    /// The views of the library: all the calls, the calls of a folder, the action items of every call and
    /// the bookmarks of every call. The library comes back on the one it showed when a call was opened.
    enum LibraryPage: Equatable {
        case allCalls
        case folder(UUID)
        case actions
        case bookmarks
    }
    private(set) var libraryView: LibraryPage = .allCalls
    /// The filter chosen among the chips above the cards (`user.FILTER_BY_APP`): like the search, it
    /// stays when a call is opened and the library comes back.
    private(set) var appFilter: AppFilter = .all
    /// The tab of the page of a call; every call opens on its summary.
    private(set) var callTab: CallPageTab = .summary

    @ObservationIgnored private let playback: PlaybackController
    /// The questions asked about the call shown and their answers (`call-question`); they live as
    /// long as the page of the call stays open.
    let questions: CallQuestions
    /// The translation of the transcript of the call shown (`transcript-translation`).
    let translation: TranscriptTranslation

    init(
        playback: PlaybackController = .shared,
        questions: CallQuestions = CallQuestions(),
        translation: TranscriptTranslation = TranscriptTranslation()
    ) {
        self.playback = playback
        self.questions = questions
        self.translation = translation
    }

    /// The call shown, if the page is the page of a call.
    var shownCallID: UUID? {
        if case .call(let id) = page { id } else { nil }
    }

    /// `user.SELECT_CALL`: the page of the call opens on its summary (the page loads its audio).
    func selectCall(_ id: UUID) {
        callTab = .summary
        page = .call(id)
    }

    /// `user.SELECT_BOOKMARK`, from the bookmarks view: the page of the call of the bookmark opens on
    /// its bookmarks, its audio is loaded and plays from the bookmark.
    func selectBookmark(_ bookmark: Bookmark, of call: Call) {
        callTab = .bookmarks
        page = .call(call.id)
        playback.selectBookmark(at: bookmark.time, of: call)
    }

    /// `user.SHOW_ALL_CALLS`: the library shows all calls; from the page of a call it goes back to the
    /// library, as `user.DESELECT_CALL` does.
    func showAllCalls() {
        libraryView = .allCalls
        showLibrary()
    }

    /// `user.SHOW_ACTIONS_VIEW`: the library shows the action items of every call.
    func showActionsView() {
        libraryView = .actions
        showLibrary()
    }

    /// `user.SHOW_BOOKMARKS_VIEW`: the library shows the bookmarks of every call.
    func showBookmarksView() {
        libraryView = .bookmarks
        showLibrary()
    }

    /// `user.SHOW_FOLDER`: the library shows the calls of a folder.
    func showFolder(_ id: UUID) {
        libraryView = .folder(id)
        showLibrary()
    }

    /// `user.DELETE_FOLDER`: when the folder deleted is the one shown, the library goes back to all
    /// calls.
    func folderDeleted(_ id: UUID) {
        if libraryView == .folder(id) { libraryView = .allCalls }
    }

    /// `user.FILTER_BY_APP`: only the calls of the chip chosen are shown; "Tutte" shows every call.
    func filterByApp(_ filter: AppFilter) {
        appFilter = filter
    }

    /// `user.SHOW_SUMMARY`, `user.SHOW_NOTES`, `user.SHOW_BOOKMARKS`: the tab of the page of a call.
    func showTab(_ tab: CallPageTab) {
        callTab = tab
    }

    /// `user.DESELECT_CALL`, `call.DELETED` for the call shown, `user.CANCEL_DELETION` is not a
    /// change of page: back to the library, on the view it showed before, with the audio unloaded;
    /// the questions and the translation are dropped, the processes of omp end at once.
    func showLibrary() {
        if shownCallID != nil { playback.show(nil) }
        questions.deselectCall()
        translation.deselectCall()
        page = .library
    }

    /// `user.OPEN_SETTINGS`: the page shown before is left and the audio of a call shown is unloaded;
    /// the questions and the translation are dropped, the processes of omp end at once.
    func showSettings() {
        if shownCallID != nil { playback.show(nil) }
        questions.openSettings()
        translation.openSettings()
        page = .settings
    }

    /// `user.CLOSE_SETTINGS`: the library, on all calls.
    func closeSettings() {
        page = .library
        libraryView = .allCalls
    }

    /// `user.OPEN_WINDOW` on a closed window: the window opens on the library, on all calls.
    func windowOpened() {
        page = .library
        libraryView = .allCalls
    }

    /// `user.CLOSE_WINDOW`: the playback stops and the audio is unloaded; the questions and the
    /// translation are dropped, the processes of omp end at once.
    func windowClosed() {
        playback.stop()
        playback.show(nil)
        questions.closeWindow()
        translation.closeWindow()
        page = .library
        libraryView = .allCalls
    }

    /// `call.DELETED`: the questions and the translation of the call deleted are dropped; when it
    /// is the call shown, back to the library.
    func callDeleted(_ id: UUID) {
        questions.callDeleted(id)
        translation.callDeleted(id)
        if shownCallID == id { showLibrary() }
    }

    /// `call.TRANSCRIPT_REFINED`: the translation of the call shown is dropped.
    func transcriptRefined(_ id: UUID) {
        translation.transcriptRefined(id)
    }

    /// `user.EDIT_LINE`: the translation of the transcript is dropped, or the one in progress ended,
    /// and the line takes the text typed over its original text (the call machine does that).
    func editLine(_ line: TranscriptLine, of call: Call, to text: String, lifecycle: CallLifecycle) {
        translation.editLine()
        lifecycle.editLine(line, of: call, to: text)
    }

    /// `user.TURN_OFF_QUESTIONS`: the question being answered and the translation in progress end
    /// at once.
    func questionsTurnedOff() {
        questions.turnOffQuestions()
        translation.turnOffQuestions()
    }
}
