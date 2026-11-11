import Foundation

/// "Trova una parola" in the transcript panel: the text typed is trimmed and looked for in the text
/// of every line as shown, ignoring case, accents and character width. The first line shown is the
/// first found one after the line being heard; the arrows go round from the last to the first.
struct TranscriptFind: Equatable {
    /// The comparison of the text typed and the text of a line.
    static let options: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]

    /// The text typed, trimmed; empty means nothing is looked for.
    let query: String
    /// The indexes, in the lines shown, of the lines that contain the text, in order.
    let found: [Int]
    /// The position in `found` of the found line being looked at; `nil` when nothing is found.
    private(set) var position: Int?

    /// Looks for `typed` in `texts`, the text shown of every line in order. `heard` is the index of
    /// the line being heard: the first found line after it is the one looked at first, or the first
    /// found line when none follows it.
    init(typed: String, in texts: [String], heard: Int?) {
        let query = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let found =
            query.isEmpty ? [] : texts.indices.filter { texts[$0].range(of: query, options: Self.options) != nil }
        self.query = query
        self.found = found
        if found.isEmpty {
            position = nil
        } else if let heard, let next = found.firstIndex(where: { $0 > heard }) {
            position = next
        } else {
            position = 0
        }
    }

    /// Text is being looked for.
    var isActive: Bool { !query.isEmpty }

    /// The index, in the lines shown, of the found line being looked at.
    var currentLine: Int? { position.map { found[$0] } }

    /// The next found line, going round from the last to the first (the down arrow).
    mutating func next() {
        guard let position else { return }
        self.position = (position + 1) % found.count
    }

    /// The previous found line, going round from the first to the last (the up arrow).
    mutating func previous() {
        guard let position else { return }
        self.position = (position + found.count - 1) % found.count
    }

    /// The counter "<n> di <m>" of the field: the position of the line looked at among the found
    /// ones, and how many there are.
    var counter: (position: Int, total: Int) {
        ((position ?? -1) + 1, found.count)
    }

    /// The parts of `text` that match `query`, to be marked.
    static func ranges(of query: String, in text: String) -> [Range<String.Index>] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var start = text.startIndex
        while start < text.endIndex,
            let range = text.range(of: query, options: options, range: start..<text.endIndex)
        {
            ranges.append(range)
            start = range.upperBound
        }
        return ranges
    }
}
