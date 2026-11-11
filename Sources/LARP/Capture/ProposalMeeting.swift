import Foundation

/// What the card of the proposal says about the call: the title of the meeting and the number of
/// people in it, from Microsoft Teams or from the calendar. Shown wherever the proposal appears
/// (panel, popover, banner of the library).
struct ProposalMeeting: Equatable, Sendable {
    /// The title of the meeting; `nil` for "Call rilevata".
    var title: String?
    /// The number of people in the meeting, when known.
    var peopleCount: Int?

    static let unknown = ProposalMeeting(title: nil, peopleCount: nil)

    /// The title of the meeting Teams shows, else the title of the calendar event in progress, else
    /// none; the number of people of the meeting from Teams, else the invited people of that event
    /// (the user counted too), when known. A title or a count Teams cannot give falls to the event.
    static func resolve(teams: TeamsReadout.Meeting?, event: CalendarMeeting?) -> ProposalMeeting {
        let teamsTitle = teams?.title.flatMap(nonEmpty)
        let teamsCount = teams.flatMap { $0.people.isEmpty ? nil : $0.people.count }
        return ProposalMeeting(
            title: teamsTitle ?? event?.title.flatMap(nonEmpty),
            peopleCount: teamsCount ?? event?.peopleCount)
    }

    private static func nonEmpty(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// The title of the card: the meeting's, or "Call rilevata".
    var displayTitle: String {
        title ?? L10n.string("Call rilevata")
    }

    /// "<n> persone" ("1 persona"), when the number is known.
    var peopleText: String? {
        peopleCount.map(Self.peopleText)
    }

    static func peopleText(_ count: Int) -> String {
        L10n.count(count, one: "%lld persona", other: "%lld persone")
    }
}

/// The meeting of Teams as the popover and the live window show it during a recording: its title
/// and the number of people, in one line.
enum RecordingMeetingLine {
    /// "<title> · <n> persone" of the meeting Teams shows; the title is left out when it is the one
    /// already shown as the title of the call; `nil` when there is nothing to say.
    static func text(meeting: TeamsReadout.Meeting?, callTitle: String?) -> String? {
        guard let meeting else { return nil }
        var parts: [String] = []
        if let title = meeting.title?.trimmingCharacters(in: .whitespacesAndNewlines), !title.isEmpty,
            title != callTitle
        {
            parts.append(title)
        }
        if !meeting.people.isEmpty {
            parts.append(ProposalMeeting.peopleText(meeting.people.count))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
