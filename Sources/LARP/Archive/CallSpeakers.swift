import Foundation

/// A speaker of a call as its card and its page show it: who, the initial of its avatar and its share
/// of the speaking time.
struct CallSpeaker: Identifiable, Equatable {
    let kind: SpeakerKind
    /// The participant, for `.participant`.
    let participantNumber: Int?
    let name: String
    let initial: String
    /// Sum of end minus start of its lines, in seconds.
    let seconds: TimeInterval
    /// Its share of the speaking time of every speaker of the call, as a whole percentage rounded to
    /// the nearest.
    let percent: Int

    var id: String {
        switch kind {
        case .me: "me"
        case .others: "others"
        case .participant: "participant-\(participantNumber ?? 0)"
        }
    }
}

enum CallSpeakers {
    /// The speakers of `call`: "Io" only when it has lines, "Altri" when lines of the others are not
    /// told apart yet, and every participant; ordered by share of the speaking time, the largest
    /// first (equal shares keep "Io", "Altri", then the participants by number).
    static func speakers(of call: Call, language: AppLanguage = .current) -> [CallSpeaker] {
        var seconds: [String: TimeInterval] = [:]
        var meLines = 0
        var othersLines = 0
        for line in call.lines {
            let duration = max(line.end - line.start, 0)
            switch line.speakerKind {
            case .me:
                meLines += 1
                seconds["me", default: 0] += duration
            case .others:
                othersLines += 1
                seconds["others", default: 0] += duration
            case .participant:
                if let participant = line.participant {
                    seconds["participant-\(participant.number)", default: 0] += duration
                } else {
                    othersLines += 1
                    seconds["others", default: 0] += duration
                }
            }
        }
        let total = seconds.values.reduce(0, +)
        func percent(_ value: TimeInterval) -> Int {
            total > 0 ? Int((value / total * 100).rounded()) : 0
        }

        var speakers: [CallSpeaker] = []
        if meLines > 0 {
            let me = SpeakerKind.me.displayName(language: language)
            speakers.append(
                CallSpeaker(
                    kind: .me, participantNumber: nil, name: me, initial: String(me.prefix(1)),
                    seconds: seconds["me", default: 0], percent: percent(seconds["me", default: 0])))
        }
        if othersLines > 0 {
            let others = SpeakerKind.others.displayName(language: language)
            speakers.append(
                CallSpeaker(
                    kind: .others, participantNumber: nil, name: others, initial: String(others.prefix(1)),
                    seconds: seconds["others", default: 0], percent: percent(seconds["others", default: 0])))
        }
        for participant in call.participants.sorted(by: { $0.number < $1.number }) {
            let value = seconds["participant-\(participant.number)", default: 0]
            speakers.append(
                CallSpeaker(
                    kind: .participant, participantNumber: participant.number,
                    name: participant.displayName(language: language), initial: participant.initial,
                    seconds: value, percent: percent(value)))
        }
        // A stable sort: equal shares keep the order above.
        return speakers.enumerated()
            .sorted { ($0.element.seconds, -$0.offset) > ($1.element.seconds, -$1.offset) }
            .map(\.element)
    }
}
