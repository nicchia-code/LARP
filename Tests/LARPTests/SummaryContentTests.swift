import Testing

@testable import LARP

@Suite("SummaryContent", .italianInterface)
@MainActor
struct SummaryContentTests {
    private func makeCall(summary: CallSummary?) -> Call {
        let call = Call(transcriptionLanguage: "it-IT", state: .ready)
        call.participants.append(Participant(number: 1, name: "Anna"))
        call.participants.append(Participant(number: 2))
        call.participants.append(Participant(number: 12, name: "Zoë"))
        call.summary = summary
        return call
    }

    @Test("a call without a summary has no content")
    func noSummary() {
        #expect(SummaryContent(call: makeCall(summary: nil)) == nil)
    }

    @Test("sections come in a fixed order with Italian titles and Nessuno for an empty list")
    func italianSections() throws {
        let call = makeCall(summary: CallSummary(keyConcepts: ["Uno"], text: "Libero", language: "it-IT"))
        let content = try #require(SummaryContent(call: call))
        #expect(content.opening == nil)
        #expect(
            content.sections == [
                .init(kind: .decisions, title: "Decisioni", body: .none("Nessuno")),
                .init(kind: .actionItems, title: "Azioni", body: .none("Nessuno")),
                .init(kind: .leftOpen, title: "Rimasto aperto", body: .none("Nessuno")),
                .init(kind: .keyConcepts, title: "Concetti chiave", body: .items(["Uno"])),
                .init(kind: .other, title: "Altro", body: .text("Libero")),
            ])
    }

    @Test("the English interface has English titles and None; Other is left out when the text is empty")
    func englishSections() throws {
        let call = makeCall(
            summary: CallSummary(openQuestions: ["Who pays?"], text: "  \n", language: "en-GB"))
        let content = try #require(SummaryContent(call: call, language: .english))
        #expect(
            content.sections == [
                .init(kind: .decisions, title: "Decisions", body: .none("None")),
                .init(kind: .actionItems, title: "Action items", body: .none("None")),
                .init(kind: .leftOpen, title: "Left open", body: .items(["Who pays?"])),
                .init(kind: .keyConcepts, title: "Key concepts", body: .none("None")),
            ])
    }

    @Test("the opening sentence is split around its key part, with the names of the participants")
    func opening() throws {
        let call = makeCall(
            summary: CallSummary(
                opening: "Partecipante 1 conferma che si parte a marzo.", openingHighlight: "si parte a marzo",
                language: "it-IT"))
        let opening = try #require(SummaryContent(call: call)?.opening)
        #expect(opening == .init(before: "Anna conferma che ", key: "si parte a marzo", after: "."))
        #expect(opening.plain == "Anna conferma che si parte a marzo.")
        #expect(opening.markdown == "Anna conferma che **si parte a marzo**.")
    }

    @Test("a key part that is empty or not in the sentence highlights nothing; an empty opening is none")
    func openingWithoutKeyPart() throws {
        let missing = makeCall(summary: CallSummary(opening: "Si parte.", openingHighlight: "altro", language: "it-IT"))
        #expect(try #require(SummaryContent(call: missing)?.opening) == .init(before: "Si parte.", key: "", after: ""))
        let empty = makeCall(summary: CallSummary(opening: "Si parte.", openingHighlight: "", language: "it-IT"))
        #expect(try #require(SummaryContent(call: empty)?.opening).markdown == "Si parte.")
        let none = makeCall(summary: CallSummary(opening: " \n", openingHighlight: "x", language: "it-IT"))
        #expect(SummaryContent(call: none)?.opening == nil)
    }

    @Test("decisions keep the start of their line; actions keep their place, owner, due and tick")
    func decisionsAndActions() throws {
        let call = makeCall(
            summary: CallSummary(
                decisionItems: [SummaryDecision(text: "Si parte", lineStart: 12.9), SummaryDecision(text: "Assumere")],
                actionItems: [
                    SummaryActionItem(text: "Inviare il piano", owner: "Partecipante 1", due: "venerdì"),
                    SummaryActionItem(text: "Prenotare", owner: "Partecipante 2", isDone: true),
                    SummaryActionItem(text: "Fare", owner: "Io"),
                    SummaryActionItem(text: "Chiamare"),
                ],
                language: "it-IT"))
        let content = try #require(SummaryContent(call: call))
        #expect(
            content.sections[0].body
                == .decisions([.init(text: "Si parte", lineStart: 12.9), .init(text: "Assumere", lineStart: nil)]))
        let actions = content.actions
        #expect(actions.map(\.index) == [0, 1, 2, 3])
        #expect(actions.map(\.text) == ["Inviare il piano", "Prenotare", "Fare", "Chiamare"])
        #expect(actions.map(\.owner) == ["Anna", "Partecipante 2", "Io", nil])
        #expect(actions.map(\.ownerInitial) == ["A", "2", "I", nil])
        #expect(actions.map(\.ownerKind) == [.participant, .participant, .me, .others])
        #expect(actions.map(\.ownerParticipant) == [1, 2, nil, nil])
        #expect(actions.map(\.due) == ["venerdì", nil, nil, nil])
        #expect(actions.map(\.isDone) == [false, true, false, false])
        #expect(content.openActionCount == 3)
        #expect(actions[0].line == "Inviare il piano · Anna · venerdì")
        #expect(actions[3].line == "Chiamare")
    }

    @Test("a summary written before this structure shows its next steps as actions without due and nothing left open")
    func previousSummary() throws {
        let call = makeCall(summary: CallSummary(actionItems: [SummaryActionItem(text: "Inviare", owner: "Io")], language: "it-IT"))
        let content = try #require(SummaryContent(call: call))
        #expect(content.opening == nil)
        #expect(content.actions.map(\.due) == [nil])
        #expect(content.sections.first { $0.kind == .leftOpen }?.body == .none("Nessuno"))
    }

    @Test("Partecipante N becomes the current name of that participant, only when there is one")
    func participantNames() throws {
        let call = makeCall(
            summary: CallSummary(
                keyConcepts: ["Partecipante 1 e Partecipante 2, non Partecipante 3 né Partecipante 123"],
                actionItems: [SummaryActionItem(text: "Scrivere", owner: "Partecipante 12"), SummaryActionItem(text: "Fare", owner: "Io")],
                openQuestions: ["Partecipante 1 decide?"],
                language: "it-IT"
            ))
        let content = try #require(SummaryContent(call: call))
        #expect(content.sections[3].body == .items(["Anna e Partecipante 2, non Partecipante 3 né Partecipante 123"]))
        #expect(content.sections[2].body == .items(["Anna decide?"]))
        #expect(content.actions.map(\.owner) == ["Zoë", "Io"])
        // The stored summary keeps what the assistant wrote.
        #expect(call.summary?.actionItems.first?.owner == "Partecipante 12")
    }

    @Test("in the English interface an unnamed Partecipante N becomes Participant N")
    func englishParticipants() throws {
        let call = makeCall(summary: CallSummary(decisionItems: [SummaryDecision(text: "Partecipante 1 e Partecipante 2, non Partecipante 123")], language: "it-IT"))
        let content = try #require(SummaryContent(call: call, language: .english))
        #expect(content.sections[0].body == .decisions([.init(text: "Anna e Participant 2, non Participant 123", lineStart: nil)]))
        // The stored summary is never changed.
        #expect(call.summary?.decisionItems.map(\.text) == ["Partecipante 1 e Partecipante 2, non Partecipante 123"])
    }

    @Test("a participant renamed later appears with the new name")
    func renamedLater() throws {
        let call = makeCall(summary: CallSummary(decisionItems: [SummaryDecision(text: "Partecipante 2 decide")], language: "it-IT"))
        #expect(try #require(SummaryContent(call: call)).sections[0].body == .decisions([.init(text: "Partecipante 2 decide", lineStart: nil)]))
        call.participants.first { $0.number == 2 }?.name = "Marco"
        #expect(try #require(SummaryContent(call: call)).sections[0].body == .decisions([.init(text: "Marco decide", lineStart: nil)]))
    }

    @Test("the search texts are the opening, titles, items, owners, dues and free text, not Nessuno")
    func searchableTexts() throws {
        let call = makeCall(
            summary: CallSummary(
                opening: "Si parte.", openingHighlight: "Si parte", keyConcepts: ["Budget"],
                decisionItems: [SummaryDecision(text: "Assumere", lineStart: 5)],
                actionItems: [SummaryActionItem(text: "Inviare", owner: "Partecipante 1", due: "venerdì")],
                text: "Resto", language: "it-IT"))
        let texts = try #require(SummaryContent(call: call)).searchableTexts
        #expect(
            texts == [
                "Si parte.", "Decisioni", "Assumere", "Azioni", "Inviare", "Anna", "venerdì", "Rimasto aperto",
                "Concetti chiave", "Budget", "Altro", "Resto",
            ])
        #expect(!texts.contains("Nessuno"))
    }

    @Test("the Markdown has the opening with its key part in bold, then the sections")
    func markdown() throws {
        let call = makeCall(
            summary: CallSummary(
                opening: "Si parte a marzo.", openingHighlight: "marzo", keyConcepts: ["Budget", "Scadenze"],
                decisionItems: [SummaryDecision(text: "Parte", lineStart: 65.2), SummaryDecision(text: "Assumere")],
                actionItems: [
                    SummaryActionItem(text: "Inviare", owner: "Partecipante 1", due: "venerdì"),
                    SummaryActionItem(text: "Prenotare", owner: "Io", isDone: true),
                    SummaryActionItem(text: "Chiamare"),
                ],
                openQuestions: ["Chi paga?"], text: "Resto", language: "it-IT"))
        let content = try #require(SummaryContent(call: call))
        #expect(
            content.markdownParagraphs == [
                "## Sintesi", "Si parte a **marzo**.",
                "### Decisioni", "- [01:05] Parte\n- Assumere",
                "### Azioni", "- [ ] Inviare · Anna · venerdì\n- [x] Prenotare · Io\n- [ ] Chiamare",
                "### Rimasto aperto", "- Chi paga?",
                "### Concetti chiave", "- Budget\n- Scadenze",
                "### Altro", "Resto",
            ])
    }

    @Test("an empty list is written with the word that stands for it, in the interface language")
    func markdownEmptyLists() throws {
        let call = makeCall(summary: CallSummary(language: "it-IT"))
        let english = try #require(SummaryContent(call: call, language: .english))
        #expect(
            english.markdownParagraphs == [
                "## Summary", "### Decisions", "None", "### Action items", "None", "### Left open", "None",
                "### Key concepts", "None",
            ])
    }

    @Test("a Ready call shows how its summary is going; other states keep their label")
    func summaryStatusLabels() {
        #expect(SummaryState.writing.statusLabel == "Sintesi…")
        #expect(SummaryState.awaitingRetry.statusLabel == "Sintesi da fare")
        #expect(SummaryState.written.statusLabel == nil)
        #expect(SummaryState.none.statusLabel == nil)
        #expect(CallState.ready.statusLabel == nil)
        #expect(CallState.refiningTranscript.statusLabel == "Rifinitura testo…")
        #expect(SummaryState.writing.statusLabel(language: .english) == "Summarising…")
        #expect(CallState.refiningTranscript.statusLabel(language: .english) == "Refining text…")
    }
}
