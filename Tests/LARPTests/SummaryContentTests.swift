import Testing

@testable import LARP

@Suite("SummaryContent")
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
        #expect(
            content.sections == [
                .init(title: "Concetti chiave", body: .items(["Uno"])),
                .init(title: "Decisioni", body: .none("Nessuno")),
                .init(title: "Prossimi passi", body: .none("Nessuno")),
                .init(title: "Altro", body: .text("Libero")),
            ])
    }

    @Test("English summaries have English titles and None; Other is left out when the text is empty")
    func englishSections() throws {
        let call = makeCall(summary: CallSummary(decisions: ["Go"], text: "  \n", language: "en-GB"))
        let content = try #require(SummaryContent(call: call))
        #expect(
            content.sections == [
                .init(title: "Key concepts", body: .none("None")),
                .init(title: "Decisions", body: .items(["Go"])),
                .init(title: "Next steps", body: .none("None")),
            ])
    }

    @Test("Partecipante N becomes the current name of that participant, only when there is one")
    func participantNames() throws {
        let call = makeCall(
            summary: CallSummary(
                keyConcepts: ["Partecipante 1 e Partecipante 2, non Partecipante 3 né Partecipante 123"],
                nextSteps: [SummaryNextStep(text: "Scrivere", owner: "Partecipante 12"), SummaryNextStep(text: "Fare", owner: "Io")],
                language: "it-IT"
            ))
        let content = try #require(SummaryContent(call: call))
        #expect(content.sections[0].body == .items(["Anna e Partecipante 2, non Partecipante 3 né Partecipante 123"]))
        #expect(content.sections[2].body == .items(["Scrivere (Zoë)", "Fare (Io)"]))
        // The stored summary keeps what the assistant wrote.
        #expect(call.summary?.nextSteps.first?.owner == "Partecipante 12")
    }

    @Test("a participant renamed later appears with the new name")
    func renamedLater() throws {
        let call = makeCall(summary: CallSummary(decisions: ["Partecipante 2 decide"], language: "it-IT"))
        #expect(try #require(SummaryContent(call: call)).sections[1].body == .items(["Partecipante 2 decide"]))
        call.participants.first { $0.number == 2 }?.name = "Marco"
        #expect(try #require(SummaryContent(call: call)).sections[1].body == .items(["Marco decide"]))
    }

    @Test("a Ready call shows how its summary is going; other states keep their label")
    func summaryStatusLabels() {
        #expect(SummaryState.writing.statusLabel == "Sintesi…")
        #expect(SummaryState.awaitingRetry.statusLabel == "Sintesi da fare")
        #expect(SummaryState.written.statusLabel == nil)
        #expect(SummaryState.none.statusLabel == nil)
        #expect(CallState.ready.statusLabel == nil)
        #expect(CallState.refiningTranscript.statusLabel == "Rifinitura testo…")
    }
}
