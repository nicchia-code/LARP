import Foundation

/// Names shown for calls, participants and speakers. Every text is in Italian.
extension Call {
    private static let italianMonths = [
        "gennaio", "febbraio", "marzo", "aprile", "maggio", "giugno",
        "luglio", "agosto", "settembre", "ottobre", "novembre", "dicembre",
    ]

    /// The title the user gave, or "Call del <giorno> <mese> <anno>, <hh:mm>"
    /// built from the start of the call, for example "Call del 27 ottobre 2026, 10:41".
    var displayTitle: String {
        displayTitle(calendar: .current)
    }

    func displayTitle(calendar: Calendar) -> String {
        if let title, !title.isEmpty {
            return title
        }
        return Self.defaultTitle(for: startedAt, calendar: calendar)
    }

    /// "Call del <giorno> <mese> <anno>, <hh:mm>" with the Italian month name.
    static func defaultTitle(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.day, .month, .year, .hour, .minute], from: date)
        let month = italianMonths[(parts.month ?? 1) - 1]
        return String(
            format: "Call del %d %@ %d, %02d:%02d",
            parts.day ?? 1, month, parts.year ?? 1970, parts.hour ?? 0, parts.minute ?? 0
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
