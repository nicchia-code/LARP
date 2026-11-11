import Foundation
import Observation

/// Events the `calendar-access` machine reacts to. Events with a guard carry the facts the guard
/// needs.
enum CalendarAccessEvent: Equatable, Sendable {
    /// `user.CONNECT_CALENDAR`. `access`: what macOS grants for the events once the user has been
    /// asked, if the machine had to ask.
    case connect(access: CalendarAuthorization)
    /// `user.DISCONNECT_CALENDAR`
    case disconnect
    /// `macos.APP_LAUNCHED`. `access`: what macOS grants now.
    case appLaunched(access: CalendarAuthorization)
    /// `user.OPEN_SETTINGS`. `access`: what macOS grants now.
    case openSettings(access: CalendarAuthorization)
}

/// States of the `calendar-access` machine.
enum CalendarAccessState: Sendable, Equatable {
    /// The calendar is not read.
    case notConnected
    /// The calendar is read.
    case connected
    /// The user wants the calendar but macOS does not grant the access.
    case refused
}

/// The transition table of the `calendar-access` machine (Model `meeting-info/calendar-access`).
/// Pure: it only says where an event leads; `CalendarAccessController` performs the effects. A
/// state that does not react to an event has no entry (`nil`); a transition to the same state is
/// an entry (`CalendarAccessController` tells what it does on `.connect` while refused).
enum CalendarAccessMachine {
    static func target(from state: CalendarAccessState, on event: CalendarAccessEvent) -> CalendarAccessState? {
        switch (state, event) {
        // Not connected
        case (.notConnected, .connect(let access)):
            return access == .granted ? .connected : .refused

        // Connected
        case (.connected, .disconnect):
            return .notConnected
        case (.connected, .appLaunched(let access)), (.connected, .openSettings(let access)):
            return access == .granted ? nil : .refused

        // Refused
        case (.refused, .connect):
            return .refused
        case (.refused, .appLaunched(let access)), (.refused, .openSettings(let access)):
            return access == .granted ? .connected : nil
        case (.refused, .disconnect):
            return .notConnected

        default:
            return nil
        }
    }
}

/// A call found in the calendar: the event in progress when a recording starts.
struct CalendarMeeting: Equatable, Sendable {
    /// The title of the event; `nil` when it has none.
    var title: String?
    /// The attendees that have a name, without the user.
    var invitees: [String]

    /// The number of people of the call, the user included; `nil` when the event names no one
    /// else, which leaves the number unknown.
    var peopleCount: Int? { invitees.isEmpty ? nil : invitees.count + 1 }
}

/// A meeting of the rest of the day, for "Prossime".
struct UpcomingMeeting: Equatable, Sendable, Identifiable {
    var start: Date
    /// The title of the event, empty when it has none.
    var title: String
    /// The name of the call app of its link.
    var appName: String

    var id: String { "\(start.timeIntervalSinceReferenceDate)|\(title)|\(appName)" }
}

/// What is read from the events. Pure, on the events already fetched.
enum CalendarRules {
    /// At most this many meetings in "Prossime".
    static let upcomingLimit = 3

    /// The event in progress at `now`: among the events that are not all-day and whose start is at
    /// or before `now` and whose end is after it, the one that started last.
    static func meetingInProgress(in events: [CalendarEvent], at now: Date) -> CalendarMeeting? {
        var latest: CalendarEvent?
        for event in events where !event.isAllDay && event.start <= now && event.end > now {
            if latest == nil || event.start > latest!.start {
                latest = event
            }
        }
        guard let latest else { return nil }
        let title = latest.title.trimmingCharacters(in: .whitespacesAndNewlines)
        return CalendarMeeting(
            title: title.isEmpty ? nil : title,
            invitees: latest.invitees
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty })
    }

    /// The events that start later than `now`, are not all-day and hold the link of a known call
    /// app in their URL, location or notes, by start, at most three. `events` are those of today.
    static func upcoming(in events: [CalendarEvent], after now: Date) -> [UpcomingMeeting] {
        let meetings: [UpcomingMeeting] = events.compactMap { event in
            guard !event.isAllDay, event.start > now,
                let appName = KnownCallLinks.appName(in: [event.url?.absoluteString, event.location, event.notes])
            else { return nil }
            return UpcomingMeeting(
                start: event.start,
                title: event.title.trimmingCharacters(in: .whitespacesAndNewlines),
                appName: appName)
        }
        return Array(meetings.sorted { ($0.start, $0.title) < ($1.start, $1.title) }.prefix(upcomingLimit))
    }
}

/// The `calendar-access` machine: whether LARP reads the calendar of the Mac. The choice of
/// connecting lives in `UserDefaults` (`SettingsKey.calendarConnected`, no by default); what macOS
/// grants is read each time and kept only in memory, as the state.
///
/// While the state is Connected the calendar is read: the event in progress when a recording
/// starts and the meetings of the rest of the day. Nothing read here goes to omp.
@MainActor
@Observable
final class CalendarAccessController {
    /// The controller shared by the app: the settings page, the welcome window, the popover and
    /// the recorder read the same instance.
    static let shared = CalendarAccessController()

    private(set) var state: CalendarAccessState
    /// The system is being asked for the access: a second `connect()` is ignored meanwhile.
    private(set) var isAsking = false

    /// The calendar is read.
    var isConnected: Bool { state == .connected }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let source: any CalendarEventSource
    @ObservationIgnored private let calendar: Calendar
    @ObservationIgnored private let now: @MainActor () -> Date

    init(
        defaults: UserDefaults = .standard,
        source: any CalendarEventSource = SystemCalendarEvents(),
        calendar: Calendar = .current,
        now: @escaping @MainActor () -> Date = { Date() }
    ) {
        self.defaults = defaults
        self.source = source
        self.calendar = calendar
        self.now = now
        state = defaults.bool(forKey: SettingsKey.calendarConnected) ? .connected : .notConnected
    }

    // MARK: Events

    /// `user.CONNECT_CALENDAR`: from Not connected, macOS is asked for full access to the events
    /// (the prompt shows the first time) and the choice is saved; from Refused, the calendars pane
    /// of System Settings opens.
    func connect() async {
        switch state {
        case .connected:
            return
        case .refused:
            source.openSettings()
        case .notConnected:
            guard !isAsking else { return }
            isAsking = true
            defer { isAsking = false }
            var access = source.authorization()
            if access == .undetermined {
                access = await source.requestFullAccess() ? .granted : .denied
            }
            // A refusal never leaves `access` undetermined: `denied` and `granted` are the answers.
            guard state == .notConnected,
                let target = CalendarAccessMachine.target(from: state, on: .connect(access: access))
            else { return }
            defaults.set(true, forKey: SettingsKey.calendarConnected)
            state = target
        }
    }

    /// `user.DISCONNECT_CALENDAR`: Connected or Refused → Not connected. The choice is saved; the
    /// permission of macOS stays as it is.
    func disconnect() {
        guard let target = CalendarAccessMachine.target(from: state, on: .disconnect) else { return }
        defaults.set(false, forKey: SettingsKey.calendarConnected)
        state = target
    }

    /// `macos.APP_LAUNCHED`: what macOS grants is read again.
    func appLaunched() {
        apply(.appLaunched(access: source.authorization()))
    }

    /// `user.OPEN_SETTINGS`: what macOS grants is read again.
    func openSettings() {
        apply(.openSettings(access: source.authorization()))
    }

    private func apply(_ event: CalendarAccessEvent) {
        if let target = CalendarAccessMachine.target(from: state, on: event) {
            state = target
        }
    }

    // MARK: Readings

    /// The event in progress when a recording starts, among the events of every calendar of the
    /// Mac; `nil` when none, and while the calendar is not connected.
    func meetingInProgress() -> CalendarMeeting? {
        guard isConnected else { return nil }
        let moment = now()
        return CalendarRules.meetingInProgress(in: eventsOfToday(at: moment), at: moment)
    }

    /// The next meetings of the day with the link of a known call app, at most three, by start,
    /// for "Prossime"; read again every time it is called (the popover calls it when it opens).
    /// Empty while the calendar is not connected.
    func upcomingMeetings() -> [UpcomingMeeting] {
        guard isConnected else { return [] }
        let moment = now()
        return CalendarRules.upcoming(in: eventsOfToday(at: moment), after: moment)
    }

    private func eventsOfToday(at moment: Date) -> [CalendarEvent] {
        let startOfDay = calendar.startOfDay(for: moment)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        return source.events(from: startOfDay, to: endOfDay)
    }
}
