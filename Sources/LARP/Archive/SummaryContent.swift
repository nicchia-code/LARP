import Foundation

/// The summary of a call as the archive shows it, searches it and exports it: sections in a
/// fixed order, with titles in the language of the summary and the names the user gave to the
/// participants in place of "Partecipante <number>". The summary stored on the call is never
/// changed; this is built from it each time. The view, the search and the Markdown export all
/// use it, so they always agree.
struct SummaryContent: Equatable {
    struct Section: Equatable {
        enum Body: Equatable {
            /// A bulleted list.
            case items([String])
            /// An empty list, with the text that says so ("Nessuno" / "None").
            case none(String)
            /// The free text.
            case text(String)
        }

        let title: String
        let body: Body
    }

    /// Key concepts, decisions, next steps and, when it is not empty, the free text.
    let sections: [Section]

    /// The summary of `call` as shown now; `nil` when the call has none.
    init?(call: Call) {
        guard let summary = call.summary else { return nil }
        let names = Dictionary(
            call.participants.compactMap { participant in
                participant.name.flatMap { $0.isEmpty ? nil : (participant.number, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let words = Words(language: summary.language)

        func shown(_ text: String) -> String {
            Self.replacingParticipants(in: text, names: names)
        }
        func list(_ title: String, _ items: [String]) -> Section {
            Section(title: title, body: items.isEmpty ? .none(words.none) : .items(items.map(shown)))
        }

        var sections = [
            list(words.keyConcepts, summary.keyConcepts),
            list(words.decisions, summary.decisions),
            list(
                words.nextSteps,
                summary.nextSteps.map { step in
                    guard let owner = step.owner, !owner.isEmpty else { return step.text }
                    return "\(step.text) (\(owner))"
                }
            ),
        ]
        let text = summary.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            sections.append(Section(title: words.other, body: .text(shown(text))))
        }
        self.sections = sections
    }

    /// Every text of the summary a search looks into: titles, items and free text; not the
    /// "Nessuno" / "None" that stands for an empty list.
    var searchableTexts: [String] {
        sections.flatMap { section -> [String] in
            switch section.body {
            case .items(let items): [section.title] + items
            case .none: [section.title]
            case .text(let text): [section.title, text]
            }
        }
    }

    /// Markdown of the summary: `## Sintesi`, then one `### <title>` per section with its list
    /// as `- <text>` or its free text as a paragraph, as paragraphs to be separated by a blank line.
    var markdownParagraphs: [String] {
        var paragraphs = ["## Sintesi"]
        for section in sections {
            paragraphs.append("### \(section.title)")
            switch section.body {
            case .items(let items): paragraphs.append(items.map { "- \($0)" }.joined(separator: "\n"))
            case .none(let label): paragraphs.append(label)
            case .text(let text): paragraphs.append(text)
            }
        }
        return paragraphs
    }

    // MARK: Names

    /// `text` with every "Partecipante <number>" of a participant who has a name replaced by it.
    static func replacingParticipants(in text: String, names: [Int: String]) -> String {
        guard !names.isEmpty, text.contains("Partecipante") else { return text }
        guard let pattern = try? NSRegularExpression(pattern: #"Partecipante (\d+)(?!\d)"#) else { return text }
        let source = text as NSString
        var result = text
        for match in pattern.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            guard let number = Int(source.substring(with: match.range(at: 1))),
                let name = names[number],
                let range = Range(match.range, in: result)
            else { continue }
            result.replaceSubrange(range, with: name)
        }
        return result
    }

    // MARK: Titles

    /// Section titles and the word for an empty list, in the language of the summary.
    private struct Words {
        let keyConcepts: String
        let decisions: String
        let nextSteps: String
        let other: String
        let none: String

        init(language: String) {
            if Locale(identifier: language).language.languageCode?.identifier == "en" {
                keyConcepts = "Key concepts"
                decisions = "Decisions"
                nextSteps = "Next steps"
                other = "Other"
                none = "None"
            } else {
                keyConcepts = "Concetti chiave"
                decisions = "Decisioni"
                nextSteps = "Prossimi passi"
                other = "Altro"
                none = "Nessuno"
            }
        }
    }
}
