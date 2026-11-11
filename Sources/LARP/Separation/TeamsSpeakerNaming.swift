import Foundation

/// A participant of a separated call with the time of its lines, for the names that Teams marked as
/// speaking at the time.
struct ParticipantSpeech: Equatable, Sendable {
    /// The number of the participant (1, 2, …).
    let number: Int
    /// The time of each of its lines, in seconds from the start of the call.
    let lines: [LineSpan]
}

/// Gives the participants of a separated call the names Teams marked as speaking
/// (`requirements/rules#call/Separating participants`). Pure: no call, no settings.
enum TeamsSpeakerNaming {
    /// The share of the total time of the lines of a participant that its name has to cover.
    static let requiredShare = 0.7

    /// The name of each participant that has one, by participant number.
    ///
    /// For each participant the time of each of its lines is split among the names of the spans of
    /// the Teams timeline that overlap it; the name with the most time wins when it covers at least
    /// 70 % of the total time of the lines of the participant, otherwise the participant keeps its
    /// number. A name goes to one participant only: when two participants win the same name, the one
    /// whose share is higher takes it (the one with the lower number when the shares are equal) and
    /// the other keeps its number. Names are compared without case, accents and surrounding spaces.
    /// Spans without a name give nothing; without spans nobody is named.
    static func names(for participants: [ParticipantSpeech], timeline: [SpeakerSpan]) -> [Int: String] {
        let named = timeline.compactMap { span -> (name: String, start: TimeInterval, end: TimeInterval)? in
            guard let name = span.name, !name.isEmpty else { return nil }
            return (name, span.start, span.end)
        }
        guard !named.isEmpty else { return [:] }

        struct Winner {
            let number: Int
            let name: String
            let share: Double
        }
        var winners: [Winner] = []
        for participant in participants {
            let total = participant.lines.reduce(0) { $0 + max(0, $1.end - $1.start) }
            guard total > 0 else { continue }
            // The time of the lines of the participant that each name covers, by name in order of
            // first appearance so that a tie between names goes to the one Teams marked first.
            var order: [String] = []
            var time: [String: (display: String, seconds: TimeInterval)] = [:]
            for line in participant.lines {
                for span in named {
                    let overlap = min(line.end, span.end) - max(line.start, span.start)
                    guard overlap > 0 else { continue }
                    let key = TeamsText.fold(span.name)
                    if time[key] == nil {
                        order.append(key)
                        time[key] = (span.name, 0)
                    }
                    time[key]?.seconds += overlap
                }
            }
            var best: (key: String, seconds: TimeInterval)?
            for key in order {
                let seconds = time[key]?.seconds ?? 0
                if best == nil || seconds > best!.seconds { best = (key, seconds) }
            }
            guard let best, let display = time[best.key]?.display else { continue }
            let share = best.seconds / total
            // A tolerance for the sum of the times in floating point: 0.7 of 10 s is 7 s.
            guard share >= requiredShare - 1e-9 else { continue }
            winners.append(Winner(number: participant.number, name: display, share: share))
        }

        // One name, one participant: the highest share keeps it, then the lowest number.
        var names: [Int: String] = [:]
        var taken: [String: Winner] = [:]
        for winner in winners {
            let key = TeamsText.fold(winner.name)
            if let current = taken[key] {
                if winner.share > current.share || (winner.share == current.share && winner.number < current.number) {
                    taken[key] = winner
                }
            } else {
                taken[key] = winner
            }
        }
        for winner in taken.values {
            names[winner.number] = winner.name
        }
        return names
    }
}
