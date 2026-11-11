import Foundation
import Testing

@testable import LARP

@Suite("TranscriptExport", .italianInterface)
@MainActor
struct TranscriptExportTests {
    private func makeCall(title: String?) -> Call {
        let start = Calendar.current.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 10, minute: 41))!
        let call = Call(
            title: title,
            startedAt: start,
            duration: 754,
            transcriptionLanguage: "it-IT",
            state: .ready
        )
        let anna = Participant(number: 1, name: "Anna")
        call.participants.append(anna)
        // Inserted out of order on purpose: the export follows the start times.
        call.lines.append(
            TranscriptLine(speakerKind: .participant, participant: anna, start: 65, end: 70, text: "Buongiorno"))
        call.lines.append(TranscriptLine(speakerKind: .me, start: 3, end: 5, text: "Ciao a tutti"))
        return call
    }

    @Test("the export has an H1, the info line, the transcript heading and one paragraph per line")
    func markdownFormat() {
        let markdown = TranscriptExport.markdown(for: makeCall(title: "Weekly"))
        let expected = """
            # Weekly

            27 ottobre 2026, 10:41 · durata 12:34 · lingua italiano (Italia)

            ## Trascrizione

            **Io** [00:03]: Ciao a tutti

            **Anna** [01:05]: Buongiorno

            """
        #expect(markdown == expected)
    }

    @Test("a call without title is exported with its default title")
    func defaultTitle() {
        let call = makeCall(title: nil)
        #expect(TranscriptExport.markdown(for: call).hasPrefix("# \(call.displayTitle)\n"))
        #expect(TranscriptExport.defaultFileName(for: call) == call.displayTitle)
        #expect(call.displayTitle.hasPrefix("Registrazione del 27 ottobre 2026, 10:41"))
    }

    @Test("a call from a call app without title is exported as \"Call del …\"")
    func defaultTitleWithCallApp() {
        let call = makeCall(title: nil)
        call.callAppName = "Zoom"
        #expect(TranscriptExport.defaultFileName(for: call) == "Call del 27 ottobre 2026, 10:41")
    }

    @Test("the default file name is the title, without the path separator")
    func defaultFileName() {
        #expect(TranscriptExport.defaultFileName(for: makeCall(title: "Weekly")) == "Weekly")
        #expect(TranscriptExport.defaultFileName(for: makeCall(title: "Q1/Q2: piano")) == "Q1-Q2: piano")
    }

    @Test("times are written as mm:ss, going past 59 minutes")
    func clockFormat() {
        #expect(ArchiveFormat.clock(0) == "00:00")
        #expect(ArchiveFormat.clock(65.9) == "01:05")
        #expect(ArchiveFormat.clock(4503) == "75:03")
        #expect(ArchiveFormat.duration(754) == "12:34")
        #expect(ArchiveFormat.duration(3725) == "1:02:05")
    }

    @Test("a call with a summary has it between the info line and the lines, with current names")
    func markdownWithSummary() {
        let call = makeCall(title: "Weekly")
        call.participants.append(Participant(number: 2))
        call.summary = CallSummary(
            opening: "Si parte a marzo con Partecipante 1.",
            openingHighlight: "marzo",
            keyConcepts: ["Budget alto", "Scadenza vicina"],
            decisionItems: [SummaryDecision(text: "Partire", lineStart: 65.4), SummaryDecision(text: "Assumere")],
            actionItems: [
                SummaryActionItem(text: "Inviare il piano", owner: "Partecipante 1", due: "venerdì"),
                SummaryActionItem(text: "Prenotare la sala", owner: "Io", isDone: true),
                SummaryActionItem(text: "Chiamare il cliente"),
            ],
            openQuestions: ["Chi paga?"],
            text: "Partecipante 2 resta in dubbio.",
            language: "it-IT"
        )
        let expected = """
            # Weekly

            27 ottobre 2026, 10:41 · durata 12:34 · lingua italiano (Italia)

            ## Sintesi

            Si parte a **marzo** con Anna.

            ### Decisioni

            - [01:05] Partire
            - Assumere

            ### Azioni

            - [ ] Inviare il piano · Anna · venerdì
            - [x] Prenotare la sala · Io
            - [ ] Chiamare il cliente

            ### Rimasto aperto

            - Chi paga?

            ### Concetti chiave

            - Budget alto
            - Scadenza vicina

            ### Altro

            Partecipante 2 resta in dubbio.

            ## Trascrizione

            **Io** [00:03]: Ciao a tutti

            **Anna** [01:05]: Buongiorno

            """
        #expect(TranscriptExport.markdown(for: call) == expected)
    }

    @Test("the English interface exports English headings, names and titles")
    func markdownInEnglish() {
        let call = makeCall(title: nil)
        call.callAppName = "Zoom"
        call.summary = CallSummary(keyConcepts: ["Budget"], language: "it-IT")
        let expected = """
            # Call on 27 October 2026, 10:41

            27 October 2026, 10:41 · duration 12:34 · language Italian (Italy)

            ## Summary

            ### Decisions

            None

            ### Action items

            None

            ### Left open

            None

            ### Key concepts

            - Budget

            ## Transcript

            **Me** [00:03]: Ciao a tutti

            **Anna** [01:05]: Buongiorno

            """
        #expect(TranscriptExport.markdown(for: call, language: .english) == expected)
        #expect(TranscriptExport.defaultFileName(for: call, language: .english) == "Call on 27 October 2026, 10:41")
    }

    @Test("a call without summary, notes and bookmarks has only the transcript heading")
    func markdownWithoutSummary() {
        let markdown = TranscriptExport.markdown(for: makeCall(title: "Weekly"))
        #expect(markdown.components(separatedBy: "\n").filter { $0.hasPrefix("##") } == ["## Trascrizione"])
    }

    @Test("notes and bookmarks come after the summary and before the transcript, in order of time")
    func markdownWithNotesAndBookmarks() {
        let call = makeCall(title: "Weekly")
        call.notes.append(Note(text: "Senza ora", writtenAt: Date(timeIntervalSince1970: 20)))
        call.notes.append(Note(text: "Chiedere il budget", time: 65.9, writtenAt: Date(timeIntervalSince1970: 10)))
        call.bookmarks.append(Bookmark(time: 66))
        call.bookmarks.append(Bookmark(time: 400))
        call.bookmarks.append(Bookmark(time: 4))
        let expected = """
            # Weekly

            27 ottobre 2026, 10:41 · durata 12:34 · lingua italiano (Italia)

            ## Note

            - [01:05] Chiedere il budget
            - Senza ora

            ## Segnalibri

            - [00:04] Ciao a tutti
            - [01:06] Buongiorno
            - [06:40]

            ## Trascrizione

            **Io** [00:03]: Ciao a tutti

            **Anna** [01:05]: Buongiorno

            """
        #expect(TranscriptExport.markdown(for: call) == expected)

        call.summary = CallSummary(keyConcepts: ["Budget"], language: "it-IT")
        let headings = TranscriptExport.markdown(for: call).components(separatedBy: "\n").filter {
            $0.hasPrefix("## ")
        }
        #expect(headings == ["## Sintesi", "## Note", "## Segnalibri", "## Trascrizione"])
    }

    @Test("the copied summary is the summary without its heading, the opening first")
    func summaryTextWithoutHeading() {
        let call = makeCall(title: "Weekly")
        #expect(TranscriptExport.summaryText(for: call) == nil)
        call.summary = CallSummary(opening: "Si parte.", openingHighlight: "Si parte", keyConcepts: ["Budget"], language: "it-IT")
        let text = TranscriptExport.summaryText(for: call)
        #expect(text?.hasPrefix("**Si parte**.\n\n### Decisioni\n\nNessuno") == true)
        #expect(text?.contains("## Sintesi") == false)
    }
}
