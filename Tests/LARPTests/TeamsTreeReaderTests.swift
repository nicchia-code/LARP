import Foundation
import Testing

@testable import LARP

/// A fake interface of Teams: a tree the test builds, a clock that moves with every request and a
/// count of the requests made.
private final class FakeTeamsTree: TeamsTreeSource, @unchecked Sendable {
    typealias Node = Int

    final class Clock: @unchecked Sendable {
        var seconds = 0.0
    }

    struct Element {
        var identifier: String?
        var title: String?
        var description: String?
        var value: String?
        var children: [Int] = []
    }

    let clock = Clock()
    /// What one request costs, in seconds of the fake clock.
    var secondsPerRequest = 0.001
    var windowList: [Int]? = []
    private(set) var elements: [Int: Element] = [:]
    private(set) var valueRequests = 0
    private(set) var windowRequests = 0
    private(set) var exposeRequests = 0
    /// What Teams does when it is asked to expose its interface.
    var onExpose: (() -> Void)?

    @discardableResult
    func add(
        _ identifier: String? = nil, title: String? = nil, description: String? = nil, value: String? = nil,
        children: [Int] = []
    ) -> Int {
        let id = elements.count + 1
        elements[id] = Element(
            identifier: identifier, title: title, description: description, value: value, children: children)
        return id
    }

    func setChildren(of id: Int, to children: [Int]) {
        elements[id]?.children = children
    }

    /// An element with `count` plain children and nothing else.
    func wide(_ count: Int, identifier: String? = "x", title: String? = nil) -> Int {
        add(title: title, children: (0..<count).map { _ in add(identifier) })
    }

    func windows() -> [Int]? {
        windowRequests += 1
        return windowList
    }

    func values(of node: Int) -> TeamsNodeValues<Int> {
        valueRequests += 1
        clock.seconds += secondsPerRequest
        let element = elements[node]!
        return TeamsNodeValues(
            identifier: element.identifier, title: element.title, description: element.description,
            value: element.value, children: element.children)
    }

    func exposeInterface() {
        exposeRequests += 1
        onExpose?()
    }

    func makeReader(maxElements: Int = 5_000, maxSeconds: TimeInterval = 1) -> TeamsTreeReader<FakeTeamsTree> {
        let clock = clock
        return TeamsTreeReader(
            source: self, maxElements: maxElements, maxSeconds: maxSeconds, now: { clock.seconds })
    }
}

private func notCancelled() -> Bool { false }

private extension TeamsTreeResult {
    var meeting: TeamsReadout.Meeting? {
        if case .meeting(let meeting) = outcome { meeting } else { nil }
    }
}

@Suite("Teams tree reading")
struct TeamsTreeReaderTests {
    // MARK: Recognition

    @Test("the meeting is the window that holds the marker; its title, people and speaker are read")
    func meeting() {
        let tree = FakeTeamsTree()
        let speaking = tree.add("active-speaker")
        let anna = tree.add("roster-participant-1", title: "Anna Rossi", children: [speaking])
        let guest = tree.add("roster-participant-2", title: "Marco (Guest)")
        let user = tree.add("roster-participant-3", title: "Luca (Tu)")
        let list = tree.add(children: [anna, guest, user])
        let marker = tree.add("call-duration-custom", title: "12:03")
        let window = tree.add(title: "Daily | Microsoft Teams", children: [marker, list])
        tree.windowList = [window]

        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(result.meeting == .init(title: "Daily", people: ["Anna Rossi", "Marco"], speaker: "Anna Rossi"))
        #expect(result.markerFound)
        #expect(result.participantElements == 3)
        #expect(result.speakerMarks == 1)
        #expect(result.limit == nil)
        #expect(result.elements == 7)
        #expect(result.windows == 1)
        // One request for each element, and one for the windows: nothing else is asked.
        #expect(tree.valueRequests == 7)
        #expect(tree.windowRequests == 1)
    }

    @Test("titles and texts never say a meeting is on: without the marker there is none")
    func noMarker() {
        let tree = FakeTeamsTree()
        let window = tree.add(
            title: "Riunione | Microsoft Teams",
            children: [tree.add("other", title: "call-duration-custom", description: "In call")])
        tree.windowList = [window]

        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(result.outcome == .noMeeting)
        #expect(!result.markerFound)
    }

    @Test("the title of a section of Teams counts as no title")
    func sectionTitle() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.add(title: "Calendar | Microsoft Teams", children: [tree.add("call-duration-custom")])]
        #expect(tree.makeReader().read(isCancelled: notCancelled).meeting == .init(title: nil))
    }

    @Test("a participant without a name of its own takes the first text below it, in the same walk")
    func participantName() {
        let tree = FakeTeamsTree()
        let empty = tree.add(title: "   ")
        let text = tree.add(value: "Giulia")
        let anna = tree.add("roster-participant-1", children: [empty, text])
        let window = tree.add(children: [tree.add("call-duration-custom"), anna])
        tree.windowList = [window]

        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(result.meeting?.people == ["Giulia"])
        #expect(tree.valueRequests == 5)
    }

    @Test("the speaker is the label of the nearest labelled element above the mark")
    func speaker() {
        let tree = FakeTeamsTree()
        let mark = tree.add("active-speaker")
        let tile = tree.add(description: "Anna Rossi", children: [tree.add(children: [mark])])
        let other = tree.add(description: "Marco")
        let window = tree.add(children: [tree.add("call-duration-custom"), tile, other])
        tree.windowList = [window]

        #expect(tree.makeReader().read(isCancelled: notCancelled).meeting?.speaker == "Anna Rossi")
    }

    // MARK: Limits

    @Test("a reading visits at most 5,000 elements")
    func elementLimit() {
        let tree = FakeTeamsTree()
        tree.secondsPerRequest = 0
        tree.windowList = [tree.wide(6_000)]
        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(result.elements == 5_000)
        #expect(result.limit == .elements)
        #expect(tree.valueRequests == 5_000)
    }

    @Test("a reading lasts at most one second")
    func timeLimit() {
        let tree = FakeTeamsTree()
        tree.secondsPerRequest = 0.3
        tree.windowList = [tree.wide(50)]
        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(result.limit == .time)
        #expect(result.elements == 4)
    }

    @Test("the limits count across all the windows")
    func limitsAcrossWindows() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(5), tree.wide(5), tree.wide(5)]
        let result = tree.makeReader(maxElements: 8).read(isCancelled: notCancelled)
        #expect(result.elements == 8)
        #expect(result.windows == 2)
        #expect(result.limit == .elements)
    }

    @Test("a reading that stops at a limit with the marker found gives what it found")
    func limitWithMarker() {
        let tree = FakeTeamsTree()
        let window = tree.add(title: "Daily | Microsoft Teams", children: [tree.add("call-duration-custom")] + (0..<50).map { _ in tree.add("x") })
        tree.windowList = [window]
        let result = tree.makeReader(maxElements: 10).read(isCancelled: notCancelled)
        #expect(result.limit == .elements)
        #expect(result.meeting?.title == "Daily")
    }

    @Test("a reading that stops at a limit without the marker leaves the meeting as it was")
    func limitWithoutMarker() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(100)]
        let result = tree.makeReader(maxElements: 10).read(isCancelled: notCancelled)
        #expect(result.outcome == .inconclusive)
        #expect(result.readout?.leavesMeetingAsItWas == true)

        // The same Teams read whole says there is no meeting.
        #expect(tree.makeReader().read(isCancelled: notCancelled).outcome == .noMeeting)
    }

    @Test("the pause doubles after a reading that reached a limit, up to 30 seconds, and returns to 2")
    func pause() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(100)]
        let reader = tree.makeReader(maxElements: 10)
        var pauses: [TimeInterval] = []
        for _ in 0..<7 { pauses.append(reader.read(isCancelled: notCancelled).pause) }
        #expect(pauses == [4, 8, 16, 30, 30, 30, 30])

        tree.windowList = [tree.wide(3)]
        #expect(reader.read(isCancelled: notCancelled).pause == 2)
        tree.windowList = [tree.wide(100)]
        #expect(reader.read(isCancelled: notCancelled).pause == 4)
    }

    @Test("a reading within the limits has the usual pause")
    func usualPause() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(5)]
        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(result.pause == 2)
        #expect(result.limit == nil)
    }

    // MARK: The window of the meeting

    private func meetingTree() -> (tree: FakeTeamsTree, main: Int, meeting: Int) {
        let tree = FakeTeamsTree()
        let main = tree.wide(20)
        let meeting = tree.add(title: "Daily | Microsoft Teams", children: [tree.add("call-duration-custom"), tree.add("x")])
        tree.windowList = [main, meeting]
        return (tree, main, meeting)
    }

    @Test("once the window of the meeting is found, only that window is visited while Teams has it")
    func rememberedWindow() {
        let (tree, _, meeting) = meetingTree()
        let reader = tree.makeReader()
        let first = reader.read(isCancelled: notCancelled)
        #expect(first.windows == 2)
        #expect(first.elements == 21 + 3)

        let again = reader.read(isCancelled: notCancelled)
        #expect(again.windows == 1)
        #expect(again.elements == 3)
        #expect(again.meeting?.title == "Daily")

        // A window of the meeting that goes on after other windows come and go.
        tree.windowList = [tree.wide(3), meeting]
        #expect(reader.read(isCancelled: notCancelled).windows == 1)
    }

    @Test("when the window of the meeting is gone every window is visited again, and the meeting is left")
    func windowGone() {
        let (tree, main, _) = meetingTree()
        let reader = tree.makeReader()
        _ = reader.read(isCancelled: notCancelled)

        tree.windowList = [main]
        let result = reader.read(isCancelled: notCancelled)
        #expect(result.windows == 1)
        #expect(result.elements == 21)
        #expect(result.outcome == .noMeeting)
    }

    @Test("the window gone leaves the meeting even when the walk of the others reaches a limit")
    func windowGoneAtALimit() {
        let (tree, main, _) = meetingTree()
        let reader = tree.makeReader(maxElements: 10)
        tree.windowList = [tree.add(children: [tree.add("call-duration-custom")])]
        _ = reader.read(isCancelled: notCancelled)
        tree.windowList = [main]
        let result = reader.read(isCancelled: notCancelled)
        #expect(result.limit == .elements)
        #expect(result.outcome == .noMeeting)
    }

    @Test("a whole reading of the window of the meeting without the marker leaves the meeting, and all windows are read next")
    func markerGone() {
        let (tree, _, meeting) = meetingTree()
        let reader = tree.makeReader()
        _ = reader.read(isCancelled: notCancelled)

        tree.setChildren(of: meeting, to: [tree.add("x")])
        let left = reader.read(isCancelled: notCancelled)
        #expect(left.windows == 1)
        #expect(left.outcome == .noMeeting)

        #expect(reader.read(isCancelled: notCancelled).windows == 2)
    }

    @Test("a limit inside the window of the meeting, without the marker, leaves the meeting as it was")
    func limitInRememberedWindow() {
        let tree = FakeTeamsTree()
        let window = tree.add(children: [tree.add("call-duration-custom")] + (0..<50).map { _ in tree.add("x") })
        tree.windowList = [window]
        let reader = tree.makeReader(maxElements: 20)
        #expect(reader.read(isCancelled: notCancelled).meeting != nil)

        // The marker went; the walk of the window stops before it could tell.
        tree.setChildren(of: window, to: (0..<50).map { _ in tree.add("x") })
        let result = reader.read(isCancelled: notCancelled)
        #expect(result.windows == 1)
        #expect(result.limit == .elements)
        #expect(result.outcome == .inconclusive)
    }

    @Test("a Teams that does not answer is not a meeting left, and counts as no reading")
    func noAnswer() {
        let (tree, _, _) = meetingTree()
        let reader = tree.makeReader()
        _ = reader.read(isCancelled: notCancelled)
        let requests = tree.valueRequests

        tree.windowList = nil
        for _ in 0..<5 {
            let result = reader.read(isCancelled: notCancelled)
            #expect(result.outcome == .inconclusive)
            #expect(!result.gaveUp)
        }
        #expect(tree.valueRequests == requests)
        #expect(tree.exposeRequests == 0)
    }

    // MARK: Exposing the interface and giving up

    @Test("a reading with no web identifier asks Teams to expose its interface and reads again, once")
    func expose() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.add(title: "Teams", children: [tree.add(title: "native")])]
        tree.onExpose = {
            tree.windowList = [tree.add(title: "Daily | Microsoft Teams", children: [tree.add("call-duration-custom")])]
        }
        let reader = tree.makeReader()

        let first = reader.read(isCancelled: notCancelled)
        #expect(first.exposeRequested)
        #expect(tree.exposeRequests == 1)
        #expect(first.meeting?.title == "Daily")
        #expect(first.elements == 2 + 2)
        #expect(!first.gaveUp)

        tree.windowList = [tree.add(title: "Teams")]
        for _ in 0..<5 {
            let result = reader.read(isCancelled: notCancelled)
            #expect(!result.exposeRequested)
        }
        #expect(tree.exposeRequests == 1)
    }

    @Test("a reading with identifiers does not ask Teams anything")
    func noExposeWithIdentifiers() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(3)]
        let result = tree.makeReader().read(isCancelled: notCancelled)
        #expect(!result.exposeRequested)
        #expect(tree.exposeRequests == 0)
    }

    @Test("after 3 readings in a row without identifiers since the request, that Teams is not read any more")
    func givesUp() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.add(title: "Teams")]
        let reader = tree.makeReader()
        #expect(reader.read(isCancelled: notCancelled).exposeRequested)

        let results = (0..<3).map { _ in reader.read(isCancelled: notCancelled) }
        #expect(results.map(\.gaveUp) == [false, false, true])
        #expect(reader.hasGivenUp)

        let requests = (tree.valueRequests, tree.windowRequests)
        let after = reader.read(isCancelled: notCancelled)
        #expect(after.gaveUp)
        #expect(after.outcome == .inconclusive)
        #expect(tree.valueRequests == requests.0 && tree.windowRequests == requests.1)
        #expect(tree.exposeRequests == 1)
    }

    @Test("a reading with identifiers brings the count of readings without them back to zero")
    func identifiersResetTheCount() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.add(title: "Teams")]
        let reader = tree.makeReader()
        _ = reader.read(isCancelled: notCancelled)
        _ = reader.read(isCancelled: notCancelled)
        _ = reader.read(isCancelled: notCancelled)
        tree.windowList = [tree.wide(2)]
        _ = reader.read(isCancelled: notCancelled)

        tree.windowList = [tree.add(title: "Teams")]
        #expect(!reader.read(isCancelled: notCancelled).gaveUp)
        #expect(!reader.read(isCancelled: notCancelled).gaveUp)
        #expect(reader.read(isCancelled: notCancelled).gaveUp)
    }

    @Test("a new reader, for a new launch of Teams, asks again")
    func newLaunch() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.add(title: "Teams")]
        _ = tree.makeReader().read(isCancelled: notCancelled)
        _ = tree.makeReader().read(isCancelled: notCancelled)
        #expect(tree.exposeRequests == 2)
    }

    // MARK: Cancelling

    @Test("a walk that is cancelled stops between two elements and gives nothing back")
    func cancelled() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(100)]
        let reader = tree.makeReader()
        var checks = 0
        let result = reader.read(isCancelled: {
            checks += 1
            return checks > 5
        })
        #expect(result.outcome == .cancelled)
        #expect(result.readout == nil)
        #expect(tree.valueRequests == 5)

        // Nothing of the cancelled walk is remembered: the pace is the usual one.
        #expect(reader.read(isCancelled: notCancelled).pause == 2)
    }

    @Test("a walk cancelled after Teams was asked to expose its interface does not ask again")
    func cancelledAfterExpose() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.add(title: "Teams", children: (0..<5).map { _ in tree.add(title: "native") })]
        let reader = tree.makeReader()
        var asked = false
        tree.onExpose = { asked = true }
        var checks = 0
        let result = reader.read(isCancelled: {
            checks += 1
            return asked && checks > 3
        })
        #expect(result.outcome == .cancelled)
        let next = reader.read(isCancelled: notCancelled)
        #expect(!next.exposeRequested)
        #expect(tree.exposeRequests == 1)
    }

    // MARK: Diagnostics

    @Test("the line of a reading holds numbers and reasons, never a text read from Teams")
    func logLine() {
        let tree = FakeTeamsTree()
        let window = tree.add(
            title: "Segretissimo | Microsoft Teams",
            children: [tree.add("call-duration-custom"), tree.add("roster-participant-1", title: "Anna Rossi")])
        tree.windowList = [window]
        var result = tree.makeReader().read(isCancelled: notCancelled)
        result.duration = 0.0421
        let line = TeamsLog.line(for: result)
        #expect(line.contains("42 ms"))
        #expect(line.contains("3 elements in 1 windows"))
        #expect(line.contains("within the limits"))
        #expect(line.contains("expose request not made"))
        #expect(line.contains("meeting marker found"))
        #expect(line.contains("1 participant elements"))
        #expect(line.contains("0 speaker marks"))
        #expect(line.contains("next reading after 2 s"))
        #expect(!line.contains("Segretissimo"))
        #expect(!line.contains("Anna"))
    }

    @Test("the line of a reading that reached a limit says which")
    func logLineLimit() {
        let tree = FakeTeamsTree()
        tree.windowList = [tree.wide(50)]
        let result = tree.makeReader(maxElements: 5).read(isCancelled: notCancelled)
        let line = TeamsLog.line(for: result)
        #expect(line.contains("reached the limit of elements"))
        #expect(line.contains("meeting marker not found"))
        #expect(line.contains("next reading after 4 s"))
    }
}

// MARK: - Pacing

@Suite("Teams reading pace")
struct TeamsReadPacingTests {
    private let base = ContinuousClock.now

    private func at(_ seconds: Double) -> ContinuousClock.Instant { base + .seconds(seconds) }

    @Test("the first reading starts at once")
    func first() {
        let pacing = TeamsReadPacing()
        #expect(pacing.nextStart(now: at(5)) == at(5))
    }

    @Test("the next reading comes 2 seconds after the end of the previous one")
    func baseInterval() {
        var pacing = TeamsReadPacing()
        pacing.readStarted()
        pacing.readFinished(at: at(10), pause: 2)
        #expect(pacing.nextStart(now: at(10)) == at(12))
    }

    @Test("a longer pause after a reading that reached a limit")
    func longerPause() {
        var pacing = TeamsReadPacing()
        pacing.readFinished(at: at(10), pause: 8)
        #expect(pacing.nextStart(now: at(10)) == at(18))
    }

    @Test("an announcement makes the reading come sooner, but not within a second of the previous one")
    func announcement() {
        var pacing = TeamsReadPacing()
        pacing.readFinished(at: at(10), pause: 2)
        pacing.announced(at: at(10.2))
        #expect(pacing.nextStart(now: at(10.2)) == at(11))
        pacing = TeamsReadPacing()
        pacing.readFinished(at: at(10), pause: 2)
        pacing.announced(at: at(10.6))
        #expect(pacing.nextStart(now: at(10.6)) == at(11))
        pacing = TeamsReadPacing()
        pacing.readFinished(at: at(10), pause: 2)
        pacing.announced(at: at(11.5))
        #expect(pacing.nextStart(now: at(11.5)) == at(11.5))
    }

    @Test("an announcement while a reading runs is read one second after it ends")
    func announcementWhileReading() {
        var pacing = TeamsReadPacing()
        pacing.readStarted()
        pacing.announced(at: at(10.5))
        pacing.readFinished(at: at(11), pause: 2)
        #expect(pacing.nextStart(now: at(11)) == at(12))
    }

    @Test("an announcement that came before a reading started is covered by it")
    func announcementCovered() {
        var pacing = TeamsReadPacing()
        pacing.announced(at: at(1))
        pacing.readStarted()
        pacing.readFinished(at: at(5), pause: 2)
        #expect(pacing.nextStart(now: at(5)) == at(7))
    }

    @Test("never within 3 seconds after Teams opened a window, whatever the pause")
    func quietAfterWindow() {
        var pacing = TeamsReadPacing()
        pacing.readFinished(at: at(10), pause: 2)
        pacing.windowOpened(at: at(11))
        // The reading due at 12 and the announcement both wait for 14.
        #expect(pacing.nextStart(now: at(11)) == at(14))

        pacing.readStarted()
        pacing.readFinished(at: at(13), pause: 2)
        #expect(pacing.nextStart(now: at(13)) == at(15))

        var fresh = TeamsReadPacing()
        fresh.windowOpened(at: at(20))
        #expect(fresh.nextStart(now: at(20)) == at(23))
    }

    @Test("a window opened again moves the quiet time")
    func quietMoves() {
        var pacing = TeamsReadPacing()
        pacing.readFinished(at: at(10), pause: 2)
        pacing.windowOpened(at: at(11))
        pacing.windowOpened(at: at(13))
        #expect(pacing.nextStart(now: at(13)) == at(16))
    }
}
