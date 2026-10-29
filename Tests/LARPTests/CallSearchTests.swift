import Testing

@testable import LARP

@Suite("CallSearch")
@MainActor
struct CallSearchTests {
    private func makeCall(title: String?, lines: [String] = [], participants: [String] = []) -> Call {
        let call = Call(title: title, transcriptionLanguage: "it-IT", state: .ready)
        for (index, name) in participants.enumerated() {
            call.participants.append(Participant(number: index + 1, name: name))
        }
        for (index, text) in lines.enumerated() {
            call.lines.append(
                TranscriptLine(speakerKind: .others, start: Double(index), end: Double(index + 1), text: text))
        }
        return call
    }

    @Test("an empty search shows every call")
    func emptyQueryMatchesAll() {
        let calls = [makeCall(title: "Uno"), makeCall(title: nil)]
        #expect(CallSearch.filter(calls, query: "").count == 2)
        #expect(CallSearch.filter(calls, query: "   ").count == 2)
    }

    @Test("it matches the title ignoring case and accents")
    func matchesTitle() {
        let call = makeCall(title: "Riunione città")
        #expect(CallSearch.matches(call, query: "CITTA"))
        #expect(CallSearch.matches(call, query: "riunione"))
        #expect(CallSearch.matches(call, query: "città"))
        #expect(!CallSearch.matches(call, query: "paese"))
    }

    @Test("it finds a call without title and call app by the word Registrazione, one with a call app by Call")
    func matchesDefaultTitle() {
        let recording = makeCall(title: nil)
        let appCall = makeCall(title: nil)
        appCall.callAppName = "Zoom"
        #expect(CallSearch.matches(recording, query: "registrazione"))
        #expect(!CallSearch.matches(recording, query: "call del"))
        #expect(CallSearch.matches(appCall, query: "Call del"))
        #expect(!CallSearch.matches(appCall, query: "Registrazione"))
    }

    @Test("it matches the transcript text ignoring case and accents")
    func matchesTranscriptText() {
        let call = makeCall(title: "Weekly", lines: ["Ciao a tutti", "Perché no?"])
        #expect(CallSearch.matches(call, query: "perche"))
        #expect(CallSearch.matches(call, query: "TUTTI"))
        #expect(!CallSearch.matches(call, query: "arrivederci"))
    }

    @Test("it matches the participant names ignoring case and accents")
    func matchesParticipantNames() {
        let call = makeCall(title: "Weekly", participants: ["Zoë", "Anna"])
        #expect(CallSearch.matches(call, query: "zoe"))
        #expect(CallSearch.matches(call, query: "ANNA"))
        #expect(!CallSearch.matches(call, query: "marco"))
    }

    @Test("filter keeps only the matching calls, in order")
    func filterKeepsOrder() {
        let first = makeCall(title: "Budget", lines: ["numeri"])
        let second = makeCall(title: "Altro")
        let third = makeCall(title: "Budget 2")
        let result = CallSearch.filter([first, second, third], query: "budget")
        #expect(result.map(\.id) == [first.id, third.id])
    }

    private func makeSummarisedCall() -> Call {
        let call = makeCall(title: "Weekly", participants: ["Zoë"])
        call.summary = CallSummary(
            keyConcepts: ["Il budget è alto"],
            decisions: [],
            nextSteps: [SummaryNextStep(text: "Inviare il piano", owner: "Partecipante 1")],
            text: "Parlato anche di Partecipante 1 e Partecipante 2.",
            language: "it-IT"
        )
        call.summaryState = .written
        return call
    }

    @Test("it matches the text of the summary and its section titles, ignoring case and accents")
    func matchesSummary() {
        let call = makeSummarisedCall()
        #expect(CallSearch.matches(call, query: "BUDGET E ALTO"))
        #expect(CallSearch.matches(call, query: "concetti chiave"))
        #expect(CallSearch.matches(call, query: "prossimi passi"))
        #expect(CallSearch.matches(call, query: "inviare il piano"))
        #expect(!CallSearch.matches(call, query: "ferie"))
    }

    @Test("the summary is searched with the current names of the participants")
    func matchesSummaryWithNames() {
        let call = makeSummarisedCall()
        #expect(CallSearch.matches(call, query: "piano (zoe)"))
        #expect(CallSearch.matches(call, query: "di zoe e partecipante 2"))
        #expect(!CallSearch.matches(call, query: "piano (partecipante 1)"))
    }

    @Test("the word for an empty list is not searched")
    func emptyListWordIsNotSearched() {
        let call = makeSummarisedCall()
        #expect(!CallSearch.matches(call, query: "nessuno"))
    }

    @Test("a summary stays searchable whatever its state")
    func summaryStateDoesNotMatter() {
        let call = makeSummarisedCall()
        call.summaryState = .awaitingRetry
        #expect(CallSearch.matches(call, query: "budget"))
        call.summaryState = .writing
        #expect(CallSearch.matches(call, query: "budget"))
    }
}
