import Foundation
import Observation

/// What the `teams-meeting` machine tells the call being recorded, in the order it happened.
enum TeamsMeetingNews: Sendable, Equatable {
    /// `teams.MEETING_JOINED`, with the title of the meeting when it could be read.
    case meetingJoined(title: String?)
    /// `teams.PARTICIPANTS_READ`: the people in the meeting now.
    case participantsRead([String])
    /// `teams.SPEAKER_CHANGED`: the new speaker, or nobody.
    case speakerChanged(String?)
    /// `teams.MEETING_LEFT` or `teams-access.ACCESS_LOST`: nobody is marked any more.
    case meetingEnded
}

/// The `teams-meeting` machine: the meeting Microsoft Teams shows at this moment, as LARP reads it
/// while Teams access is allowed: its title, the people in it and who is speaking.
///
/// The readings come from a `TeamsReading`; the changes between one reading and the next are the
/// Events of the actor `teams` (`teams.MEETING_JOINED`, `teams.PARTICIPANTS_READ`,
/// `teams.SPEAKER_CHANGED`, `teams.MEETING_LEFT`), which move the machine and, while a recording is
/// going on, are given to the call being recorded through `news`. Every Event may never come:
/// nothing depends on Teams being readable. What is read stays on the Mac and is never logged.
@MainActor
@Observable
final class TeamsMeetingController {
    /// The controller shared by the app: the popover, the proposal, the live window and the call
    /// being recorded read the same instance.
    static let shared = TeamsMeetingController()

    private(set) var state: TeamsMeetingState = .noMeeting
    /// The title of the meeting; `nil` when it could not be read or there is no meeting.
    private(set) var title: String?
    /// The people known in the meeting, as read.
    private(set) var people: [String] = []
    /// Who Teams marks as speaking now.
    private(set) var speaker: String?

    /// The meeting as it is now; `nil` when there is none.
    var meeting: TeamsReadout.Meeting? {
        state == .inMeeting ? TeamsReadout.Meeting(title: title, people: people, speaker: speaker) : nil
    }

    /// The number of people in the meeting when known.
    var peopleCount: Int? {
        state == .inMeeting && !people.isEmpty ? people.count : nil
    }

    @ObservationIgnored private let access: TeamsAccessController
    @ObservationIgnored private let reader: any TeamsReading
    @ObservationIgnored private let broadcaster = EventBroadcaster<TeamsMeetingNews>()
    @ObservationIgnored private var isReading = false
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(
        access: TeamsAccessController = .shared,
        reader: any TeamsReading = AccessibilityTeamsReader()
    ) {
        self.access = access
        self.reader = reader
    }

    /// Follows Teams access: Teams is read while it is allowed. Call once, at launch, after the
    /// access machine has seen `macos.APP_LAUNCHED`.
    func start() {
        guard tasks.isEmpty else { return }
        let allowedChanges = access.allowedChanges
        let accessLost = access.accessLostEvents
        tasks = [
            Task { [weak self] in
                for await allowed in allowedChanges {
                    self?.accessChanged(allowed: allowed)
                }
            },
            Task { [weak self] in
                for await _ in accessLost {
                    self?.accessLost()
                }
            },
        ]
        accessChanged(allowed: access.isAllowed)
    }

    /// A new stream that yields what happens in the meeting, from now on.
    var news: AsyncStream<TeamsMeetingNews> {
        broadcaster.stream()
    }

    // MARK: Events

    /// `teams-access.ACCESS_LOST`: Teams is not read any more; title, people and speaker are
    /// forgotten, what was kept with a call stays.
    func accessLost() {
        stopReading()
        if let target = TeamsMeetingStateMachine.target(from: state, on: .accessLost) {
            leave(to: target)
        }
    }

    /// Teams access became allowed or not: the reading starts or stops.
    func accessChanged(allowed: Bool) {
        if allowed {
            guard !isReading else { return }
            isReading = true
            reader.start { [weak self] readout in self?.received(readout) }
        } else {
            stopReading()
        }
    }

    /// One reading of Teams: the changes since the previous one are the Events of the actor
    /// `teams`. Ignored while Teams access is not allowed.
    func received(_ readout: TeamsReadout) {
        guard access.isAllowed, isReading else { return }
        guard let meeting = readout.meeting else {
            // `teams.MEETING_LEFT`
            if let target = TeamsMeetingStateMachine.target(from: state, on: .meetingLeft) {
                leave(to: target)
            }
            return
        }
        if state == .noMeeting {
            // `teams.MEETING_JOINED`
            guard let target = TeamsMeetingStateMachine.target(from: state, on: .meetingJoined(accessAllowed: true))
            else { return }
            state = target
            title = meeting.title
            people = []
            speaker = nil
            broadcaster.emit(.meetingJoined(title: meeting.title))
        }
        // `teams.PARTICIPANTS_READ`: the list of participants is shown and has changed.
        if !meeting.people.isEmpty, meeting.people != people,
            let target = TeamsMeetingStateMachine.target(from: state, on: .participantsRead)
        {
            state = target
            people = meeting.people
            broadcaster.emit(.participantsRead(meeting.people))
        }
        // `teams.SPEAKER_CHANGED`
        if meeting.speaker != speaker,
            let target = TeamsMeetingStateMachine.target(from: state, on: .speakerChanged)
        {
            state = target
            speaker = meeting.speaker
            broadcaster.emit(.speakerChanged(meeting.speaker))
        }
    }

    // MARK: Private

    private func stopReading() {
        guard isReading else { return }
        isReading = false
        reader.stop()
    }

    /// `teams.MEETING_LEFT` and `teams-access.ACCESS_LOST`: title, people and speaker are
    /// forgotten.
    private func leave(to target: TeamsMeetingState) {
        state = target
        title = nil
        people = []
        speaker = nil
        broadcaster.emit(.meetingEnded)
    }
}
