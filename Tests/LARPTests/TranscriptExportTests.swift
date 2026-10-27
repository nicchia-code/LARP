import Foundation
import Testing

@testable import LARP

@Suite("TranscriptExport")
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

    @Test("the export has an H1, the info line and one paragraph per line")
    func markdownFormat() {
        let markdown = TranscriptExport.markdown(for: makeCall(title: "Weekly"))
        let expected = """
            # Weekly

            27 ottobre 2026, 10:41 · durata 12:34 · lingua italiano (Italia)

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
}
