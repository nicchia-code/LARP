import Foundation

/// The meeting information Microsoft Teams gives to the call being recorded (the `teams-meeting`
/// machine, Model `meeting-info/teams-meeting`): the title of the meeting, the names of the people
/// in it and the timeline of who Teams marks as speaking. It stays with the call on the Mac, goes
/// with it when it is deleted and is never sent to omp.
///
/// Every piece may never come: a call whose Teams was never read has no meeting title, no names
/// and no timeline.
extension CallLifecycle {
    /// What `teams-meeting` tells, during a recording: `teams.MEETING_JOINED` gives the call its
    /// meeting title if it has none yet, `teams.PARTICIPANTS_READ` adds the names not already kept
    /// to the names for its participants and `teams.SPEAKER_CHANGED` adds the change to the timeline
    /// of speakers at the elapsed time, not while the recording is paused. Nothing is kept when no
    /// call is being recorded.
    func teamsMeetingNews(_ news: TeamsMeetingNews) {
        guard let call = activeRecording?.call else { return }
        switch news {
        case .meetingJoined(let title):
            keepMeetingTitle(title, on: call)
        case .participantsRead(let names):
            keepParticipantNames(names, on: call)
        case .speakerChanged(let name):
            speakerTimeline.change(to: name, at: elapsed(in: call))
            call.speakerTimeline = speakerTimeline.spans
        case .meetingEnded:
            speakerTimeline.meetingEnded(at: elapsed(in: call))
            call.speakerTimeline = speakerTimeline.spans
        }
        save()
    }

    /// A recording starts: the call takes as meeting title the title of the meeting Teams shows, else
    /// the title of the calendar event in progress, and as names for its participants the people Teams
    /// shows and the people invited to that event, as the Events would have given them; and, when
    /// Teams already shows a meeting, its speaker.
    func beginMeetingInformation(for call: Call) {
        speakerTimeline = SpeakerTimelineBuilder()
        let meeting = teamsMeeting()
        let event = calendarMeeting()
        // The title of Teams comes first: the one kept is never replaced.
        keepMeetingTitle(meeting?.title, on: call)
        keepMeetingTitle(event?.title, on: call)
        keepParticipantNames((meeting?.people ?? []) + (event?.invitees ?? []), on: call)
        if let meeting {
            speakerTimeline.begin(speaker: meeting.speaker, at: elapsed(in: call))
            call.speakerTimeline = speakerTimeline.spans
        }
        save()
    }

    /// `user.PAUSE_RECORDING` / `user.RESUME_RECORDING` for the timeline of speakers.
    func pauseSpeakerTimeline(_ paused: Bool) {
        guard let call = activeRecording?.call else { return }
        if paused {
            speakerTimeline.pause(at: elapsed(in: call))
        } else {
            speakerTimeline.resume(at: elapsed(in: call))
        }
        call.speakerTimeline = speakerTimeline.spans
    }

    /// The recording ends: the last span ends with it.
    func endSpeakerTimeline(of call: Call) {
        speakerTimeline.finish(at: call.duration)
        if !speakerTimeline.spans.isEmpty {
            call.speakerTimeline = speakerTimeline.spans
        }
        speakerTimeline = SpeakerTimelineBuilder()
    }

    private func keepMeetingTitle(_ title: String?, on call: Call) {
        guard call.meetingTitle == nil, let title, !title.isEmpty else { return }
        call.meetingTitle = title
    }

    private func keepParticipantNames(_ names: [String], on call: Call) {
        var kept = call.participantNames
        var known = Set(kept.map(TeamsText.fold))
        for name in names where known.insert(TeamsText.fold(name)).inserted {
            kept.append(name)
        }
        if kept != call.participantNames {
            call.participantNames = kept
        }
    }

    private func elapsed(in call: Call) -> TimeInterval {
        max(0, now().timeIntervalSince(call.startedAt))
    }
}
