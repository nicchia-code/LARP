import Foundation

/// Names shown for calls, participants and speakers. Every text is in Italian.
extension Call {
    private static let italianMonths = [
        "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre",
    ]

    /// The title the user gave, or the default one built from the start of the call:
    /// "Call del <giorno> <mese> <anno>, <hh:mm>" for a call tied to a call app, for example
    /// "Call del 27 ottobre 2026, 10:41", and "Registrazione del <giorno> <mese> <anno>, <hh:mm>"
    /// for a recording without a call app (`callAppName == nil`).
    var displayTitle: String {
        displayTitle(calendar: .current)
    }

    func displayTitle(calendar: Calendar) -> String {
        if let title, !title.isEmpty {
            return title
        }
        return Self.defaultTitle(for: startedAt, hasCallApp: callAppName != nil, calendar: calendar)
    }

    /// "Call del <giorno> <mese> <anno>, <hh:mm>" with the Italian month name, or
    /// "Registrazione del …" when the recording has no call app.
    static func defaultTitle(for date: Date, hasCallApp: Bool = true, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month, .year, .hour, .minute], from: date)
        let month = italianMonths[(parts.month ?? 1) - 1]
        return String(
            format: "%@ del %d %@ %d, %02d:%02d",
            hasCallApp ? "Call" : "Registrazione", parts.day ?? 1, month, parts.year ?? 1970, parts.hour ?? 0, parts.minute ?? 0
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
    /// The name the user gave, or "Partecipante <numero>".
    var displayName: String {
        if let name, !name.isEmpty {
            return name
        }
        return "Partecipante \(number)"
    }
}

extension SpeakerKind {
    /// "Io" for the user and "Altri" for the other parties as a whole. A
    /// participant is named by `Participant.displayName`.
    var displayName: String {
        switch self {
        case .me: "Io"
        case .others: "Altri"
        case .participant: "Partecipante"
        }
    }
}

extension TranscriptLine {
    /// Who spoke the line: "Io", "Altri", or the name of the participant
    /// ("Partecipante <numero>" until the user gives one).
    var speakerName: String {
        switch speakerKind {
        case .me: SpeakerKind.me.displayName
        case .others: SpeakerKind.others.displayName
        case .participant: participant?.displayName ?? SpeakerKind.others.displayName
        }
    }
}
