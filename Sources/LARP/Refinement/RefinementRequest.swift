import Foundation

/// The speaker a refinement correction gives to a line.
enum RefinementSpeaker: Equatable, Sendable {
    case me
    case participant(Int)

    /// "Io" or "Partecipante <numero>": what is sent to the assistant and what it
    /// answers. Never "Altri" and never a name given by the user.
    var label: String {
        switch self {
        case .me: "Io"
        case .participant(let number): "Partecipante \(number)"
        }
    }

    init?(label: String) {
        if label == "Io" {
            self = .me
            return
        }
        let prefix = "Partecipante "
        guard label.hasPrefix(prefix), let number = Int(label.dropFirst(prefix.count)),
            number > 0, label == "\(prefix)\(number)"
        else { return nil }
        self = .participant(number)
    }
}

/// A line as it is sent to the assistant: the original text and speaker.
struct RefinementLine: Equatable, Sendable {
    let number: Int
    let speaker: RefinementSpeaker
    let start: TimeInterval
    let end: TimeInterval
    let text: String

    /// The original lines of `call` in order of start time, numbered from 1: a call
    /// refined before gives its original text and speakers, never the refined ones.
    /// Shared by refinement and summary. `nil` when a line has no participant to send
    /// (after the separation every line of the others has one), so that nothing but
    /// "Io" and "Partecipante <numero>" is sent.
    static func originalLines(of call: Call) -> [RefinementLine]? {
        var lines: [RefinementLine] = []
        for (index, line) in call.sortedLines.enumerated() {
            guard let speaker = line.originalSpeaker else { return nil }
            lines.append(
                RefinementLine(
                    number: index + 1,
                    speaker: speaker,
                    start: line.start,
                    end: line.end,
                    text: line.originalText ?? line.text))
        }
        return lines
    }

    /// `lines` as a JSON array, one object per line (`number`, `speaker`, `start`, `end`, `text`).
    static func json(_ lines: [RefinementLine]) -> String {
        let rows = lines.map { line -> String in
            let fields: [(String, String)] = [
                ("number", String(line.number)),
                ("speaker", json(line.speaker.label)),
                ("start", json(line.start)),
                ("end", json(line.end)),
                ("text", json(line.text)),
            ]
            return "  {" + fields.map { "\"\($0.0)\": \($0.1)" }.joined(separator: ", ") + "}"
        }
        return "[\n" + rows.joined(separator: ",\n") + "\n]"
    }

    private static func json(_ string: String) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .withoutEscapingSlashes
        return String(decoding: (try? encoder.encode(string)) ?? Data("\"\"".utf8), as: UTF8.self)
    }

    /// Seconds with at most two decimals.
    private static func json(_ seconds: TimeInterval) -> String {
        let rounded = (seconds * 100).rounded() / 100
        return rounded == rounded.rounded() ? String(Int(rounded)) : String(rounded)
    }
}

/// One correction of the answer, already valid for its line.
struct RefinementCorrection: Equatable, Sendable {
    let number: Int
    let text: String
    let speaker: RefinementSpeaker
}

/// What is sent to the assistant to refine the transcript of a call, and the check
/// of what it answers (`requirements/rules#call`). Pure: no process, no model.
struct RefinementRequest: Equatable, Sendable {
    /// The lines of the call in order of start time, numbered from 1.
    let lines: [RefinementLine]

    init(lines: [RefinementLine]) {
        self.lines = lines
    }

    /// The original lines of `call`: a call refined before is sent with its original
    /// text and speakers, never with the refined ones. Nothing else of the call is read.
    /// `nil` when a line has no participant to send.
    init?(call: Call) {
        guard let lines = RefinementLine.originalLines(of: call) else { return nil }
        self.lines = lines
    }

    static let instructions = """
        Sei un correttore di trascrizioni automatiche di conversazioni. Ricevi le righe di una \
        trascrizione come array JSON; ogni riga ha number, speaker, start, end e text.

        Correggi ogni parola riconosciuta male, in qualsiasi lingua (per esempio le parole inglesi \
        dentro frasi italiane). Non riformulare, non riassumere, non tradurre e non cambiare lo stile. \
        Non unire, non dividere, non aggiungere e non togliere righe.

        Una riga può passare da un partecipante a un altro della stessa conversazione, correggendo \
        speaker con uno dei "Partecipante <numero>" già presenti nelle righe. Una riga "Io" resta "Io" \
        e nessun'altra riga diventa "Io".

        Rispondi solo con JSON, senza testo prima o dopo e senza blocchi di codice: un array con un \
        oggetto per ogni riga ricevuta, con i campi number (lo stesso della riga), text (il testo \
        corretto, mai vuoto) e speaker.
        """

    /// The instructions followed by the lines as JSON (`number`, `speaker`, `start`, `end`, `text`).
    var prompt: String {
        Self.instructions + "\n\n" + RefinementLine.json(lines)
    }

    // MARK: Answer

    private struct Item: Decodable {
        let number: Int
        let text: String
        let speaker: String
    }

    /// The corrections of `answer`, in the order of the lines, when it is valid:
    /// exactly one correction for every line sent, each with non-empty text and a
    /// speaker the line may have. `nil` otherwise: nothing is to be applied.
    ///
    /// A "Io" line may only stay "Io"; any other line may take any participant that
    /// appears in the lines sent, or keep its own participant.
    func corrections(from answer: String) -> [RefinementCorrection]? {
        guard let json = Self.jsonArray(in: answer),
            let items = try? JSONDecoder().decode([Item].self, from: Data(json.utf8)),
            items.count == lines.count
        else { return nil }

        let participants = lines.compactMap { line -> RefinementSpeaker? in
            if case .participant = line.speaker { return line.speaker }
            return nil
        }
        var byNumber: [Int: Item] = [:]
        for item in items {
            guard byNumber.updateValue(item, forKey: item.number) == nil else { return nil }
        }

        var corrections: [RefinementCorrection] = []
        for line in lines {
            guard let item = byNumber[line.number], let speaker = RefinementSpeaker(label: item.speaker) else {
                return nil
            }
            let allowed =
                line.speaker == .me
                ? speaker == .me
                : speaker == line.speaker || participants.contains(speaker)
            let text = item.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard allowed, !text.isEmpty else { return nil }
            corrections.append(RefinementCorrection(number: line.number, text: text, speaker: speaker))
        }
        return corrections
    }

    /// The JSON array in the answer: the assistant may wrap it in a code block or
    /// add a few words around it.
    private static func jsonArray(in answer: String) -> String? {
        guard let open = answer.firstIndex(of: "["), let close = answer.lastIndex(of: "]"), open < close else {
            return nil
        }
        return String(answer[open...close])
    }
}

extension TranscriptLine {
    /// The speaker as transcription and separation left it, for the assistant; `nil`
    /// for a line of the others that has no participant.
    fileprivate var originalSpeaker: RefinementSpeaker? {
        let kind = originalSpeakerKind ?? speakerKind
        switch kind {
        case .me: return .me
        case .others: return nil
        case .participant:
            guard let number = originalSpeakerKind == nil ? participant?.number : originalParticipantNumber
            else { return nil }
            return .participant(number)
        }
    }
}
