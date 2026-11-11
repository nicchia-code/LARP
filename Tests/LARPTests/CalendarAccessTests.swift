import Foundation
import Testing

@testable import LARP

private func makeDefaults() -> UserDefaults {
    UserDefaults(suiteName: "LARPTests.\(UUID().uuidString)")!
}

/// A calendar whose access and events the test chooses; it records what was asked.
@MainActor
private final class FakeCalendar: CalendarEventSource {
    var access: CalendarAuthorization
    /// What the user answers when asked.
    var answer = true
    var events: [CalendarEvent] = []
    private(set) var requests = 0
    private(set) var settingsOpened = 0
    private(set) var queries: [(start: Date, end: Date)] = []

    init(access: CalendarAuthorization = .undetermined) {
        self.access = access
    }

    func authorization() -> CalendarAuthorization { access }

    func requestFullAccess() async -> Bool {
        requests += 1
        access = answer ? .granted : .denied
        return answer
    }

    func events(from start: Date, to end: Date) -> [CalendarEvent] {
        queries.append((start, end))
        return events
    }

    func openSettings() { settingsOpened += 1 }
}

private let utc: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "UTC")!
    return calendar
}()

/// 2026-10-27 at `hour`:`minute` UTC.
private func at(_ hour: Int, _ minute: Int = 0, day: Int = 27) -> Date {
    utc.date(from: DateComponents(year: 2026, month: 10, day: day, hour: hour, minute: minute))!
}

private func event(
    _ title: String, _ start: Date, _ end: Date, allDay: Bool = false, url: String? = nil,
    location: String? = nil, notes: String? = nil, invitees: [String] = []
) -> CalendarEvent {
    CalendarEvent(
        title: title, start: start, end: end, isAllDay: allDay, url: url.flatMap(URL.init(string:)),
        location: location, notes: notes, invitees: invitees)
}

@Suite("Calendar access", .serialized)
@MainActor
struct CalendarAccessTests {
    @MainActor
    private struct Fixture {
        let defaults = makeDefaults()
        let calendar: FakeCalendar
        let controller: CalendarAccessController

        init(access: CalendarAuthorization = .undetermined, connected: Bool = false, now: Date = at(10, 30)) {
            let defaults = defaults
            if connected { defaults.set(true, forKey: SettingsKey.calendarConnected) }
            calendar = FakeCalendar(access: access)
            controller = CalendarAccessController(
                defaults: defaults, source: calendar, calendar: utc, now: { now })
        }

        var saved: Bool { defaults.bool(forKey: SettingsKey.calendarConnected) }
    }

    // MARK: The machine

    @Test("the transition table of calendar-access")
    func table() {
        typealias M = CalendarAccessMachine
        #expect(M.target(from: .notConnected, on: .connect(access: .granted)) == .connected)
        #expect(M.target(from: .notConnected, on: .connect(access: .denied)) == .refused)
        #expect(M.target(from: .notConnected, on: .disconnect) == nil)
        #expect(M.target(from: .notConnected, on: .appLaunched(access: .granted)) == nil)
        #expect(M.target(from: .notConnected, on: .openSettings(access: .denied)) == nil)

        #expect(M.target(from: .connected, on: .disconnect) == .notConnected)
        #expect(M.target(from: .connected, on: .appLaunched(access: .denied)) == .refused)
        #expect(M.target(from: .connected, on: .appLaunched(access: .undetermined)) == .refused)
        #expect(M.target(from: .connected, on: .appLaunched(access: .granted)) == nil)
        #expect(M.target(from: .connected, on: .openSettings(access: .denied)) == .refused)
        #expect(M.target(from: .connected, on: .openSettings(access: .granted)) == nil)

        #expect(M.target(from: .refused, on: .connect(access: .denied)) == .refused)
        #expect(M.target(from: .refused, on: .appLaunched(access: .granted)) == .connected)
        #expect(M.target(from: .refused, on: .appLaunched(access: .denied)) == nil)
        #expect(M.target(from: .refused, on: .openSettings(access: .granted)) == .connected)
        #expect(M.target(from: .refused, on: .openSettings(access: .denied)) == nil)
        #expect(M.target(from: .refused, on: .disconnect) == .notConnected)
    }

    @Test("the calendar starts not connected, or connected when it was before")
    func initialState() {
        #expect(Fixture().controller.state == .notConnected)
        #expect(Fixture(connected: true).controller.state == .connected)
    }

    @Test("user.CONNECT_CALENDAR asks macOS the first time and goes to Connected when it is granted")
    func connectGranted() async {
        let f = Fixture(access: .undetermined)
        await f.controller.connect()
        #expect(f.calendar.requests == 1)
        #expect(f.controller.state == .connected)
        #expect(f.saved)
    }

    @Test("user.CONNECT_CALENDAR goes to Refused when the user refuses; the choice is saved")
    func connectRefusedNow() async {
        let f = Fixture(access: .undetermined)
        f.calendar.answer = false
        await f.controller.connect()
        #expect(f.calendar.requests == 1)
        #expect(f.controller.state == .refused)
        #expect(f.saved)
        #expect(f.calendar.settingsOpened == 0)
    }

    @Test("user.CONNECT_CALENDAR goes to Refused without asking when the user refused before")
    func connectRefusedBefore() async {
        let f = Fixture(access: .denied)
        await f.controller.connect()
        #expect(f.calendar.requests == 0)
        #expect(f.controller.state == .refused)
        #expect(f.saved)
    }

    @Test("user.CONNECT_CALENDAR does not ask again when macOS already grants the access")
    func connectAlreadyGranted() async {
        let f = Fixture(access: .granted)
        await f.controller.connect()
        #expect(f.calendar.requests == 0)
        #expect(f.controller.state == .connected)
    }

    @Test("user.CONNECT_CALENDAR while Refused opens the calendars pane and stays")
    func connectWhileRefused() async {
        let f = Fixture(access: .denied)
        await f.controller.connect()
        await f.controller.connect()
        #expect(f.controller.state == .refused)
        #expect(f.calendar.settingsOpened == 1)
        #expect(f.calendar.requests == 0)
    }

    @Test("user.CONNECT_CALENDAR while Connected does nothing")
    func connectWhileConnected() async {
        let f = Fixture(access: .granted, connected: true)
        await f.controller.connect()
        #expect(f.controller.state == .connected)
        #expect(f.calendar.settingsOpened == 0)
        #expect(f.calendar.requests == 0)
    }

    @Test("user.DISCONNECT_CALENDAR goes to Not connected, saves the choice and stops the readings")
    func disconnect() {
        let f = Fixture(access: .granted, connected: true)
        f.calendar.events = [
            event("Now", at(10), at(11)), event("Later", at(15), at(16), url: "https://zoom.us/j/1"),
        ]
        #expect(f.controller.meetingInProgress() != nil)
        f.controller.disconnect()
        #expect(f.controller.state == .notConnected)
        #expect(!f.saved)
        let queries = f.calendar.queries.count
        #expect(f.controller.meetingInProgress() == nil)
        #expect(f.controller.upcomingMeetings().isEmpty)
        #expect(f.calendar.queries.count == queries)
    }

    @Test("user.DISCONNECT_CALENDAR from Refused goes to Not connected and saves the choice")
    func disconnectFromRefused() async {
        let f = Fixture(access: .denied)
        await f.controller.connect()
        f.controller.disconnect()
        #expect(f.controller.state == .notConnected)
        #expect(!f.saved)
    }

    @Test("user.DISCONNECT_CALENDAR while Not connected does nothing")
    func disconnectWhileNotConnected() {
        let f = Fixture()
        f.controller.disconnect()
        #expect(f.controller.state == .notConnected)
    }

    @Test("macos.APP_LAUNCHED and user.OPEN_SETTINGS: Connected goes to Refused when macOS no longer grants the access")
    func accessLost() {
        let f = Fixture(access: .denied, connected: true)
        f.controller.appLaunched()
        #expect(f.controller.state == .refused)
        // The choice of connecting stays saved.
        #expect(f.saved)

        let g = Fixture(access: .denied, connected: true)
        g.controller.openSettings()
        #expect(g.controller.state == .refused)
    }

    @Test("macos.APP_LAUNCHED and user.OPEN_SETTINGS: Refused goes to Connected when macOS grants the access now")
    func accessBack() async {
        let f = Fixture(access: .denied)
        await f.controller.connect()
        f.controller.appLaunched()
        #expect(f.controller.state == .refused)
        f.calendar.access = .granted
        f.controller.appLaunched()
        #expect(f.controller.state == .connected)

        let g = Fixture(access: .denied, connected: true)
        g.controller.appLaunched()
        g.calendar.access = .granted
        g.controller.openSettings()
        #expect(g.controller.state == .connected)
    }

    @Test("macos.APP_LAUNCHED and user.OPEN_SETTINGS leave Connected as it is while macOS grants the access")
    func accessKept() {
        let f = Fixture(access: .granted, connected: true)
        f.controller.appLaunched()
        f.controller.openSettings()
        #expect(f.controller.state == .connected)
    }

    @Test("the settings open the machine's read of the access")
    func settingsEvent() {
        let f = Fixture(access: .denied, connected: true)
        SettingsEvents.openSettings(calendarAccess: f.controller)
        #expect(f.controller.state == .refused)
    }

    // MARK: Readings

    @Test("the readings look at the events of today, every calendar")
    func today() {
        let f = Fixture(access: .granted, connected: true, now: at(10, 30))
        _ = f.controller.meetingInProgress()
        _ = f.controller.upcomingMeetings()
        #expect(f.calendar.queries.count == 2)
        for query in f.calendar.queries {
            #expect(query.start == at(0))
            #expect(query.end == at(0, day: 28))
        }
    }

    @Test("the event in progress is the one that started last, not all-day, ending after now")
    func inProgress() {
        let now = at(10, 30)
        let events = [
            event("Early", at(9), at(11), invitees: ["Anna"]),
            event("Late", at(10), at(12), invitees: ["Bruno", " ", "Carla"]),
            event("Starts now", at(10, 30), at(11), invitees: []),
            event("Ended", at(10, 30), at(10, 30)),
            event("Over", at(9), at(10)),
            event("Not yet", at(10, 31), at(12)),
            event("All day", at(0), at(0, day: 28), allDay: true),
        ]
        let meeting = CalendarRules.meetingInProgress(in: events, at: now)
        #expect(meeting == CalendarMeeting(title: "Starts now", invitees: []))
        #expect(meeting?.peopleCount == nil)

        let withoutNow = CalendarRules.meetingInProgress(in: Array(events.filter { $0.title != "Starts now" }), at: now)
        #expect(withoutNow == CalendarMeeting(title: "Late", invitees: ["Bruno", "Carla"]))
        #expect(withoutNow?.peopleCount == 3)
    }

    @Test("with no event in progress there is no event, and an untitled event has no title")
    func noneInProgress() {
        #expect(CalendarRules.meetingInProgress(in: [], at: at(10)) == nil)
        #expect(CalendarRules.meetingInProgress(in: [event("Later", at(11), at(12))], at: at(10)) == nil)
        #expect(CalendarRules.meetingInProgress(in: [event(" ", at(9), at(11))], at: at(10))?.title == nil)
    }

    @Test("Prossime: events later than now with the link of a known call app, by start, at most three")
    func upcoming() {
        let now = at(10)
        let events = [
            event("Four", at(16), at(17), url: "https://zoom.us/j/4"),
            event("Teams", at(12), at(13), url: "https://teams.microsoft.com/l/meetup-join/abc"),
            event("Live", at(11), at(12), notes: "Join: https://teams.live.com/meet/1"),
            event("Meet", at(14), at(15), location: "https://meet.google.com/abc-defg-hij"),
            event("Webex", at(13), at(14), url: "https://acme.webex.com/meet/x"),
            event("Started", at(9), at(11), url: "https://zoom.us/j/9"),
            event("Starts now", at(10), at(11), url: "https://zoom.us/j/9"),
            event("All day", at(0, day: 27), at(0, day: 28), allDay: true, url: "https://zoom.us/j/9"),
            event("No link", at(11, 30), at(12), notes: "Room 4"),
        ]
        let upcoming = CalendarRules.upcoming(in: events, after: now)
        #expect(upcoming.map(\.title) == ["Live", "Teams", "Webex"])
        #expect(upcoming.map(\.appName) == ["Microsoft Teams", "Microsoft Teams", "Webex"])
        #expect(upcoming.map(\.start) == [at(11), at(12), at(13)])
    }

    @Test("Prossime names the app of every known link")
    func upcomingApps() {
        let now = at(8)
        let links = [
            "https://us04web.zoom.us/j/1": "Zoom",
            "https://meet.google.com/x": "Google Meet",
            "https://facetime.apple.com/join#v=1": "FaceTime",
            "HTTPS://TEAMS.MICROSOFT.COM/x": "Microsoft Teams",
        ]
        for (link, app) in links {
            let upcoming = CalendarRules.upcoming(in: [event("E", at(9), at(10), notes: link)], after: now)
            #expect(upcoming.map(\.appName) == [app])
        }
    }

    @Test("a call app domain that ends a longer word is not a link")
    func linkBoundary() {
        #expect(KnownCallLinks.appName(in: ["see notzoom.us"]) == nil)
        #expect(KnownCallLinks.appName(in: ["see zoom.us/j/1"]) == "Zoom")
        #expect(KnownCallLinks.appName(in: ["notzoom.us and then https://zoom.us/j/2"]) == "Zoom")
        #expect(KnownCallLinks.appName(in: [nil, "", "x-webex.com"]) == nil)
        // The URL is looked at before the location and the notes.
        #expect(KnownCallLinks.appName(in: ["https://zoom.us/j/1", "https://webex.com/x"]) == "Zoom")
    }

    @Test("the invited people count the user too")
    func peopleCount() {
        #expect(CalendarMeeting(title: "T", invitees: ["Anna", "Bruno"]).peopleCount == 3)
    }
}
