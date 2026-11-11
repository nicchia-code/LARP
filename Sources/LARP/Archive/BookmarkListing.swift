import Foundation

/// One bookmark as the bookmarks of a call and the list of every bookmark show it: its time and
/// the text of the transcript line at that time, when there is one.
struct BookmarkRow: Identifiable {
    let bookmark: Bookmark
    /// The text of the transcript line heard at the time of the bookmark.
    let lineText: String?

    var id: UUID { bookmark.id }
    var time: TimeInterval { bookmark.time }
}

/// The bookmarks of one call, in order of time.
struct BookmarkGroup: Identifiable {
    let call: Call
    let rows: [BookmarkRow]

    var id: UUID { call.id }
}

/// What the "Segnalibri" view of the library and the "Segnalibri" tab of a call page list.
enum BookmarkListing {
    /// The bookmarks of the calls that match the search, grouped by call, the most recent call first
    /// and in order of time within a call. A call without bookmarks is left out.
    static func groups(of calls: [Call], query: String) -> [BookmarkGroup] {
        CallSearch.filter(calls, query: query)
            .filter { !$0.bookmarks.isEmpty }
            .sorted { $0.startedAt != $1.startedAt ? $0.startedAt > $1.startedAt : $0.id.uuidString < $1.id.uuidString }
            .map { BookmarkGroup(call: $0, rows: rows(of: $0)) }
    }

    /// The bookmarks of a call in order of time, each with the text of the line at its time.
    static func rows(of call: Call) -> [BookmarkRow] {
        let lines = call.sortedLines
        let timeline = TranscriptTimeline(spans: lines.map { LineTiming(start: $0.start, end: $0.end) })
        return call.sortedBookmarks.map { bookmark in
            BookmarkRow(
                bookmark: bookmark,
                lineText: timeline.lineIndex(at: bookmark.time).map { lines[$0].text })
        }
    }

    /// The seconds of the bookmarks of a call, for the ticks above the timeline of the playback bar.
    static func times(of call: Call) -> [TimeInterval] {
        call.sortedBookmarks.map(\.time)
    }

    /// The indexes, in `Call.sortedLines`, of the lines heard at the time of a bookmark of the call:
    /// the lines that carry "SEGNALIBRO" in the transcript.
    static func bookmarkedLineIndexes(of call: Call) -> Set<Int> {
        let lines = call.sortedLines
        let timeline = TranscriptTimeline(spans: lines.map { LineTiming(start: $0.start, end: $0.end) })
        return Set(call.bookmarks.compactMap { timeline.lineIndex(at: $0.time) })
    }
}
