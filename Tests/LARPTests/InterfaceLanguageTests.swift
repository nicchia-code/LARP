import Foundation
import Testing

@testable import LARP

@Suite("Interface language")
@MainActor
struct InterfaceLanguageTests {
    private static var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private static func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    // MARK: Which language

    @Test("Italian when the first language of the Mac that LARP has is Italian, English otherwise")
    func resolvesTheLanguage() {
        #expect(AppLanguage.resolve(preferred: ["it-IT", "en-US"]) == .italian)
        #expect(AppLanguage.resolve(preferred: ["en-GB", "it"]) == .english)
        #expect(AppLanguage.resolve(preferred: ["de-DE", "it-IT"]) == .italian)
        #expect(AppLanguage.resolve(preferred: ["de-DE", "fr-FR"]) == .english)
        #expect(AppLanguage.resolve(preferred: []) == .english)
    }

    @Test("every text of the String Catalog exists in Italian and English")
    func catalogIsComplete() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/LARP/Resources/Localizable.xcstrings")
        let catalog = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        #expect(catalog?["sourceLanguage"] as? String == "it")
        let strings = try #require(catalog?["strings"] as? [String: [String: Any]])
        #expect(!strings.isEmpty)
        for (key, entry) in strings {
            let localizations = entry["localizations"] as? [String: [String: Any]] ?? [:]
            for language in ["it", "en"] {
                let unit = localizations[language]?["stringUnit"] as? [String: Any]
                let value = unit?["value"] as? String
                #expect(value?.isEmpty == false, "\"\(key)\" has no \(language) text")
            }
        }
    }

    @Test("the compiled catalog translates the texts into English")
    func translatesIntoEnglish() {
        #expect(L10n.string("Altri", language: .english) == "Others")
        #expect(L10n.string("Altri", language: .italian) == "Altri")
        #expect(L10n.string("Un testo che non esiste", language: .english) == "Un testo che non esiste")
    }

    // MARK: Default titles

    @Test("the default title has the Italian month in lower case or the English one")
    func defaultTitleMonths() {
        let italian = [
            "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
            "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre",
        ]
        let english = [
            "January", "February", "March", "April", "May", "June",
            "July", "August", "September", "October", "November", "December",
        ]
        for index in 0..<12 {
            let date = Self.date(2027, index + 1, 3, 9, 5)
            #expect(
                Call.defaultTitle(for: date, calendar: Self.utc, language: .italian)
                    == "Call del 3 \(italian[index]) 2027, 09:05")
            #expect(
                Call.defaultTitle(for: date, hasCallApp: false, calendar: Self.utc, language: .italian)
                    == "Registrazione del 3 \(italian[index]) 2027, 09:05")
            #expect(
                Call.defaultTitle(for: date, calendar: Self.utc, language: .english)
                    == "Call on 3 \(english[index]) 2027, 09:05")
            #expect(
                Call.defaultTitle(for: date, hasCallApp: false, calendar: Self.utc, language: .english)
                    == "Recording on 3 \(english[index]) 2027, 09:05")
        }
    }

    @Test("a title typed by the user is shown in both languages, the default one is built when shown")
    func titleShown() {
        let named = Call(title: "Weekly", startedAt: Self.date(2026, 10, 27, 10, 41), transcriptionLanguage: "it-IT")
        #expect(named.displayTitle(calendar: Self.utc, language: .english) == "Weekly")
        let unnamed = Call(startedAt: Self.date(2026, 10, 27, 10, 41), callAppName: "Zoom", transcriptionLanguage: "it-IT")
        #expect(unnamed.displayTitle(calendar: Self.utc, language: .italian) == "Call del 27 ottobre 2026, 10:41")
        #expect(unnamed.displayTitle(calendar: Self.utc, language: .english) == "Call on 27 October 2026, 10:41")
        #expect(unnamed.title == nil)
    }

    @Test("a title or a name typed by the user is stored without surrounding spaces; an empty one restores the default")
    func normalizedNames() {
        #expect(Call.normalizedName("  Weekly \n") == "Weekly")
        #expect(Call.normalizedName("   ") == nil)
        #expect(Call.normalizedName("") == nil)
    }

    // MARK: Speaker names

    @Test("speakers are named in the language of the interface")
    func speakerNames() {
        let me = TranscriptLine(speakerKind: .me, start: 0, end: 1, text: "a")
        let others = TranscriptLine(speakerKind: .others, start: 0, end: 1, text: "a")
        let orphan = TranscriptLine(speakerKind: .participant, start: 0, end: 1, text: "a")
        let participant = Participant(number: 3)
        let line = TranscriptLine(speakerKind: .participant, participant: participant, start: 0, end: 1, text: "a")
        #expect([me, others, orphan, line].map { $0.speakerName(language: .italian) } == ["Io", "Altri", "Altri", "Partecipante 3"])
        #expect([me, others, orphan, line].map { $0.speakerName(language: .english) } == ["Me", "Others", "Others", "Participant 3"])
        participant.name = "Marco"
        #expect(line.speakerName(language: .english) == "Marco")
        #expect(participant.initial == "M")
        #expect(Participant(number: 12).initial == "12")
    }

    @Test("what omp receives keeps the Italian names whatever the interface language")
    func ompNamesStayItalian() {
        #expect(RefinementSpeaker.me.label == "Io")
        #expect(RefinementSpeaker.participant(2).label == "Partecipante 2")
    }

    // MARK: Formats

    @Test("a day is written with the month name of the language")
    func dayAndTime() {
        let date = Self.date(2026, 10, 27, 10, 41)
        #expect(ArchiveFormat.dayAndTime(date, calendar: Self.utc, language: .italian) == "27 ottobre 2026, 10:41")
        #expect(ArchiveFormat.dayAndTime(date, calendar: Self.utc, language: .english) == "27 October 2026, 10:41")
        #expect(ArchiveFormat.language("it-IT", language: .italian) == "italiano (Italia)")
        #expect(ArchiveFormat.language("it-IT", language: .english) == "Italian (Italy)")
    }

    @Test("on a card: Oggi for today, the day name within the last week, otherwise the short date")
    func cardDayAndTime() {
        let now = Self.date(2026, 11, 11, 18, 0)
        func shown(_ date: Date, _ language: AppLanguage) -> String {
            ArchiveFormat.cardDayAndTime(date, now: now, calendar: Self.utc, language: language)
        }
        #expect(shown(Self.date(2026, 11, 11, 10, 0), .italian) == "Oggi 10:00")
        #expect(shown(Self.date(2026, 11, 11, 10, 0), .english) == "Today 10:00")
        #expect(shown(Self.date(2026, 11, 10, 16, 30), .italian) == "mar 16:30")
        #expect(shown(Self.date(2026, 11, 10, 16, 30), .english) == "Tue 16:30")
        #expect(shown(Self.date(2026, 11, 5, 14, 0), .italian) == "gio 14:00")
        #expect(shown(Self.date(2026, 10, 27, 10, 41), .italian) == "27 ott 10:41")
        #expect(shown(Self.date(2026, 10, 27, 10, 41), .english) == "27 Oct 10:41")
        // Seven days ago is no longer "within the last seven days": the weekday would be ambiguous.
        #expect(shown(Self.date(2026, 11, 4, 9, 5), .english) == "4 Nov 09:05")
    }

    @Test("the line above the title of the library counts the calls of today")
    func todayLine() {
        let now = Self.date(2026, 11, 11, 18, 0)
        #expect(ArchiveFormat.todayLine(now, callsToday: 2, calendar: Self.utc, language: .italian) == "mer 11 nov · 2 call oggi")
        #expect(ArchiveFormat.todayLine(now, callsToday: 2, calendar: Self.utc, language: .english) == "Wed 11 Nov · 2 calls today")
        #expect(ArchiveFormat.todayLine(now, callsToday: 1, calendar: Self.utc, language: .english) == "Wed 11 Nov · 1 call today")
        #expect(ArchiveFormat.todayLine(now, callsToday: 0, calendar: Self.utc, language: .italian) == "mer 11 nov · nessuna call oggi")
        #expect(ArchiveFormat.todayLine(now, callsToday: 0, calendar: Self.utc, language: .english) == "Wed 11 Nov · no calls today")
    }

    @Test("calls started today are counted in the calendar of the Mac")
    func callsToday() {
        let now = Self.date(2026, 11, 11, 18, 0)
        let dates = [Self.date(2026, 11, 11, 0, 5), Self.date(2026, 11, 11, 17, 59), Self.date(2026, 11, 10, 23, 59)]
        #expect(ArchiveFormat.callsStarted(on: now, in: dates, calendar: Self.utc) == 2)
    }

    @Test("durations on a card are minutes, or hours and minutes from one hour on")
    func cardDuration() {
        #expect(ArchiveFormat.cardDuration(0) == "0 min")
        #expect(ArchiveFormat.cardDuration(42 * 60 + 59) == "42 min")
        #expect(ArchiveFormat.cardDuration(3600) == "1 h 0 min")
        #expect(ArchiveFormat.cardDuration(4320) == "1 h 12 min")
    }

    // MARK: Permission alerts

    @Test("the alert of a missing permission is in the language of the interface")
    func permissionAlerts() {
        #expect(RecordingPermission.microphone.alertTitle(language: .italian) == "Permesso del microfono mancante")
        #expect(RecordingPermission.microphone.alertTitle(language: .english) == "Microphone permission missing")
        #expect(
            RecordingPermission.systemAudio.alertTitle(language: .english)
                == "System audio recording permission missing")
        #expect(
            RecordingPermission.systemAudio.alertMessage(language: .italian)
                == "LARP non può registrare senza il permesso «Registrazione audio di sistema». "
                + "Aprire Impostazioni di Sistema › Privacy e sicurezza › Registrazione audio di sistema e attivare LARP, poi riprovare.")
        #expect(
            RecordingPermission.microphone.alertMessage(language: .english)
                == "LARP can't record without the «Microphone» permission. "
                + "Open System Settings › Privacy & Security › Microphone, turn on LARP, then try again.")
    }

    @Test("the notices of the recorder are in the language of the interface")
    func noticeTexts() {
        AppLanguage.$override.withValue(.english) {
            #expect(MicrophoneLostPanelController.message == "The microphone is not available: the recording goes on without your voice.")
            #expect(SystemAudioUnavailablePanelController.message == "System audio is not available: only the microphone is recorded.")
        }
        AppLanguage.$override.withValue(.italian) {
            #expect(SystemAudioLostPanelController.message.hasPrefix("Audio di sistema non disponibile"))
        }
    }

    // MARK: Colours

    @Test("speakers have the same colours everywhere")
    func speakerColors() {
        #expect(SpeakerPalette.color(kind: .me, participantNumber: nil) == LARPColor.ink)
        #expect(SpeakerPalette.color(kind: .me, participantNumber: nil, onDark: true) == LARPColor.white)
        #expect(SpeakerPalette.color(kind: .others, participantNumber: nil) == LARPColor.textMuted)
        let numbers = (1...5).map { SpeakerPalette.color(kind: .participant, participantNumber: $0) }
        #expect(numbers == [LARPColor.lime, LARPColor.lilac, LARPColor.peach, LARPColor.sky, LARPColor.lime])
        #expect(SpeakerPalette.initialColor(kind: .me) == LARPColor.white)
        #expect(SpeakerPalette.initialColor(kind: .me, onDark: true) == LARPColor.ink)
        #expect(SpeakerPalette.initialColor(kind: .participant) == LARPColor.ink)
    }
}
