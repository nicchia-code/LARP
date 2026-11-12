import Foundation

/// States of the `teams-meeting` machine (Model `meeting-info/teams-meeting`).
enum TeamsMeetingState: Sendable, Equatable {
    /// Teams is not running, shows no meeting, or cannot be read.
    case noMeeting
    /// Teams shows a meeting.
    case inMeeting
}

/// Events the `teams-meeting` machine reacts to. Events with a guard carry the facts the guard
/// needs.
enum TeamsMeetingEvent: Sendable, Equatable {
    /// `teams.MEETING_JOINED`. `accessAllowed`: Teams access is allowed.
    case meetingJoined(accessAllowed: Bool)
    /// `teams.PARTICIPANTS_READ`
    case participantsRead
    /// `teams.SPEAKER_CHANGED`
    case speakerChanged
    /// `teams.MEETING_LEFT`
    case meetingLeft
    /// `teams-access.ACCESS_LOST`
    case accessLost
    /// `macos.CALL_APP_MIC_STOPPED` for Microsoft Teams. `recording`: a recording is going on.
    case callAppMicStopped(recording: Bool)
    /// `recorder.RECORDING_STOPPED`. `teamsUsesMicrophone`: Microsoft Teams uses the microphone.
    case recordingStopped(teamsUsesMicrophone: Bool)
}

/// The transition table of the `teams-meeting` machine. Pure: it only says where an event leads;
/// `TeamsMeetingController` performs the effects. A state that does not react to an event has no
/// entry (`nil`).
enum TeamsMeetingStateMachine {
    static func target(from state: TeamsMeetingState, on event: TeamsMeetingEvent) -> TeamsMeetingState? {
        switch (state, event) {
        // No meeting
        case (.noMeeting, .meetingJoined(let accessAllowed)):
            return accessAllowed ? .inMeeting : nil

        // In a meeting
        case (.inMeeting, .participantsRead), (.inMeeting, .speakerChanged):
            return .inMeeting
        case (.inMeeting, .meetingLeft), (.inMeeting, .accessLost):
            return .noMeeting
        case (.inMeeting, .callAppMicStopped(let recording)):
            return recording ? nil : .noMeeting
        case (.inMeeting, .recordingStopped(let teamsUsesMicrophone)):
            return teamsUsesMicrophone ? nil : .noMeeting

        default:
            return nil
        }
    }
}
