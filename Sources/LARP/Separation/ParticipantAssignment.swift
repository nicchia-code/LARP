import Foundation

/// A stretch of the system audio spoken by one voice, as found by diarization.
struct SpeakerSegment: Equatable, Sendable {
    /// Identifier of the voice, as given by the diarizer (e.g. `S1`).
    let speaker: String
    /// Seconds from the start of the audio, which is the start of the call.
    let start: TimeInterval
    let end: TimeInterval
}

/// The time span of a transcript line, in seconds from the start of the call.
struct LineSpan: Equatable, Sendable {
    let start: TimeInterval
    let end: TimeInterval
}

/// Gives each "Others" line to a participant by voice. Pure: no audio, no models.
enum ParticipantAssignment {
    /// The participant number (1, 2, …) of each line of `lines`, in the same order.
    ///
    /// - A line goes to the voice whose segments overlap it most in time.
    /// - A line without any overlap goes to the voice of the nearest segment.
    /// - Participants are numbered in the order in which they first speak in the
    ///   transcript (by start of their first line); a voice that gets no line gets
    ///   no number.
    ///
    /// Every entry is `nil` when `segments` is empty: no voice was found, so no
    /// line can be given to a participant.
    static func assign(lines: [LineSpan], segments: [SpeakerSegment]) -> [Int?] {
        guard !segments.isEmpty else { return lines.map { _ in nil } }

        let segmentsBySpeaker = Dictionary(grouping: segments, by: \.speaker)
        // Ties are broken by the voice that speaks first, then by name, so the
        // result does not depend on dictionary order.
        let speakers = segmentsBySpeaker.keys.sorted { lhs, rhs in
            let first = (segmentsBySpeaker[lhs] ?? []).map(\.start).min() ?? 0
            let other = (segmentsBySpeaker[rhs] ?? []).map(\.start).min() ?? 0
            return first == other ? lhs < rhs : first < other
        }

        let speakerOfLine = lines.map { line in
            speaker(of: line, speakers: speakers, segmentsBySpeaker: segmentsBySpeaker)
        }

        var numbers: [String: Int] = [:]
        let chronological = lines.indices.sorted { lhs, rhs in
            lines[lhs].start == lines[rhs].start ? lhs < rhs : lines[lhs].start < lines[rhs].start
        }
        for index in chronological {
            let speaker = speakerOfLine[index]
            if numbers[speaker] == nil {
                numbers[speaker] = numbers.count + 1
            }
        }
        return speakerOfLine.map { numbers[$0] }
    }

    private static func speaker(
        of line: LineSpan, speakers: [String], segmentsBySpeaker: [String: [SpeakerSegment]]
    ) -> String {
        var best: (speaker: String, overlap: TimeInterval)?
        for speaker in speakers {
            let overlap = (segmentsBySpeaker[speaker] ?? []).reduce(0) { total, segment in
                total + max(0, min(line.end, segment.end) - max(line.start, segment.start))
            }
            if overlap > (best?.overlap ?? 0) {
                best = (speaker, overlap)
            }
        }
        if let best {
            return best.speaker
        }

        var nearest: (speaker: String, distance: TimeInterval)?
        for speaker in speakers {
            for segment in segmentsBySpeaker[speaker] ?? [] {
                let distance = max(0, segment.start - line.end, line.start - segment.end)
                if distance < (nearest?.distance ?? .infinity) {
                    nearest = (speaker, distance)
                }
            }
        }
        // `speakers` is not empty, so there is always a nearest segment.
        return nearest?.speaker ?? speakers[0]
    }
}
