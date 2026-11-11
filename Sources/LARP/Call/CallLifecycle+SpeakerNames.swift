import Foundation

/// The names that Teams and the calendar give to the participants of a call, while "Identifica i
/// parlanti" is on (`speaker-identification`).
extension CallLifecycle {
    /// When the separation of voices ends: for each participant the time of each of its lines is
    /// split among the names of the Teams speaker spans that overlap it, and the name with the most
    /// time takes the participant when it covers at least 70 % of the time of its lines; a name goes
    /// to one participant only (see `TeamsSpeakerNaming`). The name is stored as the name of the
    /// participant, as if the user had typed it, so it never goes to omp, and a name the user gave
    /// is never replaced. Nothing is done while the switch is off, or when Teams showed nobody
    /// speaking.
    func nameParticipantsFromTeams(of call: Call) {
        guard speakerIdentificationIsOn() else { return }
        let timeline = call.speakerTimeline
        guard !timeline.isEmpty else { return }
        let participants = call.participants.sorted { $0.number < $1.number }
        let speeches = participants.map { participant in
            ParticipantSpeech(
                number: participant.number,
                lines: participant.lines.map { LineSpan(start: $0.start, end: $0.end) })
        }
        let names = TeamsSpeakerNaming.names(for: speeches, timeline: timeline)
        // Names the user already gave stay, and are not given a second time.
        var taken = Set(participants.compactMap(\.name).map(TeamsText.fold))
        for participant in participants where participant.name == nil {
            guard let name = names[participant.number], taken.insert(TeamsText.fold(name)).inserted else { continue }
            participant.name = name
        }
    }

    /// The names the rename field of `participant` offers: the names kept with the call from Teams
    /// and the calendar that no other participant of the call has. None while the switch is off.
    func offeredNames(for participant: Participant, in call: Call) -> [String] {
        guard speakerIdentificationIsOn() else { return [] }
        let taken = Set(
            call.participants.filter { $0 !== participant }.compactMap(\.name).map(TeamsText.fold))
        return call.participantNames.filter { !taken.contains(TeamsText.fold($0)) }
    }
}
