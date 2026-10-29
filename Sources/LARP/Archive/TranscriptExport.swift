import Foundation

/// Formatting of times and dates of the archive, in Italian.
enum ArchiveFormat {
    static let locale = Locale(identifier: "it_IT")

    /// `mm:ss`; minutes go past 59 for long times (`75:03`).
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

    /// `27 ottobre 2026`
    static func day(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale).day().month(.wide).year())
    }

    /// `10:41`
    static func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(locale: locale).hour(.twoDigits(amPM: .omitted)).minute(.twoDigits))
    }

    /// `27 ottobre 2026, 10:41`
    static func dayAndTime(_ date: Date) -> String {
        "\(day(date)), \(time(date))"
    }

    /// `italiano (Italia)` for `it-IT`; the identifier itself when unknown.
    static func language(_ identifier: String) -> String {
        locale.localizedString(forIdentifier: identifier) ?? identifier
    }
}

/// Markdown export of the transcript of a call.
enum TranscriptExport {
    /// An H1 with the title, a line with date, time, duration and language, then, when the call
    /// has a summary, `## Sintesi` with its sections and `## Trascrizione`, then one paragraph
    /// per line as `**<speaker>** [<mm:ss>]: <text>`.
    static func markdown(for call: Call) -> String {
        var paragraphs = [
            "# \(call.displayTitle)",
            "\(ArchiveFormat.dayAndTime(call.startedAt)) · "
                + "durata \(ArchiveFormat.duration(call.duration)) · "
                + "lingua \(ArchiveFormat.language(call.transcriptionLanguage))",
        ]
        if let summary = SummaryContent(call: call) {
            paragraphs.append(contentsOf: summary.markdownParagraphs)
            paragraphs.append("## Trascrizione")
        }
        for line in call.sortedLines {
            paragraphs.append("**\(line.speakerName)** [\(ArchiveFormat.clock(line.start))]: \(line.text)")
        }
        return paragraphs.joined(separator: "\n\n") + "\n"
    }

    /// Default file name (without extension): the call title, with the path separator replaced.
    static func defaultFileName(for call: Call) -> String {
        call.displayTitle.replacingOccurrences(of: "/", with: "-")
    }
}

extension Call {
    /// Transcript lines in the order they are read: by start time.
    var sortedLines: [TranscriptLine] {
        lines.sorted { ($0.start, $0.end) < ($1.start, $1.end) }
    }
}
