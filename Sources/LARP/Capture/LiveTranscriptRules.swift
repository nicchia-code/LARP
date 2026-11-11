import Foundation

/// What the live window decides about the transcript it shows.
enum LiveTranscriptRules {
    /// How many of the last words of the text being recognised are shown dimmed.
    static let dimmedWordCount = 3

    /// Whether a bookmark at `time` seconds marks `line`: the bookmark was made in the second the
    /// line started or while it lasted. Bookmarks are whole seconds, so the start of the line is
    /// taken down to its second.
    static func isBookmarked(start: TimeInterval, end: TimeInterval, bookmarkTimes: [TimeInterval]) -> Bool {
        let first = start.rounded(.down)
        let last = max(end, first + 1)
        return bookmarkTimes.contains { $0 >= first && $0 < last }
    }

    /// The text being recognised split in what is already steady and its last words, which the
    /// recognition may still change. The two parts joined give `text` again.
    static func splitRecognised(_ text: String) -> (steady: String, tail: String) {
        var wordStarts: [String.Index] = []
        var inWord = false
        for index in text.indices {
            let isSpace = text[index].isWhitespace
            if !isSpace && !inWord { wordStarts.append(index) }
            inWord = !isSpace
        }
        guard wordStarts.count > dimmedWordCount else { return ("", text) }
        let split = wordStarts[wordStarts.count - dimmedWordCount]
        return (String(text[..<split]), String(text[split...]))
    }
}
