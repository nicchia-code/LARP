import Foundation

/// The summary of a call as the archive shows it, searches it and exports it: the opening sentence
/// and the sections in a fixed order (decisions, action items, left open, key concepts and the free
/// text when there is one), with titles in the language of the interface and the names the user gave
/// to the participants in place of "Partecipante <number>" ("Participant <number>" in the English
/// interface). The summary stored on the call is never changed; this is built from it each time. The
/// view, the list of actions, the card, the search and the Markdown export all use it, so they always
/// agree.
struct SummaryContent: Equatable {
    /// The opening sentence, split around its key part.
    struct Opening: Equatable {
        let before: String
        /// The key part; empty when the summary names none or it is not in the sentence.
        let key: String
        let after: String

        var plain: String { before + key + after }

        /// The sentence with its key part in `**bold**`.
        var markdown: String { key.isEmpty ? plain : "\(before)**\(key)**\(after)" }
    }

    /// A decision: its text and the start of the line where it was taken, when it has one.
    struct Decision: Equatable {
        let text: String
        let lineStart: TimeInterval?
    }

    /// An action item as shown: its text, its owner with the participant's current name, and its due as
    /// said in the call.
    struct Action: Equatable {
        /// Its place among the action items of the summary, which `CallLifecycle.toggleActionItem` takes.
        let index: Int
        let text: String
        let owner: String?
        /// Who the avatar of the owner stands for.
        let ownerKind: SpeakerKind
        let ownerParticipant: Int?
        /// The first letter of the owner as shown; the number of an unnamed participant.
        let ownerInitial: String?
        let due: String?
        let isDone: Bool

        /// `<text> · <owner> · <due>`, each part only when present.
        var line: String {
            [text, owner, due].compactMap { $0 }.joined(separator: " · ")
        }
    }

    struct Section: Equatable {
        enum Body: Equatable {
            /// A bulleted list.
            case items([String])
            /// The decisions, numbered, each with the time of its line when it has one.
            case decisions([Decision])
            /// The action items, each with its tick.
            case actions([Action])
            /// An empty list, with the text that says so ("Nessuno" / "None").
            case none(String)
            /// The free text.
            case text(String)
        }

        /// Which section it is, whatever the language of its title.
        enum Kind: Equatable {
            case decisions
            case actionItems
            case leftOpen
            case keyConcepts
            case other
        }

        let kind: Kind
        let title: String
        let body: Body
    }

    /// `nil` when the summary has no opening sentence (one written before it existed).
    let opening: Opening?
    /// Decisions, action items, left open, key concepts and, when it is not empty, the free text.
    let sections: [Section]
    /// The language of the interface the titles are in.
    let language: AppLanguage

    /// The summary of `call` as shown now; `nil` when the call has none.
    init?(call: Call, language: AppLanguage = .current) {
        guard let summary = call.summary else { return nil }
        let names = Dictionary(
            call.participants.compactMap { participant in
                participant.name.flatMap { $0.isEmpty ? nil : (participant.number, $0) }
            },
            uniquingKeysWith: { first, _ in first }
        )
        let words = Words(language: language)
        self.language = language

        func shown(_ text: String) -> String {
            Self.replacingParticipants(in: text, names: names, language: language)
        }
        func list(_ kind: Section.Kind, _ title: String, _ items: [String]) -> Section {
            Section(kind: kind, title: title, body: items.isEmpty ? .none(words.none) : .items(items.map(shown)))
        }

        let sentence = shown(summary.opening)
        if sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            opening = nil
        } else {
            let key = shown(summary.openingHighlight)
            if !key.isEmpty, let range = sentence.range(of: key) {
                opening = Opening(
                    before: String(sentence[..<range.lowerBound]), key: key,
                    after: String(sentence[range.upperBound...]))
            } else {
                opening = Opening(before: sentence, key: "", after: "")
            }
        }

        let decisions = summary.decisionItems.map { Decision(text: shown($0.text), lineStart: $0.lineStart) }
        let actions = summary.actionItems.enumerated().map { index, action in
            let owner = action.owner.flatMap { $0.isEmpty ? nil : $0 }
            let due = action.due.flatMap { $0.isEmpty ? nil : $0 }
            let (kind, number) = Self.speaker(ofOwner: owner)
            return Action(
                index: index, text: shown(action.text), owner: owner.map(shown), ownerKind: kind,
                ownerParticipant: number, ownerInitial: owner.map { Self.initial(ofOwner: $0, names: names, shown: shown) },
                due: due.map(shown), isDone: action.isDone)
        }

        var sections = [
            Section(kind: .decisions, title: words.decisions, body: decisions.isEmpty ? .none(words.none) : .decisions(decisions)),
            Section(kind: .actionItems, title: words.actionItems, body: actions.isEmpty ? .none(words.none) : .actions(actions)),
            list(.leftOpen, words.leftOpen, summary.openQuestions),
            list(.keyConcepts, words.keyConcepts, summary.keyConcepts),
        ]
        let text = summary.text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !text.isEmpty {
            sections.append(Section(kind: .other, title: words.other, body: .text(shown(text))))
        }
        self.sections = sections
    }

    /// The action items, in the order of the summary.
    var actions: [Action] {
        for section in sections {
            if case .actions(let actions) = section.body { return actions }
        }
        return []
    }

    /// How many action items are not done yet.
    var openActionCount: Int {
        actions.filter { !$0.isDone }.count
    }

    /// Every text of the summary a search looks into: the opening sentence, titles, items, owners, dues
    /// and free text; not the "Nessuno" / "None" that stands for an empty list.
    var searchableTexts: [String] {
        var texts = opening.map { [$0.plain] } ?? []
        for section in sections {
            texts.append(section.title)
            switch section.body {
            case .items(let items): texts.append(contentsOf: items)
            case .decisions(let decisions): texts.append(contentsOf: decisions.map(\.text))
            case .actions(let actions):
                for action in actions { texts.append(contentsOf: [action.text, action.owner, action.due].compactMap { $0 }) }
            case .none: break
            case .text(let text): texts.append(text)
            }
        }
        return texts
    }

    /// Markdown of the summary: `## Sintesi` (`## Summary`), the opening sentence as a paragraph with its
    /// key part in bold, then one `### <title>` per section with its list as `- <text>` lines (decisions
    /// as `- [<clock>] <text>`, action items as `- [x] <item>` or `- [ ] <item>`), or the word of the empty
    /// list, or its free text as a paragraph; as paragraphs to be separated by a blank line.
    var markdownParagraphs: [String] {
        var paragraphs = ["## \(L10n.string("Sintesi", language: language))"]
        if let opening { paragraphs.append(opening.markdown) }
        for section in sections {
            paragraphs.append("### \(section.title)")
            switch section.body {
            case .items(let items): paragraphs.append(items.map { "- \($0)" }.joined(separator: "\n"))
            case .decisions(let decisions):
                paragraphs.append(
                    decisions.map { decision in
                        decision.lineStart.map { "- [\(ArchiveFormat.clock($0))] \(decision.text)" } ?? "- \(decision.text)"
                    }.joined(separator: "\n"))
            case .actions(let actions):
                paragraphs.append(actions.map { "- [\($0.isDone ? "x" : " ")] \($0.line)" }.joined(separator: "\n"))
            case .none(let label): paragraphs.append(label)
            case .text(let text): paragraphs.append(text)
            }
        }
        return paragraphs
    }

    // MARK: Owners

    /// Who an owner as the assistant wrote it stands for: "Io", a "Partecipante <number>", else nobody in
    /// particular.
    private static func speaker(ofOwner owner: String?) -> (SpeakerKind, Int?) {
        guard let owner else { return (.others, nil) }
        if owner == "Io" { return (.me, nil) }
        if let number = participantNumber(in: owner) { return (.participant, number) }
        return (.others, nil)
    }

    /// The first letter of the owner as shown; for an unnamed participant, its number.
    private static func initial(ofOwner owner: String, names: [Int: String], shown: (String) -> String) -> String {
        if let number = participantNumber(in: owner), names[number] == nil { return String(number) }
        return shown(owner).first.map { String($0).uppercased() } ?? ""
    }

    /// The number of an owner that is exactly "Partecipante <number>".
    private static func participantNumber(in owner: String) -> Int? {
        guard owner.hasPrefix("Partecipante "), let number = Int(owner.dropFirst("Partecipante ".count)) else { return nil }
        return number
    }

    // MARK: Names

    /// `text` with every "Partecipante <number>" of a participant who has a name replaced by it, or
    /// by "Participant <number>" in the English interface.
    static func replacingParticipants(in text: String, names: [Int: String], language: AppLanguage = .current) -> String {
        guard !names.isEmpty || language == .english, text.contains("Partecipante") else { return text }
        guard let pattern = try? NSRegularExpression(pattern: #"Partecipante (\d+)(?!\d)"#) else { return text }
        let source = text as NSString
        var result = text
        for match in pattern.matches(in: text, range: NSRange(location: 0, length: source.length)).reversed() {
            guard let number = Int(source.substring(with: match.range(at: 1))),
                let name = names[number] ?? (language == .english ? "Participant \(number)" : nil),
                let range = Range(match.range, in: result)
            else { continue }
            result.replaceSubrange(range, with: name)
        }
        return result
    }

    // MARK: Titles

    /// Section titles and the word for an empty list, in the language of the interface.
    private struct Words {
        let decisions: String
        let actionItems: String
        let leftOpen: String
        let keyConcepts: String
        let other: String
        let none: String

        init(language: AppLanguage) {
            decisions = L10n.string("Decisioni", language: language)
            actionItems = L10n.string("Azioni", language: language)
            leftOpen = L10n.string("Rimasto aperto", language: language)
            keyConcepts = L10n.string("Concetti chiave", language: language)
            other = L10n.string("Altro", language: language)
            none = L10n.string("Nessuno", language: language)
        }
    }
}
