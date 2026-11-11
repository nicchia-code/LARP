import Foundation

/// A summary as the assistant answered it, already valid: ready to be stored.
struct SummaryAnswer: Equatable, Sendable {
    let opening: String
    /// The key part of `opening`; empty when none is to be highlighted.
    let openingHighlight: String
    let keyConcepts: [String]
    let decisions: [SummaryDecision]
    let actionItems: [SummaryActionItem]
    let openQuestions: [String]
    let text: String
}

/// What is sent to the assistant to write the summary of a call, and the check of what
/// it answers (`requirements/rules#call-summary`). Pure: no process, no model.
struct SummaryRequest: Equatable, Sendable {
    /// The original lines of the call in order of start time, numbered from 1.
    let lines: [RefinementLine]
    /// The language the summary is asked in, as a locale identifier (`it-IT` or `en-US`).
    let language: String

    init(lines: [RefinementLine], language: String) {
        self.lines = lines
        self.language = language
    }

    /// The original lines of `call`, as transcription and separation left them (a call
    /// refined before is sent with its original text and speakers) and the language `choice`
    /// asks for given the transcription language of the call. Nothing else of the call is read:
    /// never the title, the names, the dates or the call app. `nil` when a line has no
    /// participant to send.
    init?(call: Call, languageChoice choice: SummaryLanguageChoice) {
        guard let lines = RefinementLine.originalLines(of: call) else { return nil }
        self.init(lines: lines, language: choice.language(forCallLanguage: call.transcriptionLanguage))
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

            La sintesi contiene, in quest'ordine: una frase d'apertura di al più 40 parole che dica \
            l'esito della call, con la sua parte chiave (poche parole consecutive, copiate così come \
            sono dalla frase) data anche a parte; i concetti chiave discussi; le decisioni prese, \
            ciascuna con il number della riga in cui è stata presa; le azioni, ciascuna con chi deve \
            farla, come "Io" o "Partecipante <numero>", solo quando la conversazione lo rende chiaro, \
            e con la scadenza solo quando è detta, scritta come è stata detta (per esempio "venerdì"), \
            mai come data calcolata; ciò che è rimasto aperto; infine, come testo libero, ciò che è \
            stato detto di importante e non rientra in nessuno dei punti precedenti. Ogni elenco e il \
            testo libero possono essere vuoti. Se il responsabile o la scadenza di un'azione non sono \
            chiari, non indicarli.

            Rispondi solo con un oggetto JSON, senza testo prima o dopo e senza blocchi di codice, con \
            i campi opening (stringa), openingHighlight (stringa), keyConcepts (lista di stringhe), \
            decisions (lista di oggetti con text e line, il number della riga), actionItems (lista di \
            oggetti con text e, facoltativi, owner e due), openQuestions (lista di stringhe) e other \
            (stringa, anche vuota).
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

    private struct Decision: Decodable {
        let text: String
        /// The number of the line, or `nil` when absent or not a number: the decision is kept
        /// without line either way.
        let line: Int?

        enum CodingKeys: String, CodingKey { case text, line }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            text = try container.decode(String.self, forKey: .text)
            line = try? container.decodeIfPresent(Int.self, forKey: .line)
        }
    }

    private struct Action: Decodable {
        let text: String
        let owner: String?
        let due: String?
    }

    private struct Item: Decodable {
        let opening: String
        let openingHighlight: String
        let keyConcepts: [String]
        let decisions: [Decision]
        let actionItems: [Action]
        let openQuestions: [String]
        let other: String
    }

    /// The summary in `answer`, when it is complete: the seven fields, the owner of every action
    /// being "Io" or "Partecipante <numero>" of one of `participants` (the numbers of the
    /// participants of the call). `lines` are the lines that were sent: a decision keeps the
    /// start of the line it names. `nil` otherwise: nothing is to be saved.
    static func summary(from answer: String, participants: Set<Int>, lines: [RefinementLine]) -> SummaryAnswer? {
        guard let json = jsonObject(in: answer),
            let item = try? JSONDecoder().decode(Item.self, from: Data(json.utf8))
        else { return nil }

        var actions: [SummaryActionItem] = []
        for action in item.actionItems {
            var owner: String?
            if let label = action.owner {
                switch RefinementSpeaker(label: label) {
                case .me?: break
                case .participant(let number)? where participants.contains(number): break
                default: return nil
                }
                owner = label
            }
            let text = trim(action.text)
            guard !text.isEmpty else { continue }
            let due = action.due.map(trim).flatMap { $0.isEmpty ? nil : $0 }
            actions.append(SummaryActionItem(text: text, owner: owner, due: due))
        }

        let starts = Dictionary(lines.map { ($0.number, $0.start) }, uniquingKeysWith: { first, _ in first })
        let decisions = item.decisions.compactMap { decision -> SummaryDecision? in
            let text = trim(decision.text)
            guard !text.isEmpty else { return nil }
            return SummaryDecision(text: text, lineStart: decision.line.flatMap { starts[$0] })
        }

        let opening = trim(item.opening)
        let highlight = trim(item.openingHighlight)
        let keptHighlight = !highlight.isEmpty && opening.range(of: highlight, options: .caseInsensitive) != nil
        return SummaryAnswer(
            opening: opening,
            openingHighlight: keptHighlight ? highlight : "",
            keyConcepts: trimmed(item.keyConcepts),
            decisions: decisions,
            actionItems: actions,
            openQuestions: trimmed(item.openQuestions),
            text: trim(item.other))
    }

    private static func trim(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func trimmed(_ items: [String]) -> [String] {
        items.map(trim).filter { !$0.isEmpty }
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
