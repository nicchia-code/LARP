import Foundation
import Observation

/// What the `teams-meeting` machine tells the call being recorded, in the order it happened.
enum TeamsMeetingNews: Sendable, Equatable {
    /// `teams.MEETING_JOINED`, with the title of the meeting when it could be read.
    case meetingJoined(title: String?)
    /// `teams.PARTICIPANTS_READ`: the people in the meeting now.
    case participantsRead([String])
    /// The first title read from Teams for a meeting joined without one (the title of the meeting
    /// is kept when it can be read).
    case titleRead(String)
    /// `teams.SPEAKER_CHANGED`: the new speaker, or nobody.
    case speakerChanged(String?)
    /// `teams.MEETING_LEFT`, `teams-access.ACCESS_LOST`, `macos.CALL_APP_MIC_STOPPED` or
    /// `recorder.RECORDING_STOPPED`: nobody is marked any more.
    case meetingEnded
}

/// The `teams-meeting` machine: the meeting Microsoft Teams shows at this moment, as LARP reads it
/// while Teams access is allowed and the reading is needed: its title, the people in it and who is
/// speaking.
///
/// Teams is read only while access is allowed and Teams uses the microphone or a recording is going
/// on (`teamsMicrophoneChanged`, `recordingChanged`); "Rileva le call" and the watched apps do not
/// matter. When the reading stops being needed, it stops and the meeting is forgotten.
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
    /// Microsoft Teams uses the microphone (`macos.CALL_APP_MIC_STARTED`).
    @ObservationIgnored private var teamsUsesMicrophone = false
    /// A recording is going on (`recorder.RECORDING_STARTED`).
    @ObservationIgnored private var isRecording = false
    @ObservationIgnored private var tasks: [Task<Void, Never>] = []

    init(
        access: TeamsAccessController = .shared,
        reader: any TeamsReading = AccessibilityTeamsReader()
    ) {
        self.access = access
        self.reader = reader
    }

    /// Follows Teams access: Teams is read while it is allowed and needed. Call once, at launch,
    /// after the access machine has seen `macos.APP_LAUNCHED`.
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
        stopReading(because: "access to Teams lost")
        if let target = TeamsMeetingStateMachine.target(from: state, on: .accessLost) {
            leave(to: target)
        }
    }

    /// Teams access became allowed or not: the reading starts when it is needed, or stops.
    func accessChanged(allowed: Bool) {
        reconcile(reason: allowed ? "access to Teams allowed" : "access to Teams not allowed")
    }

    /// `macos.CALL_APP_MIC_STARTED` and `macos.CALL_APP_MIC_STOPPED` for Microsoft Teams, whether or
    /// not call detection is on and Teams is watched. When Teams stops using the microphone and no
    /// recording is going on, the reading stops and the meeting is forgotten.
    func teamsMicrophoneChanged(inUse: Bool) {
        guard inUse != teamsUsesMicrophone else { return }
        teamsUsesMicrophone = inUse
        reconcile(reason: inUse ? "Teams uses the microphone" : "Teams stopped using the microphone")
        if !inUse,
            let target = TeamsMeetingStateMachine.target(from: state, on: .callAppMicStopped(recording: isRecording))
        {
            leave(to: target)
        }
    }

    /// `recorder.RECORDING_STARTED` and `recorder.RECORDING_STOPPED`. When a recording ends while Teams
    /// does not use the microphone, the reading stops and the meeting is forgotten.
    func recordingChanged(isRecording: Bool) {
        guard isRecording != self.isRecording else { return }
        self.isRecording = isRecording
        reconcile(reason: isRecording ? "recording started" : "recording stopped")
        if !isRecording,
            let target = TeamsMeetingStateMachine.target(
                from: state, on: .recordingStopped(teamsUsesMicrophone: teamsUsesMicrophone))
        {
            leave(to: target)
        }
    }

    /// What the recorder tells about the microphone and the recordings, for the reading of Teams.
    func recorderActivity(_ activity: RecorderActivity) {
        switch activity {
        case .callAppMic(.bundleStarted(let bundle)):
            // Only the main process of the new Teams; the classic Teams using the microphone is not.
            if bundle == TeamsInterface.bundleIdentifier { teamsMicrophoneChanged(inUse: true) }
        case .callAppMic(.bundleStopped(let bundle)):
            if bundle == TeamsInterface.bundleIdentifier { teamsMicrophoneChanged(inUse: false) }
        case .callAppMic(.started), .callAppMic(.stopped):
            break
        case .recordingStarted:
            recordingChanged(isRecording: true)
        case .recordingStopped:
            recordingChanged(isRecording: false)
        }
    }

    /// One reading of Teams: the changes since the previous one are the Events of the actor
    /// `teams`. Ignored while Teams access is not allowed.
    func received(_ readout: TeamsReadout) {
        guard access.isAllowed, isReading else { return }
        // A reading that stopped at a limit before the element of the meeting was found says nothing.
        guard !readout.leavesMeetingAsItWas else { return }
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
        // The first title read for a meeting joined without one.
        if title == nil, let read = meeting.title {
            title = read
            broadcaster.emit(.titleRead(read))
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

    /// Starts or stops the reading according to whether it is needed: Teams access is allowed and
    /// Teams uses the microphone or a recording is going on.
    private func reconcile(reason: String) {
        if access.isAllowed, teamsUsesMicrophone || isRecording {
            guard !isReading else { return }
            isReading = true
            TeamsLog.started(reason)
            reader.start { [weak self] readout in self?.received(readout) }
        } else {
            stopReading(because: reason)
        }
    }

    private func stopReading(because reason: String) {
        guard isReading else { return }
        isReading = false
        TeamsLog.stopped(reason)
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
