import Foundation

/// Search of the archive: the text typed is matched, ignoring case and accents,
/// against the title, the transcript text and the participant names of a call.
enum CallSearch {
    /// Lowercased, accent-free form used for comparing.
    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }

    /// An empty search (or one of only spaces) matches every call.
    static func matches(_ call: Call, query: String) -> Bool {
        let needle = normalized(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !needle.isEmpty else { return true }
        return fields(of: call).contains { normalized($0).contains(needle) }
    }

    static func filter(_ calls: [Call], query: String) -> [Call] {
        calls.filter { matches($0, query: query) }
    }

    /// Title as shown (the default one when the user gave none), transcript lines and participant names.
    private static func fields(of call: Call) -> [String] {
        var fields = [call.displayTitle]
        fields.append(contentsOf: call.lines.map(\.text))
        fields.append(contentsOf: call.participants.compactMap(\.name))
        return fields
    }
}
