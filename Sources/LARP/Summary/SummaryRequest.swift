import Foundation

/// A summary as the assistant answered it, already valid: ready to be stored.
struct SummaryAnswer: Equatable, Sendable {
    let keyConcepts: [String]
    let decisions: [String]
    let nextSteps: [SummaryNextStep]
    let text: String
}

/// What is sent to the assistant to write the summary of a call, and the check of what
/// it answers (`requirements/rules#call-summary`). Pure: no process, no model.
struct SummaryRequest: Equatable, Sendable {
    /// The original lines of the call in order of start time, numbered from 1.
    let lines: [RefinementLine]
    /// Transcription language of the call, as a locale identifier (e.g. `it-IT`): the
    /// language the summary is written in.
    let language: String

    init(lines: [RefinementLine], language: String) {
        self.lines = lines
        self.language = language
    }

    /// The original lines of `call`, as transcription and separation left them (a call
    /// refined before is sent with its original text and speakers) and its transcription
    /// language. Nothing else of the call is read: never the title, the names, the
    /// dates or the call app. `nil` when a line has no participant to send.
    init?(call: Call) {
        guard let lines = RefinementLine.originalLines(of: call) else { return nil }
        self.init(lines: lines, language: call.transcriptionLanguage)
    }

    /// The fixed instructions, saying in which language the summary is written.
    static func instructions(language: String) -> String {
        let name = isEnglish(language) ? "inglese" : "italiano"
        return """
            Sei un assistente che scrive la sintesi di una conversazione registrata. Ricevi le righe \
            della trascrizione come array JSON; ogni riga ha number, speaker, start, end e text.

            Le righe vengono da un riconoscimento vocale automatico e da una separazione automatica \
            delle voci: alcune parole possono essere riconosciute male e alcune righe possono essere \
            attribuite al partecipante sbagliato. Dai loro un senso, senza segnalare questi errori.

            Scrivi la sintesi in \(name). Chiama i partecipanti solo "Io" e "Partecipante <numero>", \
            come nel campo speaker, senza indovinare nomi dalla conversazione.

            La sintesi contiene i concetti chiave discussi, le decisioni prese, i prossimi passi e, \
            come testo libero, ciò che è stato detto di importante e non rientra in nessuno dei tre. \
            Ogni elenco può essere vuoto e il testo libero può essere vuoto. Di un prossimo passo \
            indica chi deve farlo, come "Io" o "Partecipante <numero>", solo quando la conversazione \
            lo rende chiaro; altrimenti non indicare nessuno.

            Rispondi solo con un oggetto JSON, senza testo prima o dopo e senza blocchi di codice, con \
            i campi keyConcepts (lista di stringhe), decisions (lista di stringhe), nextSteps (lista \
            di oggetti con text e, facoltativo, owner) e other (stringa, anche vuota).
            """
    }

    /// The instructions followed by the lines as JSON (`number`, `speaker`, `start`, `end`, `text`).
    var prompt: String {
        Self.instructions(language: language) + "\n\n" + RefinementLine.json(lines)
    }

    private static func isEnglish(_ language: String) -> Bool {
        Locale(identifier: language).language.languageCode?.identifier == "en"
    }

    // MARK: Answer

    private struct Step: Decodable {
        let text: String
        let owner: String?
    }

    private struct Item: Decodable {
        let keyConcepts: [String]
        let decisions: [String]
        let nextSteps: [Step]
        let other: String
    }

    /// The summary in `answer`, when it is complete: the four fields, the owner of every next
    /// step being "Io" or "Partecipante <numero>" of one of `participants` (the numbers of the
    /// participants of the call). `nil` otherwise: nothing is to be saved.
    static func summary(from answer: String, participants: Set<Int>) -> SummaryAnswer? {
        guard let json = jsonObject(in: answer),
            let item = try? JSONDecoder().decode(Item.self, from: Data(json.utf8))
        else { return nil }

        var steps: [SummaryNextStep] = []
        for step in item.nextSteps {
            var owner: String?
            if let label = step.owner {
                switch RefinementSpeaker(label: label) {
                case .me?: break
                case .participant(let number)? where participants.contains(number): break
                default: return nil
                }
                owner = label
            }
            let text = step.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty { steps.append(SummaryNextStep(text: text, owner: owner)) }
        }
        return SummaryAnswer(
            keyConcepts: trimmed(item.keyConcepts),
            decisions: trimmed(item.decisions),
            nextSteps: steps,
            text: item.other.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func trimmed(_ items: [String]) -> [String] {
        items.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    }

    /// The JSON object in the answer: the assistant may wrap it in a code block or add a
    /// few words around it.
    private static func jsonObject(in answer: String) -> String? {
        guard let open = answer.firstIndex(of: "{"), let close = answer.lastIndex(of: "}"), open < close else {
            return nil
        }
        return String(answer[open...close])
    }
}
