import Foundation

/// Names shown for calls, participants and speakers, in the language of the interface; what is
/// stored never changes with the language.
extension Call {
    /// The title the user gave, else the title of the meeting (from Teams or the calendar), else the
    /// default one built from the start of the call: "Call del <giorno> <mese> <anno>, <hh:mm>" for
    /// a call tied to a call app, for example "Call del 27 ottobre 2026, 10:41", and "Registrazione
    /// del <giorno> <mese> <anno>, <hh:mm>" for a recording without a call app
    /// (`callAppName == nil`); in English "Call on …" and "Recording on …". The title of the meeting
    /// is only shown here: it never goes to omp.
    var displayTitle: String {
        displayTitle(calendar: .current)
    }

    func displayTitle(calendar: Calendar, language: AppLanguage = .current) -> String {
        if let title, !title.isEmpty {
            return title
        }
        if let meetingTitle, !meetingTitle.isEmpty {
            return meetingTitle
        }
        return Self.defaultTitle(
            for: startedAt, hasCallApp: callAppName != nil, calendar: calendar, language: language)
    }

    /// "Call del <giorno> <mese> <anno>, <hh:mm>" with the Italian month name in lower case, or
    /// "Registrazione del …" when the recording has no call app; "Call on …" and "Recording on …"
    /// with the English month name in English. The day is not padded, hours (24-hour) and minutes
    /// are two digits, in the calendar given.
    static func defaultTitle(
        for date: Date, hasCallApp: Bool = true, calendar: Calendar = .current, language: AppLanguage = .current
    ) -> String {
        var calendar = calendar
        calendar.locale = language.locale
        let parts = calendar.dateComponents([.day, .month, .year, .hour, .minute], from: date)
        let month = calendar.monthSymbols[(parts.month ?? 1) - 1]
        return L10n.format(
            hasCallApp ? "Call del %lld %@ %lld, %02lld:%02lld" : "Registrazione del %lld %@ %lld, %02lld:%02lld",
            parts.day ?? 1, month, parts.year ?? 1970, parts.hour ?? 0, parts.minute ?? 0,
            language: language
        )
    }

    /// Normalizes a title typed by the user: surrounding whitespace is dropped and
    /// an empty title becomes `nil`, which restores the default one.
    static func normalizedName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Participant {
    /// The name the user gave, or "Partecipante <numero>" ("Participant <number>").
    var displayName: String {
        displayName(language: .current)
    }

    func displayName(language: AppLanguage) -> String {
        if let name, !name.isEmpty {
            return name
        }
        return L10n.format("Partecipante %lld", number, language: language)
    }

    /// The first letter of the name as shown; for "Partecipante <number>" the number.
    var initial: String {
        if let name, let first = name.first {
            return String(first).uppercased()
        }
        return String(number)
    }
}

extension SpeakerKind {
    /// "Io" / "Me" for the user and "Altri" / "Others" for the other parties as a whole. A
    /// participant is named by `Participant.displayName`.
    var displayName: String {
        displayName(language: .current)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .me: L10n.string("Io", language: language)
        case .others: L10n.string("Altri", language: language)
        case .participant: L10n.string("Partecipante", language: language)
        }
    }
}

extension TranscriptLine {
    /// Who spoke the line: "Io", "Altri", or the name of the participant
    /// ("Partecipante <numero>" until the user gives one); a participant line without
    /// participant shows "Altri". In the language of the interface.
    var speakerName: String {
        speakerName(language: .current)
    }

    func speakerName(language: AppLanguage) -> String {
        switch speakerKind {
        case .me: SpeakerKind.me.displayName(language: language)
        case .others: SpeakerKind.others.displayName(language: language)
        case .participant:
            participant?.displayName(language: language) ?? SpeakerKind.others.displayName(language: language)
        }
    }

    /// The initial shown in the avatar of whoever spoke the line.
    var speakerInitial: String {
        switch speakerKind {
        case .me: String(SpeakerKind.me.displayName.prefix(1))
        case .others: String(SpeakerKind.others.displayName.prefix(1))
        case .participant: participant?.initial ?? String(SpeakerKind.others.displayName.prefix(1))
        }
    }
}
