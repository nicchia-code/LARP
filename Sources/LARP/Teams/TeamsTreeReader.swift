import Foundation

/// What LARP knows of the interface of the new Microsoft Teams. Web elements are matched by their
/// `AXDOMIdentifier`, never by their titles or descriptions, which change with the language.
///
/// None of the identifiers is verified on a real Teams (`scripts/teams-ax-dump.swift` shows what
/// Teams really exposes): when the identifiers of the participant list and of the mark on whoever
/// speaks are not there, the people and the speaker are simply not read.
enum TeamsInterface {
    /// The main process of the new Teams; the classic Teams (`com.microsoft.teams`) is not read.
    static let bundleIdentifier = "com.microsoft.teams2"
    /// The element that is in a window while Teams is in a meeting.
    static let meetingMarker = "call-duration-custom"
    /// An item of the list of participants.
    static let participantItemPrefix = "roster-participant"
    /// The mark Teams puts on whoever speaks.
    static let speakingMarkerPrefix = "active-speaker"
}

/// The limits and the pace of the readings of Teams.
enum TeamsReadingLimits {
    /// How many elements one reading visits at most, across all windows.
    static let elements = 5_000
    /// How long one reading lasts at most, in seconds.
    static let seconds: TimeInterval = 1
    /// The pause between readings while Teams answers within the limits, in seconds.
    static let basePause: TimeInterval = 2
    /// The longest pause after readings that reached a limit, in seconds.
    static let longestPause: TimeInterval = 30
    /// A reading that finds no web identifier at all, this many times in a row after the request
    /// to expose the interface, gives that launch of Teams up.
    static let readingsWithoutIdentifiersBeforeGivingUp = 3
}

/// What one reading of the interface of Teams found, and how it went.
struct TeamsTreeResult: Sendable, Equatable {
    enum Outcome: Sendable, Equatable {
        /// A window holds the marker of the meeting.
        case meeting(TeamsReadout.Meeting)
        /// The meeting is not there: no marker in a whole reading, or its window is gone.
        case noMeeting
        /// The reading stopped at a limit or Teams did not answer before the marker was found: the
        /// meeting stays as it was.
        case inconclusive
        /// The reading was cancelled; its result is not wanted.
        case cancelled
    }

    /// The limit a reading stopped at.
    enum Limit: String, Sendable {
        case elements
        case time
    }

    var outcome: Outcome = .inconclusive
    var elements = 0
    var windows = 0
    var limit: Limit?
    var exposeRequested = false
    var markerFound = false
    var participantElements = 0
    var speakerMarks = 0
    var duration: TimeInterval = 0
    /// The pause before the next reading, in seconds.
    var pause: TimeInterval = TeamsReadingLimits.basePause
    /// This launch of Teams is not read any more.
    var gaveUp = false

    /// What the reading tells the `teams-meeting` machine.
    var readout: TeamsReadout? {
        switch outcome {
        case .meeting(let meeting): TeamsReadout(meeting: meeting)
        case .noMeeting: .noMeeting
        case .inconclusive: .leavesMeetingAsItWas
        case .cancelled: nil
        }
    }
}

/// The readings of one launch of Teams: walks its interface for the element of the meeting and
/// for what it shows of it, within the limits, and keeps what lasts from one reading to the next
/// (the window of the meeting, the single request to expose the interface, the readings without
/// identifiers, the pace). Only one reading runs at a time, so it is not thread-safe by itself.
///
/// Every request blocks while Teams answers: it runs off the main actor, and checks between one
/// element and the next whether it has been cancelled.
final class TeamsTreeReader<Source: TeamsTreeSource>: @unchecked Sendable {
    private let source: Source
    private let maxElements: Int
    private let maxSeconds: TimeInterval
    private let now: @Sendable () -> TimeInterval

    private var meetingWindow: Source.Node?
    private var exposeRequested = false
    private var readingsWithoutIdentifiers = 0
    private var pause = TeamsReadingLimits.basePause
    private(set) var hasGivenUp = false

    init(
        source: Source,
        maxElements: Int = TeamsReadingLimits.elements,
        maxSeconds: TimeInterval = TeamsReadingLimits.seconds,
        now: @escaping @Sendable () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }
    ) {
        self.source = source
        self.maxElements = maxElements
        self.maxSeconds = maxSeconds
        self.now = now
    }

    /// One reading. `isCancelled` is asked between one element and the next.
    func read(isCancelled: () -> Bool) -> TeamsTreeResult {
        guard !hasGivenUp else { return TeamsTreeResult(outcome: .inconclusive, pause: pause, gaveUp: true) }
        let start = now()
        var walk = Walk(deadline: start + maxSeconds, elementsLeft: maxElements)
        var result = TeamsTreeResult()

        var found = scan(&walk, isCancelled: isCancelled)
        if walk.cancelled { return cancelled(result, walk, start) }
        if found.answered, !found.sawIdentifier {
            if !exposeRequested {
                // No web element at all: Teams is asked once to expose its interface and read again.
                exposeRequested = true
                readingsWithoutIdentifiers = 0
                result.exposeRequested = true
                source.exposeInterface()
                let again = scan(&walk, isCancelled: isCancelled)
                if walk.cancelled { return cancelled(result, walk, start) }
                found = again.merged(after: found)
            } else {
                readingsWithoutIdentifiers += 1
                if readingsWithoutIdentifiers >= TeamsReadingLimits.readingsWithoutIdentifiersBeforeGivingUp {
                    hasGivenUp = true
                    result.gaveUp = true
                }
            }
        } else if found.sawIdentifier {
            readingsWithoutIdentifiers = 0
        }

        result.elements = walk.elements
        result.windows = walk.windows
        result.limit = walk.limit
        result.markerFound = found.meeting != nil
        result.participantElements = walk.participantElements
        result.speakerMarks = walk.speakerMarks
        if let meeting = found.meeting {
            result.outcome = .meeting(meeting)
        } else if !found.answered {
            result.outcome = .inconclusive
        } else if walk.limit == nil || found.rememberedWindowGone {
            result.outcome = .noMeeting
        } else {
            result.outcome = .inconclusive
        }
        pause =
            walk.limit == nil
            ? TeamsReadingLimits.basePause : min(TeamsReadingLimits.longestPause, pause * 2)
        result.pause = pause
        result.duration = now() - start
        return result
    }

    // MARK: Walk

    private struct Walk {
        let deadline: TimeInterval
        var elementsLeft: Int
        var elements = 0
        var windows = 0
        var participantElements = 0
        var speakerMarks = 0
        var limit: TeamsTreeResult.Limit?
        var cancelled = false
    }

    /// What one pass over the windows of Teams found.
    private struct Found {
        /// Teams answered with its windows.
        var answered = true
        var sawIdentifier = false
        var meeting: TeamsReadout.Meeting?
        /// The window of the meeting remembered by an earlier reading is not among the windows.
        var rememberedWindowGone = false

        /// This pass after an earlier one in the same reading.
        func merged(after earlier: Found) -> Found {
            var merged = self
            merged.sawIdentifier = sawIdentifier || earlier.sawIdentifier
            merged.rememberedWindowGone = rememberedWindowGone || earlier.rememberedWindowGone
            return merged
        }
    }

    private struct Entry {
        let node: Source.Node
        /// The label of the nearest element above that has one: the person a speaking mark is on.
        let itemName: String?
        /// The participant whose name is still to be found in the elements below.
        let pendingPerson: Int?
    }

    /// Visits the window of the meeting alone while Teams still has it, every window otherwise.
    private func scan(_ walk: inout Walk, isCancelled: () -> Bool) -> Found {
        var found = Found()
        guard let windows = source.windows() else {
            found.answered = false
            return found
        }
        var toVisit = windows
        if let remembered = meetingWindow {
            if windows.contains(remembered) {
                toVisit = [remembered]
            } else {
                meetingWindow = nil
                found.rememberedWindowGone = true
            }
        }
        for window in toVisit {
            let window = visit(window, &walk, isCancelled: isCancelled)
            found.sawIdentifier = found.sawIdentifier || window.sawIdentifier
            if walk.cancelled { return found }
            if window.hasMarker {
                meetingWindow = window.node
                found.meeting = TeamsReadout.Meeting(
                    title: TeamsText.meetingTitle(fromWindowTitle: window.title),
                    people: TeamsText.people(from: window.people),
                    speaker: TeamsText.personName(from: window.speaker))
                return found
            }
            if walk.limit != nil { return found }
        }
        // A whole pass without the marker: the window remembered is not the meeting any more.
        meetingWindow = nil
        return found
    }

    private struct WindowFindings {
        let node: Source.Node
        var title: String?
        var sawIdentifier = false
        var hasMarker = false
        /// One slot per participant element, filled when a name is found; empty while it is not.
        var people: [String] = []
        var speaker: String?
    }

    /// Visits `window` and its descendants, one request each, while the limits last.
    private func visit(_ window: Source.Node, _ walk: inout Walk, isCancelled: () -> Bool) -> WindowFindings {
        var findings = WindowFindings(node: window)
        walk.windows += 1
        var stack = [Entry(node: window, itemName: nil, pendingPerson: nil)]
        var isWindow = true
        while let entry = stack.popLast() {
            if isCancelled() {
                walk.cancelled = true
                return findings
            }
            if walk.elementsLeft <= 0 {
                walk.limit = .elements
                return findings
            }
            if now() >= walk.deadline {
                walk.limit = .time
                return findings
            }
            walk.elementsLeft -= 1
            walk.elements += 1
            let values = source.values(of: entry.node)
            if isWindow {
                findings.title = values.title
                isWindow = false
            }
            let label = Self.nonEmpty(values.title) ?? Self.nonEmpty(values.description)
            var itemName = entry.itemName
            var pendingPerson = entry.pendingPerson
            if let pending = pendingPerson, let text = label ?? Self.nonEmpty(values.value) {
                findings.people[pending] = text
                pendingPerson = nil
            }
            if let identifier = values.identifier, !identifier.isEmpty {
                findings.sawIdentifier = true
                if identifier == TeamsInterface.meetingMarker {
                    findings.hasMarker = true
                }
                if identifier.hasPrefix(TeamsInterface.participantItemPrefix) {
                    walk.participantElements += 1
                    findings.people.append(label ?? "")
                    pendingPerson = label == nil ? findings.people.count - 1 : nil
                    itemName = label ?? itemName
                }
                if identifier.hasPrefix(TeamsInterface.speakingMarkerPrefix) {
                    walk.speakerMarks += 1
                    if findings.speaker == nil { findings.speaker = itemName ?? label }
                }
            } else if let label {
                itemName = label
            }
            for child in values.children.reversed() {
                stack.append(Entry(node: child, itemName: itemName, pendingPerson: pendingPerson))
            }
        }
        return findings
    }

    private func cancelled(_ result: TeamsTreeResult, _ walk: Walk, _ start: TimeInterval) -> TeamsTreeResult {
        var result = result
        result.outcome = .cancelled
        result.elements = walk.elements
        result.windows = walk.windows
        result.duration = now() - start
        return result
    }

    private static func nonEmpty(_ text: String?) -> String? {
        guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return text
    }
}
