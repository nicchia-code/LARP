import AppKit
import EventKit
import Foundation

/// Where macOS stands on the access to the events of the calendars, read without asking.
enum CalendarAuthorization: Sendable, Equatable {
    /// Full access to the events.
    case granted
    /// Not decided yet (or only write access, which does not let LARP read).
    case undetermined
    /// Refused or restricted: only System Settings can change it.
    case denied
}

/// An event of a calendar of the Mac, as LARP reads it.
struct CalendarEvent: Equatable, Sendable {
    var title: String
    var start: Date
    var end: Date
    var isAllDay = false
    var url: URL?
    var location: String?
    var notes: String?
    /// The names of the attendees that have one, without the user.
    var invitees: [String] = []
}

/// What LARP needs from the calendars of the Mac. Replaced in tests.
@MainActor
protocol CalendarEventSource: AnyObject {
    /// The access macOS grants for the events; never asks.
    func authorization() -> CalendarAuthorization
    /// Asks the user for full access to the events (macOS shows its prompt the first time) and
    /// returns whether it was granted.
    func requestFullAccess() async -> Bool
    /// The events of every calendar that overlap `start` ..< `end`, all-day ones included.
    func events(from start: Date, to end: Date) -> [CalendarEvent]
    /// Opens the calendars pane of System Settings.
    func openSettings()
}

/// The real calendars: one `EKEventStore`.
@MainActor
final class SystemCalendarEvents: CalendarEventSource {
    private let store = EKEventStore()

    static let settingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars")!

    func authorization() -> CalendarAuthorization {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: .granted
        case .notDetermined, .writeOnly: .undetermined
        default: .denied
        }
    }

    func requestFullAccess() async -> Bool {
        (try? await store.requestFullAccessToEvents()) ?? false
    }

    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: nil)
        return store.events(matching: predicate).map { event in
            CalendarEvent(
                title: event.title ?? "",
                start: event.startDate,
                end: event.endDate,
                isAllDay: event.isAllDay,
                url: event.url,
                location: event.location,
                notes: event.notes,
                invitees: (event.attendees ?? []).compactMap { attendee in
                    guard !attendee.isCurrentUser else { return nil }
                    return attendee.name
                })
        }
    }

    func openSettings() {
        NSWorkspace.shared.open(Self.settingsURL)
    }
}
