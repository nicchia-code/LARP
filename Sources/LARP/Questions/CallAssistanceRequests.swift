import Foundation

extension RefinementLine {
    /// The lines of `call` as they are shown (text after refinement and corrections), sorted by
    /// start and then by end, numbered from 1. Shared by the questions and the translation. `nil`
    /// when a line has no participant to send (after the separation every line of the others has
    /// one), so that nothing but "Io" and "Partecipante <numero>" is sent, never a name given by
    /// the user.
    static func shownLines(of call: Call) -> [RefinementLine]? {
        var lines: [RefinementLine] = []
        for (index, line) in call.sortedLines.enumerated() {
            let speaker: RefinementSpeaker
            switch line.speakerKind {
            case .me:
                speaker = .me
            case .participant:
                guard let number = line.participant?.number else { return nil }
                speaker = .participant(number)
            case .others:
                return nil
            }
            lines.append(
                RefinementLine(number: index + 1, speaker: speaker, start: line.start, end: line.end, text: line.text))
        }
        return lines
    }
}

/// What is sent to the assistant to answer a question about a call, and the check of what it
/// answers (`requirements/rules#call-question`). Pure: no process, no model.
struct CallQuestionRequest: Equatable, Sendable {
    /// The lines of the call as shown, in order of start time, numbered from 1.
    let lines: [RefinementLine]
    /// The question as typed, trimmed.
    let question: String

    init(lines: [RefinementLine], question: String) {
        self.lines = lines
        self.question = question.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The lines of `call` as shown and `question`. Nothing else of the call is read: never the
    /// audio, the title, the names given by the user, the meeting information, the notes, the
    /// dates or the call app. `nil` when a line has no participant to send.
    init?(call: Call, question: String) {
        guard let lines = RefinementLine.shownLines(of: call) else { return nil }
        self.init(lines: lines, question: question)
    }

    static let instructions = """
        Sei un assistente che risponde a domande su una conversazione registrata. Ricevi le righe \
        della trascrizione come array JSON; ogni riga ha number, speaker, start, end e text; dopo \
        le righe c'è la domanda.

        Rispondi solo in base alle righe, nella lingua della domanda. Chiama le persone solo "Io" \
        e "Partecipante <numero>", come nel campo speaker, senza indovinare nomi dalla \
        conversazione. Se le righe non lo dicono, rispondi che la call non lo dice.

        Rispondi con testo semplice, senza JSON e senza blocchi di codice.
        """

    /// The instructions, the lines as JSON (`number`, `speaker`, `start`, `end`, `text`) and the question.
    var prompt: String {
        Self.instructions + "\n\n" + RefinementLine.json(lines) + "\n\nDomanda: " + question
    }

    /// The answer: the whole text of the reply, trimmed. `nil` for an empty reply: the question fails.
    static func answer(from reply: String) -> String? {
        let answer = reply.trimmingCharacters(in: .whitespacesAndNewlines)
        return answer.isEmpty ? nil : answer
    }
}

/// What is sent to the assistant to translate the transcript of a call, and the check of what it
/// answers (`requirements/rules#transcript-translation`). Pure: no process, no model.
struct TranscriptTranslationRequest: Equatable, Sendable {
    /// The language the lines are translated into: the other one of the two.
    enum Target: Equatable, Sendable {
        case italian
        case english

        /// English for a call in Italian, Italian for a call in English.
        init(callLanguage: String) {
            let code = Locale(identifier: callLanguage).language.languageCode?.identifier
            self = code == "en" ? .italian : .english
        }

        /// The name in the instructions, in Italian.
        var name: String {
            switch self {
            case .italian: "italiano"
            case .english: "inglese"
            }
        }
    }

    /// The lines of the call as shown, in order of start time, numbered from 1.
    let lines: [RefinementLine]
    let target: Target

    init(lines: [RefinementLine], target: Target) {
        self.lines = lines
        self.target = target
    }

    /// The lines of `call` as shown and the language they are translated into. Nothing else of
    /// the call is read. `nil` when a line has no participant to send.
    init?(call: Call) {
        guard let lines = RefinementLine.shownLines(of: call) else { return nil }
        self.init(lines: lines, target: Target(callLanguage: call.transcriptionLanguage))
    }

    static let instructions = """
        Sei un traduttore di trascrizioni di conversazioni. Ricevi le righe di una trascrizione come \
        array JSON; ogni riga ha number, speaker, start, end e text; dopo le righe c'è la lingua di \
        destinazione.

        Traduci nella lingua di destinazione il testo di ogni riga. Non unire, non dividere, non \
        aggiungere e non togliere righe e non cambiare i parlanti.

        Rispondi solo con JSON, senza testo prima o dopo e senza blocchi di codice: un array con un \
        oggetto per ogni riga ricevuta, con i campi number (lo stesso della riga) e text (il testo \
        tradotto).
        """

    /// The instructions, the lines as JSON and the target language.
    var prompt: String {
        Self.instructions + "\n\n" + RefinementLine.json(lines) + "\n\nLingua di destinazione: " + target.name
    }

    private struct Item: Decodable {
        let number: Int
        let text: String
    }

    /// The translated text of every line by its number, when `answer` is valid: the text from the
    /// first `[` to the last `]` decodes as an array with exactly as many items as lines sent,
    /// every number present once and every text non-empty once trimmed. `nil` otherwise: the
    /// translation fails.
    func translations(from answer: String) -> [Int: String]? {
        guard let open = answer.firstIndex(of: "["), let close = answer.lastIndex(of: "]"), open < close,
            let items = try? JSONDecoder().decode([Item].self, from: Data(answer[open...close].utf8)),
            items.count == lines.count
        else { return nil }
        let numbers = Set(lines.map(\.number))
        var byNumber: [Int: String] = [:]
        for item in items {
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard numbers.contains(item.number), !text.isEmpty, byNumber.updateValue(text, forKey: item.number) == nil
            else { return nil }
        }
        return byNumber
    }
}
