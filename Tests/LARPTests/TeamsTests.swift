import Foundation
import Synchronization
import Testing

@testable import LARP

/// The Accessibility permission as a test sets it.
private final class FakePermission: AccessibilityPermission {
    private let state = Mutex((granted: false, requests: 0))

    var isGranted: Bool { state.withLock { $0.granted } }
    var requests: Int { state.withLock { $0.requests } }

    func request() { state.withLock { $0.requests += 1 } }
    func set(granted: Bool) { state.withLock { $0.granted = granted } }
}

/// A fake Teams: the test emits what Teams would show.
@MainActor
private final class FakeTeamsReader: TeamsReading {
    private(set) var startCount = 0
    private(set) var stopCount = 0
    private var onReadout: (@MainActor (TeamsReadout) -> Void)?

    var isReading: Bool { onReadout != nil }

    func start(onReadout: @escaping @MainActor (TeamsReadout) -> Void) {
        startCount += 1
        self.onReadout = onReadout
    }

    func stop() {
        stopCount += 1
        onReadout = nil
    }

    /// Teams shows `meeting` (or none).
    func show(_ meeting: TeamsReadout.Meeting?) {
        onReadout?(TeamsReadout(meeting: meeting))
    }
}

private let suite = "com.larp.tests.teams"

@MainActor
private func isolatedDefaults() -> UserDefaults {
    let defaults = UserDefaults(suiteName: "\(suite).\(UUID().uuidString)")!
    return defaults
}

// MARK: - Teams access

@Suite("Teams access", .serialized)
@MainActor
struct TeamsAccessTests {
    @Test(
        "the transition table of teams-access",
        arguments: [
            (TeamsAccessState.notAllowed, TeamsAccessEvent.appLaunched(permissionGranted: true), TeamsAccessState.allowed),
            (.notAllowed, .appLaunched(permissionGranted: false), nil),
            (.notAllowed, .openSettings(permissionGranted: true), .allowed),
            (.notAllowed, .openSettings(permissionGranted: false), nil),
            (.notAllowed, .allowTeamsAccess, .awaitingPermission),
            (.awaitingPermission, .accessibilityCheckDue(permissionGranted: true, twoMinutesPassed: false), .allowed),
            (.awaitingPermission, .accessibilityCheckDue(permissionGranted: true, twoMinutesPassed: true), .allowed),
            (.awaitingPermission, .accessibilityCheckDue(permissionGranted: false, twoMinutesPassed: false), .awaitingPermission),
            (.awaitingPermission, .accessibilityCheckDue(permissionGranted: false, twoMinutesPassed: true), .notAllowed),
            (.awaitingPermission, .openSettings(permissionGranted: true), .allowed),
            (.awaitingPermission, .openSettings(permissionGranted: false), nil),
            (.allowed, .appLaunched(permissionGranted: true), nil),
            (.allowed, .openSettings(permissionGranted: true), nil),
            (.allowed, .allowTeamsAccess, nil),
        ] as [(TeamsAccessState, TeamsAccessEvent, TeamsAccessState?)])
    func table(state: TeamsAccessState, event: TeamsAccessEvent, expected: TeamsAccessState?) {
        #expect(TeamsAccessStateMachine.target(from: state, on: event)?.state == expected)
    }

    @Test("a missing permission in Allowed leads to Not allowed and emits ACCESS_LOST")
    func lossEmitsAccessLost() {
        for event in [
            TeamsAccessEvent.appLaunched(permissionGranted: false), .openSettings(permissionGranted: false),
        ] {
            let transition = TeamsAccessStateMachine.target(from: .allowed, on: event)
            #expect(transition == TeamsAccessTransition(state: .notAllowed, emitsAccessLost: true))
        }
    }

    private func makeController(
        permission: FakePermission = FakePermission(),
        defaults: UserDefaults? = nil,
        now: @escaping @Sendable () -> Date = { Date() },
        interval: Duration = .seconds(3600)
    ) -> (TeamsAccessController, FakePermission, UserDefaults) {
        let defaults = defaults ?? isolatedDefaults()
        return (
            TeamsAccessController(permission: permission, defaults: defaults, now: now, checkInterval: interval),
            permission, defaults
        )
    }

    @Test("at launch the permission is read: granted gives Allowed")
    func launchWithPermission() {
        let (controller, permission, defaults) = makeController()
        permission.set(granted: true)
        controller.appLaunched()
        #expect(controller.state == .allowed)
        #expect(defaults.bool(forKey: SettingsKey.teamsAccessGranted))
    }

    @Test("at launch without the permission the state stays Not allowed and nothing is remembered")
    func launchWithoutPermission() {
        let (controller, _, defaults) = makeController()
        controller.appLaunched()
        #expect(controller.state == .notAllowed)
        #expect(!controller.mustBeAllowedAgain)
        #expect(!defaults.bool(forKey: SettingsKey.teamsAccessGranted))
    }

    @Test("\"Consenti\" asks macOS, opens System Settings and waits")
    func allow() {
        let (controller, permission, _) = makeController()
        controller.allowTeamsAccess()
        #expect(controller.state == .awaitingPermission)
        #expect(permission.requests == 1)
        // Asking again while waiting does nothing more.
        controller.allowTeamsAccess()
        #expect(permission.requests == 1)
    }

    @Test("while waiting, the permission granted gives Allowed")
    func grantedWhileWaiting() {
        let (controller, permission, defaults) = makeController()
        controller.allowTeamsAccess()
        controller.accessibilityCheckDue()
        #expect(controller.state == .awaitingPermission)
        permission.set(granted: true)
        controller.accessibilityCheckDue()
        #expect(controller.state == .allowed)
        #expect(defaults.bool(forKey: SettingsKey.teamsAccessGranted))
    }

    @Test("two minutes without the permission lead back to Not allowed; before that it keeps waiting")
    func timeout() {
        let clock = Mutex(Date(timeIntervalSince1970: 1_800_000_000))
        let (controller, _, _) = makeController(now: { clock.withLock { $0 } })
        controller.allowTeamsAccess()
        clock.withLock { $0 = $0.addingTimeInterval(119) }
        controller.accessibilityCheckDue()
        #expect(controller.state == .awaitingPermission)
        clock.withLock { $0 = $0.addingTimeInterval(1) }
        controller.accessibilityCheckDue()
        #expect(controller.state == .notAllowed)
    }

    @Test("while waiting the permission is read on its own, and the checks stop once it is Allowed")
    func checksRunByThemselves() async {
        let (controller, permission, _) = makeController(interval: .milliseconds(10))
        controller.allowTeamsAccess()
        permission.set(granted: true)
        for _ in 0..<300 where controller.state != .allowed {
            try? await Task.sleep(for: .milliseconds(10))
        }
        #expect(controller.state == .allowed)
    }

    @Test("opening the settings reads the permission again, from Not allowed and from Awaiting")
    func openSettingsReadsAgain() {
        let (controller, permission, _) = makeController()
        permission.set(granted: true)
        controller.openSettings()
        #expect(controller.state == .allowed)

        let (waiting, other, _) = makeController()
        waiting.allowTeamsAccess()
        waiting.openSettings()
        #expect(waiting.state == .awaitingPermission)
        other.set(granted: true)
        waiting.openSettings()
        #expect(waiting.state == .allowed)
    }

    @Test("a permission lost after an update goes back to Not allowed, emits ACCESS_LOST and is remembered")
    func lossAfterUpdate() async {
        let defaults = isolatedDefaults()
        let (controller, permission, _) = makeController(defaults: defaults)
        permission.set(granted: true)
        controller.appLaunched()
        let lost = controller.accessLostEvents
        permission.set(granted: false)
        controller.openSettings()
        #expect(controller.state == .notAllowed)
        #expect(controller.mustBeAllowedAgain)
        var iterator = lost.makeAsyncIterator()
        #expect(await iterator.next() != nil)

        // A new version of the app, with the permission still missing: it must be allowed again.
        let (next, _, _) = makeController(defaults: defaults)
        next.appLaunched()
        #expect(next.state == .notAllowed)
        #expect(next.mustBeAllowedAgain)
    }

    @Test("the state of the permission itself is not stored")
    func permissionIsNotStored() {
        let defaults = isolatedDefaults()
        let (controller, permission, _) = makeController(defaults: defaults)
        controller.allowTeamsAccess()
        permission.set(granted: true)
        controller.accessibilityCheckDue()
        let (fresh, _, _) = makeController(defaults: defaults)
        #expect(fresh.state == .notAllowed)
    }
}

// MARK: - What is read from Teams

@Suite("Teams text")
struct TeamsTextTests {
    @Test(
        "the title of the meeting is the title of its window without the ending",
        arguments: [
            ("Riunione di prodotto | Microsoft Teams", "Riunione di prodotto"),
            ("  Daily  | Microsoft Teams", "Daily"),
            ("Daily", "Daily"),
        ])
    func title(window: String, expected: String) {
        #expect(TeamsText.meetingTitle(fromWindowTitle: window) == expected)
    }

    @Test(
        "an empty title or the name of a section of Teams is no title",
        arguments: ["", " | Microsoft Teams", "Chat | Microsoft Teams", "Calendar | Microsoft Teams", "Attività | Microsoft Teams",
            "Microsoft Teams", "calendario"])
    func noTitle(window: String) {
        #expect(TeamsText.meetingTitle(fromWindowTitle: window) == nil)
    }

    @Test("a missing window title is no title")
    func missingTitle() {
        #expect(TeamsText.meetingTitle(fromWindowTitle: nil) == nil)
    }

    @Test(
        "a name is kept trimmed and without the additions Teams writes after it",
        arguments: [
            ("  Anna Rossi ", "Anna Rossi"),
            ("Anna Rossi (Ospite)", "Anna Rossi"),
            ("Mark Lee (Guest)", "Mark Lee"),
            ("Mark Lee (Guest) (Unverified)", "Mark Lee"),
            ("Luca (Marketing) (Esterno)", "Luca"),
        ])
    func name(raw: String, expected: String) {
        #expect(TeamsText.personName(from: raw) == expected)
    }

    @Test(
        "the user's own name, as Teams writes it for \"you\", and empty names are left out",
        arguments: ["Luca Bianchi (Tu)", "Luca Bianchi (You)", "Luca Bianchi (Ospite) (Tu)", "", "  ", "(Guest)"])
    func leftOut(raw: String) {
        #expect(TeamsText.personName(from: raw) == nil)
    }

    @Test("the people are cleaned, without the user and without repeats, in order")
    func people() {
        let people = TeamsText.people(from: ["Anna (Ospite)", "Luca (Tu)", "Marco", "anna", " Marco "])
        #expect(people == ["Anna", "Marco"])
    }
}

// MARK: - Teams meeting

@Suite("Teams meeting", .serialized)
@MainActor
struct TeamsMeetingTests {
    private struct Setup {
        let access: TeamsAccessController
        let permission: FakePermission
        let reader: FakeTeamsReader
        let controller: TeamsMeetingController
    }

    private func makeSetup(allowed: Bool = true) -> Setup {
        let permission = FakePermission()
        permission.set(granted: allowed)
        let access = TeamsAccessController(
            permission: permission, defaults: isolatedDefaults(), checkInterval: .seconds(3600))
        access.appLaunched()
        let reader = FakeTeamsReader()
        let controller = TeamsMeetingController(access: access, reader: reader)
        controller.start()
        return Setup(access: access, permission: permission, reader: reader, controller: controller)
    }

    private func collect(_ controller: TeamsMeetingController) -> NewsLog {
        let log = NewsLog()
        let stream = controller.news
        log.task = Task { for await news in stream { log.items.append(news) } }
        return log
    }

    @MainActor
    private final class NewsLog {
        var items: [TeamsMeetingNews] = []
        var task: Task<Void, Never>?
        /// Returns once the news has stopped arriving for a few milliseconds. Every test builds its own
        /// access controller, reader and meeting controller (no singleton is touched), so the only
        /// thing to wait for is the hop of the news through its `AsyncStream` to the main actor; the
        /// earlier flake came from waiting a fixed number of yields for it under load.
        func settle() async {
            var last = -1
            var stable = 0
            for _ in 0..<500 {
                try? await Task.sleep(for: .milliseconds(5))
                if items.count == last {
                    stable += 1
                    if stable >= 4 { return }
                } else {
                    last = items.count
                    stable = 0
                }
            }
        }
        deinit { task?.cancel() }
    }

    @Test(
        "the transition table of teams-meeting",
        arguments: [
            (TeamsMeetingState.noMeeting, TeamsMeetingEvent.meetingJoined(accessAllowed: true), TeamsMeetingState.inMeeting),
            (.noMeeting, .meetingJoined(accessAllowed: false), nil),
            (.noMeeting, .participantsRead, nil),
            (.noMeeting, .speakerChanged, nil),
            (.noMeeting, .meetingLeft, nil),
            (.inMeeting, .participantsRead, .inMeeting),
            (.inMeeting, .speakerChanged, .inMeeting),
            (.inMeeting, .meetingLeft, .noMeeting),
            (.inMeeting, .accessLost, .noMeeting),
            (.inMeeting, .meetingJoined(accessAllowed: true), nil),
        ] as [(TeamsMeetingState, TeamsMeetingEvent, TeamsMeetingState?)])
    func table(state: TeamsMeetingState, event: TeamsMeetingEvent, expected: TeamsMeetingState?) {
        #expect(TeamsMeetingStateMachine.target(from: state, on: event) == expected)
    }

    @Test("Teams is read only while access is allowed")
    func readsOnlyWhileAllowed() {
        let setup = makeSetup(allowed: false)
        #expect(!setup.reader.isReading)
        #expect(setup.reader.startCount == 0)
        setup.reader.show(TeamsReadout.Meeting(title: "Daily"))
        #expect(setup.controller.state == .noMeeting)
    }

    @Test("the reading starts when access becomes allowed and stops when it is lost")
    func readingFollowsAccess() async {
        let setup = makeSetup(allowed: false)
        setup.permission.set(granted: true)
        setup.access.openSettings()
        for _ in 0..<300 where !setup.reader.isReading { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(setup.reader.isReading)

        setup.permission.set(granted: false)
        setup.access.openSettings()
        for _ in 0..<300 where setup.reader.isReading { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(!setup.reader.isReading)
    }

    @Test("a meeting joined gives its title; people and speaker follow")
    func joined() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(.init(title: "Daily", people: ["Anna", "Marco"], speaker: "Anna"))
        await log.settle()
        #expect(setup.controller.state == .inMeeting)
        #expect(setup.controller.title == "Daily")
        #expect(setup.controller.people == ["Anna", "Marco"])
        #expect(setup.controller.peopleCount == 2)
        #expect(setup.controller.speaker == "Anna")
        #expect(log.items == [.meetingJoined(title: "Daily"), .participantsRead(["Anna", "Marco"]), .speakerChanged("Anna")])
    }

    @Test("a meeting without a readable title is still joined")
    func joinedWithoutTitle() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(.init())
        await log.settle()
        #expect(setup.controller.state == .inMeeting)
        #expect(setup.controller.title == nil)
        #expect(setup.controller.peopleCount == nil)
        #expect(log.items == [.meetingJoined(title: nil)])
    }

    @Test("people replace the known ones; a list not shown keeps them; the same list gives no news")
    func participants() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(.init(title: "Daily", people: ["Anna"]))
        setup.reader.show(.init(title: "Daily", people: ["Anna"]))
        setup.reader.show(.init(title: "Daily", people: []))
        #expect(setup.controller.people == ["Anna"])
        setup.reader.show(.init(title: "Daily", people: ["Anna", "Marco"]))
        await log.settle()
        #expect(setup.controller.people == ["Anna", "Marco"])
        #expect(log.items == [.meetingJoined(title: "Daily"), .participantsRead(["Anna"]), .participantsRead(["Anna", "Marco"])])
    }

    @Test("the speaker changes, also to nobody; no change gives no news")
    func speaker() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(.init(speaker: "Anna"))
        setup.reader.show(.init(speaker: "Anna"))
        setup.reader.show(.init(speaker: "Marco"))
        setup.reader.show(.init(speaker: nil))
        await log.settle()
        #expect(setup.controller.speaker == nil)
        #expect(
            log.items == [.meetingJoined(title: nil), .speakerChanged("Anna"), .speakerChanged("Marco"), .speakerChanged(nil)])
    }

    @Test("leaving the meeting forgets title, people and speaker")
    func left() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(.init(title: "Daily", people: ["Anna"], speaker: "Anna"))
        setup.reader.show(nil)
        await log.settle()
        #expect(setup.controller.state == .noMeeting)
        #expect(setup.controller.title == nil)
        #expect(setup.controller.people.isEmpty)
        #expect(setup.controller.speaker == nil)
        #expect(setup.controller.meeting == nil)
        #expect(log.items.last == .meetingEnded)
    }

    @Test("leaving without a meeting gives no news")
    func leftWithoutMeeting() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(nil)
        await log.settle()
        #expect(log.items.isEmpty)
    }

    @Test("ACCESS_LOST forgets the meeting and stops the reading")
    func accessLost() async {
        let setup = makeSetup()
        setup.reader.show(.init(title: "Daily", people: ["Anna"], speaker: "Anna"))
        setup.permission.set(granted: false)
        setup.access.openSettings()
        for _ in 0..<300 where setup.controller.state != .noMeeting { try? await Task.sleep(for: .milliseconds(10)) }
        #expect(setup.controller.state == .noMeeting)
        #expect(setup.controller.title == nil)
        #expect(setup.controller.people.isEmpty)
        #expect(!setup.reader.isReading)
    }

    @Test("a meeting shows again after it was left")
    func joinedAgain() async {
        let setup = makeSetup()
        let log = collect(setup.controller)
        setup.reader.show(.init(title: "Daily"))
        setup.reader.show(nil)
        setup.reader.show(.init(title: "Retro"))
        await log.settle()
        #expect(setup.controller.title == "Retro")
        #expect(log.items == [.meetingJoined(title: "Daily"), .meetingEnded, .meetingJoined(title: "Retro")])
    }
}

// MARK: - Timeline of speakers

@Suite("Timeline of speakers")
struct SpeakerTimelineTests {
    @Test("one span per change, each closed by the next, and the last by the end")
    func spans() {
        var timeline = SpeakerTimelineBuilder()
        timeline.begin(speaker: nil, at: 0)
        timeline.change(to: "Anna", at: 2)
        timeline.change(to: "Marco", at: 10)
        timeline.change(to: nil, at: 14.5)
        timeline.finish(at: 20)
        #expect(
            timeline.spans == [
                SpeakerSpan(start: 0, end: 2, name: nil), SpeakerSpan(start: 2, end: 10, name: "Anna"),
                SpeakerSpan(start: 10, end: 14.5, name: "Marco"), SpeakerSpan(start: 14.5, end: 20, name: nil),
            ])
    }

    @Test("spans under 300 ms are dropped, 300 ms exactly and longer ones are kept")
    func shortSpans() {
        var timeline = SpeakerTimelineBuilder()
        timeline.begin(speaker: "Anna", at: 0)
        timeline.change(to: "Marco", at: 5)
        timeline.change(to: "Anna", at: 5.299)
        timeline.change(to: "Marco", at: 5.599)
        timeline.change(to: "Anna", at: 5.8)
        timeline.finish(at: 9)
        #expect(
            timeline.spans == [
                SpeakerSpan(start: 0, end: 5, name: "Anna"), SpeakerSpan(start: 5.299, end: 5.599, name: "Anna"),
                SpeakerSpan(start: 5.8, end: 9, name: "Anna"),
            ])
    }

    @Test("a call that never saw Teams has no timeline")
    func neverSeen() {
        var timeline = SpeakerTimelineBuilder()
        timeline.finish(at: 60)
        #expect(timeline.spans.isEmpty)
    }

    @Test("without a speaker known at the start the timeline begins with the first change")
    func beginsWithFirstChange() {
        var timeline = SpeakerTimelineBuilder()
        timeline.change(to: "Anna", at: 4)
        timeline.finish(at: 9)
        #expect(timeline.spans == [SpeakerSpan(start: 4, end: 9, name: "Anna")])
    }

    @Test("nothing is added while paused: the span closes at the pause and the speaker marked then reopens on resume")
    func paused() {
        var timeline = SpeakerTimelineBuilder()
        timeline.begin(speaker: "Anna", at: 0)
        timeline.pause(at: 10)
        timeline.change(to: "Marco", at: 15)
        timeline.resume(at: 20)
        timeline.finish(at: 30)
        #expect(
            timeline.spans == [
                SpeakerSpan(start: 0, end: 10, name: "Anna"), SpeakerSpan(start: 20, end: 30, name: "Marco"),
            ])
    }

    @Test("the end of the meeting closes the span and no speaker is known until the next change")
    func meetingEnded() {
        var timeline = SpeakerTimelineBuilder()
        timeline.begin(speaker: "Anna", at: 0)
        timeline.meetingEnded(at: 8)
        timeline.pause(at: 9)
        timeline.resume(at: 12)
        timeline.finish(at: 20)
        #expect(timeline.spans == [SpeakerSpan(start: 0, end: 8, name: "Anna")])
    }
}

// MARK: - Meeting information of the call being recorded

@Suite("Teams in a recording", .serialized)
@MainActor
struct TeamsRecordingTests {
    @Test("the title of the meeting is taken by the call being recorded if it has none")
    func title() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        harness.lifecycle.teamsMeetingNews(.meetingJoined(title: "Daily"))
        #expect(call.meetingTitle == "Daily")
        harness.lifecycle.teamsMeetingNews(.meetingJoined(title: "Altro"))
        #expect(call.meetingTitle == "Daily")
    }

    @Test("a meeting joined without a readable title leaves the call without one")
    func untitled() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        harness.lifecycle.teamsMeetingNews(.meetingJoined(title: nil))
        #expect(call.meetingTitle == nil)
    }

    @Test("the names read are added to the names for the participants, without repeats")
    func names() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        harness.lifecycle.teamsMeetingNews(.participantsRead(["Anna", "Marco"]))
        harness.lifecycle.teamsMeetingNews(.participantsRead(["marco", "Giulia"]))
        #expect(call.participantNames == ["Anna", "Marco", "Giulia"])
    }

    @Test("the changes of speaker are added at the elapsed time, and the last span ends with the recording")
    func timeline() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        harness.advanceClock(by: 5)
        harness.lifecycle.teamsMeetingNews(.speakerChanged("Anna"))
        harness.advanceClock(by: 10)
        harness.lifecycle.teamsMeetingNews(.speakerChanged("Marco"))
        harness.advanceClock(by: 10)
        await harness.lifecycle.handle(.stopped)

        #expect(
            call.speakerTimeline == [
                SpeakerSpan(start: 5, end: 15, name: "Anna"), SpeakerSpan(start: 15, end: 25, name: "Marco"),
            ])
    }

    @Test("a change while the recording is paused is not added")
    func pausedChange() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        harness.advanceClock(by: 2)
        harness.lifecycle.teamsMeetingNews(.speakerChanged("Anna"))
        harness.advanceClock(by: 8)
        await harness.lifecycle.handle(.paused)
        harness.advanceClock(by: 5)
        harness.lifecycle.teamsMeetingNews(.speakerChanged("Marco"))
        harness.advanceClock(by: 5)
        await harness.lifecycle.handle(.resumed)
        harness.advanceClock(by: 10)
        await harness.lifecycle.handle(.stopped)

        #expect(
            call.speakerTimeline == [
                SpeakerSpan(start: 2, end: 10, name: "Anna"), SpeakerSpan(start: 20, end: 30, name: "Marco"),
            ])
    }

    @Test("a recording that starts in a meeting takes its title, people and speaker")
    func startedInAMeeting() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        harness.lifecycle.teamsMeeting = { .init(title: "Daily", people: ["Anna", "Marco"], speaker: "Anna") }
        await harness.lifecycle.handle(.started(callAppName: "Microsoft Teams"))
        let call = try #require(try harness.allCalls().first)

        #expect(call.meetingTitle == "Daily")
        #expect(call.participantNames == ["Anna", "Marco"])
        harness.advanceClock(by: 12)
        await harness.lifecycle.handle(.stopped)
        #expect(call.speakerTimeline == [SpeakerSpan(start: 0, end: 12, name: "Anna")])
    }

    @Test("what Teams says with no recording is kept nowhere")
    func noRecording() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)

        harness.lifecycle.teamsMeetingNews(.meetingJoined(title: "Daily"))
        harness.lifecycle.teamsMeetingNews(.participantsRead(["Anna"]))
        harness.lifecycle.teamsMeetingNews(.speakerChanged("Anna"))
        #expect(call.meetingTitle == nil)
        #expect(call.participantNames.isEmpty)
        #expect(call.speakerTimeline.isEmpty)
    }

    @Test("a call that never saw Teams has no meeting information")
    func neverSawTeams() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        await harness.lifecycle.handle(.started(callAppName: "Zoom"))
        harness.advanceClock(by: 30)
        await harness.lifecycle.handle(.stopped)
        let call = try #require(try harness.allCalls().first)

        #expect(call.meetingTitle == nil)
        #expect(call.participantNames.isEmpty)
        #expect(call.speakerTimeline.isEmpty)
    }

    @Test("the meeting information is stored with the call")
    func stored() async throws {
        let harness = try CallHarness()
        defer { harness.cleanUp() }
        let call = try harness.insertCall(.ready)
        call.meetingTitle = "Daily"
        call.participantNames = ["Anna"]
        call.speakerTimeline = [SpeakerSpan(start: 1, end: 3, name: nil)]
        try harness.context.save()

        let fetched = try #require(try harness.allCalls().first)
        #expect(fetched.meetingTitle == "Daily")
        #expect(fetched.participantNames == ["Anna"])
        #expect(fetched.speakerTimeline == [SpeakerSpan(start: 1, end: 3, name: nil)])
    }
}
