import Foundation

/// Formatting of times and dates of the archive, in the locale of the interface language
/// (`it_IT` or `en_US`).
enum ArchiveFormat {
    /// `mm:ss`; minutes go past 59 for long times (`75:03`). Negative times are `00:00`.
    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// `mm:ss`, or `h:mm:ss` from one hour on.
    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(max(seconds, 0).rounded(.down))
        if total >= 3600 {
            return String(format: "%d:%02d:%02d", total / 3600, total % 3600 / 60, total % 60)
        }
        return String(format: "%02d:%02d", total / 60, total % 60)
    }

    /// On a card: `<n> min`, or `<h> h <m> min` from one hour on, the minutes rounded down.
    static func cardDuration(_ seconds: TimeInterval) -> String {
        let minutes = Int(max(seconds, 0).rounded(.down)) / 60
        if minutes >= 60 {
            return String(format: "%d h %d min", minutes / 60, minutes % 60)
        }
        return String(format: "%d min", minutes)
    }

    /// The calendar of the Mac with the locale of the language.
    private static func calendar(_ calendar: Calendar, _ language: AppLanguage) -> Calendar {
        var calendar = calendar
        calendar.locale = language.locale
        return calendar
    }

    /// `27 ottobre 2026` / `27 October 2026`
    static func day(_ date: Date, calendar: Calendar = .current, language: AppLanguage = .current) -> String {
        let calendar = Self.calendar(calendar, language)
        let parts = calendar.dateComponents([.day, .month, .year], from: date)
        return "\(parts.day ?? 1) \(calendar.monthSymbols[(parts.month ?? 1) - 1]) \(parts.year ?? 1970)"
    }

    /// `10:41`: 24-hour, two digits each.
    static func time(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", parts.hour ?? 0, parts.minute ?? 0)
    }

    /// `27 ottobre 2026, 10:41` / `27 October 2026, 10:41`
    static func dayAndTime(_ date: Date, calendar: Calendar = .current, language: AppLanguage = .current) -> String {
        "\(day(date, calendar: calendar, language: language)), \(time(date, calendar: calendar))"
    }

    /// On a card: `Oggi 10:00` / `Today 10:00` for today, the short day name and the time within the
    /// last seven days (`mar 16:30` / `Tue 16:30`), otherwise `27 ott 10:41` / `27 Oct 10:41`.
    static func cardDayAndTime(
        _ date: Date, now: Date = .now, calendar: Calendar = .current, language: AppLanguage = .current
    ) -> String {
        let calendar = Self.calendar(calendar, language)
        let time = time(date, calendar: calendar)
        let days = calendar.dateComponents(
            [.day], from: calendar.startOfDay(for: date), to: calendar.startOfDay(for: now)
        ).day ?? 0
        if days == 0 {
            return "\(L10n.string("Oggi", language: language)) \(time)"
        }
        if days > 0 && days < 7 {
            return "\(calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]) \(time)"
        }
        let parts = calendar.dateComponents([.day, .month], from: date)
        return "\(parts.day ?? 1) \(calendar.shortMonthSymbols[(parts.month ?? 1) - 1]) \(time)"
    }

    /// The line above the title of the library: `mer 11 nov · 2 call oggi` / `Wed 11 Nov · 2 calls
    /// today`, or `… · nessuna call oggi` / `… · no calls today`.
    static func todayLine(
        _ date: Date = .now, callsToday: Int, calendar: Calendar = .current, language: AppLanguage = .current
    ) -> String {
        let calendar = Self.calendar(calendar, language)
        let parts = calendar.dateComponents([.day, .month], from: date)
        let weekday = calendar.shortWeekdaySymbols[calendar.component(.weekday, from: date) - 1]
        let month = calendar.shortMonthSymbols[(parts.month ?? 1) - 1]
        let count =
            callsToday == 0
            ? L10n.string("nessuna call oggi", language: language)
            : L10n.count(callsToday, one: "1 call oggi", other: "%lld call oggi", language: language)
        return "\(weekday) \(parts.day ?? 1) \(month) · \(count)"
    }

    /// The number of calls that started on the day of `now`, in the calendar of the Mac.
    static func callsStarted(on now: Date = .now, in dates: [Date], calendar: Calendar = .current) -> Int {
        dates.filter { calendar.isDate($0, inSameDayAs: now) }.count
    }

    /// `italiano (Italia)` / `Italian (Italy)` for `it-IT`; the identifier itself when unknown.
    static func language(_ identifier: String, language: AppLanguage = .current) -> String {
        language.locale.localizedString(forIdentifier: identifier) ?? identifier
    }
}

/// Markdown export of a call.
enum TranscriptExport {
    /// An H1 with the title, a line with date, time, duration and language, then, when the call
    /// has a summary, `## Sintesi` with its opening sentence and sections, when it has notes
    /// `## Note`, when it has bookmarks `## Segnalibri`, and always `## Trascrizione` with one
    /// paragraph per line as `**<speaker>** [<mm:ss>]: <text>`; in the language of the interface.
    static func markdown(for call: Call, language: AppLanguage = .current) -> String {
        var paragraphs = [
            "# \(call.displayTitle(calendar: .current, language: language))",
            L10n.format(
                "%@ · durata %@ · lingua %@",
                ArchiveFormat.dayAndTime(call.startedAt, language: language),
                ArchiveFormat.duration(call.duration),
                ArchiveFormat.language(call.transcriptionLanguage, language: language),
                language: language
            ),
        ]
        if let summary = SummaryContent(call: call, language: language) {
            paragraphs.append(contentsOf: summary.markdownParagraphs)
        }
        if !call.notes.isEmpty {
            paragraphs.append("## \(L10n.string("Note", language: language))")
            paragraphs.append(noteItems(for: call).joined(separator: "\n"))
        }
        if !call.bookmarks.isEmpty {
            paragraphs.append("## \(L10n.string("Segnalibri", language: language))")
            paragraphs.append(bookmarkItems(for: call).joined(separator: "\n"))
        }
        paragraphs.append("## \(L10n.string("Trascrizione", language: language))")
        paragraphs.append(contentsOf: transcriptParagraphs(for: call, language: language))
        return paragraphs.joined(separator: "\n\n") + "\n"
    }

    /// One `- [<mm:ss>] <text>` item per note, or `- <text>` for a note without time.
    private static func noteItems(for call: Call) -> [String] {
        call.sortedNotes.map { note in
            note.time.map { "- [\(ArchiveFormat.clock($0))] \(note.text)" } ?? "- \(note.text)"
        }
    }

    /// One `- [<mm:ss>] <text of the line at that time>` item per bookmark, or `- [<mm:ss>]` when
    /// no line is there.
    private static func bookmarkItems(for call: Call) -> [String] {
        BookmarkListing.rows(of: call).map { row in
            let clock = "- [\(ArchiveFormat.clock(row.time))]"
            return row.lineText.map { "\(clock) \($0)" } ?? clock
        }
    }

    /// One paragraph per line: `**<speaker>** [<mm:ss>]: <text>`.
    private static func transcriptParagraphs(for call: Call, language: AppLanguage) -> [String] {
        call.sortedLines.map { line in
            "**\(line.speakerName(language: language))** [\(ArchiveFormat.clock(line.start))]: \(line.text)"
        }
    }

    /// `user.COPY_SUMMARY`: the summary as the Markdown export has it, without its `## Sintesi`
    /// heading; `nil` when the call has no summary.
    static func summaryText(for call: Call, language: AppLanguage = .current) -> String? {
        guard let summary = SummaryContent(call: call, language: language) else { return nil }
        return summary.markdownParagraphs.dropFirst().joined(separator: "\n\n")
    }

    /// `user.COPY_TRANSCRIPT`: the transcript as the Markdown export has it, without its
    /// `## Trascrizione` heading; `nil` when the call has no lines.
    static func transcriptText(for call: Call, language: AppLanguage = .current) -> String? {
        let paragraphs = transcriptParagraphs(for: call, language: language)
        return paragraphs.isEmpty ? nil : paragraphs.joined(separator: "\n\n")
    }

    /// Default file name (without extension): the call title as shown, with the path separator replaced.
    static func defaultFileName(for call: Call, language: AppLanguage = .current) -> String {
        call.displayTitle(calendar: .current, language: language).replacingOccurrences(of: "/", with: "-")
    }
}

extension Call {
    /// Transcript lines in the order they are read: by start time, then by end.
    var sortedLines: [TranscriptLine] {
        lines.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    }
}
