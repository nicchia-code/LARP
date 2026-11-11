import Foundation

/// What is read from the text Microsoft Teams writes: the title of a meeting and the names of its
/// people. Pure, so the rules can be tested without Teams.
enum TeamsText {
    /// What Teams adds at the end of the title of its windows.
    static let titleSuffix = " | Microsoft Teams"

    /// The names of the sections of Teams, which its main window takes as title; a window titled
    /// like one of them shows no meeting title.
    private static let sectionNames: Set<String> = [
        "microsoft teams", "teams", "chat", "calendar", "calendario", "activity", "attivita", "calls",
        "chiamate", "files", "file", "apps", "app", "home", "communities", "community", "comunita",
        "workflows", "meet", "riunioni",
    ]

    /// The words Teams writes in brackets after the name of the user, in the languages it is
    /// likely to be shown in (compared without accents): the name of the user himself, left out of
    /// the people.
    private static let selfMarkers: Set<String> = ["you", "tu", "vous", "du", "sie", "voce", "usted", "jij"]

    /// The title of the meeting held by a window titled `windowTitle`: without the ending
    /// " | Microsoft Teams"; `nil` when it is empty or the name of a section of Teams.
    static func meetingTitle(fromWindowTitle windowTitle: String?) -> String? {
        guard var title = windowTitle else { return nil }
        if title.hasSuffix(titleSuffix) {
            title.removeLast(titleSuffix.count)
        }
        title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty, !sectionNames.contains(fold(title)) else { return nil }
        return title
    }

    /// The name of a person as Teams wrote it, kept trimmed and without the additions after it
    /// such as "(Ospite)" or "(Guest)"; `nil` when nothing is left, or when the addition says the
    /// person is the user himself ("(Tu)", "(You)").
    static func personName(from raw: String?) -> String? {
        guard var name = raw?.trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        // Every bracketed addition at the end goes, whatever the language of Teams.
        while name.hasSuffix(")"), let open = name.lastIndex(of: "(") {
            let addition = name[name.index(after: open)..<name.index(before: name.endIndex)]
            if selfMarkers.contains(fold(String(addition))) { return nil }
            name = String(name[..<open]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return name.isEmpty ? nil : name
    }

    /// The people of a list of names as read: cleaned, without the user and without repeats, in
    /// order.
    static func people(from names: [String]) -> [String] {
        var seen = Set<String>()
        var people: [String] = []
        for raw in names {
            guard let name = personName(from: raw), seen.insert(fold(name)).inserted else { continue }
            people.append(name)
        }
        return people
    }

    /// Lowercase and without accents, to compare names written differently.
    static func fold(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
