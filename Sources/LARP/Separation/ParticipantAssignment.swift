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
    /// - A line that no voice overlaps goes to the participant of the recognized
    ///   line nearest to it in time (the earlier one when two are equally near).
    /// - When no line is recognized (no voice found, or none overlaps a line), every
    ///   line goes to Participant 1.
    /// - Participants are numbered in the order in which they first speak in the
    ///   transcript (by start of their first line); a voice that gets no line gets
    ///   no number.
    ///
    /// Every line gets a number: the result has the length of `lines`.
    static func assign(lines: [LineSpan], segments: [SpeakerSegment]) -> [Int] {
        let segmentsBySpeaker = Dictionary(grouping: segments, by: \.speaker)
        // Ties are broken by the voice that speaks first, then by name, so the
        // result does not depend on dictionary order.
        let speakers = segmentsBySpeaker.keys.sorted { lhs, rhs in
            let first = (segmentsBySpeaker[lhs] ?? []).map(\.start).min() ?? 0
            let other = (segmentsBySpeaker[rhs] ?? []).map(\.start).min() ?? 0
            return first == other ? lhs < rhs : first < other
        }

        let recognizedVoice = lines.map { line in
            voice(of: line, speakers: speakers, segmentsBySpeaker: segmentsBySpeaker)
        }
        let chronological = lines.indices.sorted { lhs, rhs in
            lines[lhs].start == lines[rhs].start ? lhs < rhs : lines[lhs].start < lines[rhs].start
        }

        // Without any recognized line there is no voice to follow: one participant.
        let recognized = chronological.filter { recognizedVoice[$0] != nil }
        guard !recognized.isEmpty else { return lines.map { _ in 1 } }

        // The lines no voice overlaps take the voice of the nearest recognized line.
        let voiceOfLine = lines.indices.map { index -> String in
            if let voice = recognizedVoice[index] { return voice }
            var nearest: (voice: String?, distance: TimeInterval) = (nil, .infinity)
            for other in recognized {
                let distance = max(0, lines[other].start - lines[index].end, lines[index].start - lines[other].end)
                if distance < nearest.distance {
                    nearest = (recognizedVoice[other], distance)
                }
            }
            return nearest.voice ?? ""
        }

        var numbers: [String: Int] = [:]
        for index in chronological where numbers[voiceOfLine[index]] == nil {
            numbers[voiceOfLine[index]] = numbers.count + 1
        }
        return voiceOfLine.map { numbers[$0] ?? 1 }
    }

    /// The voice whose segments overlap `line` most, or `nil` when none overlaps it.
    private static func voice(
        of line: LineSpan, speakers: [String], segmentsBySpeaker: [String: [SpeakerSegment]]
    ) -> String? {
        var best: (speaker: String, overlap: TimeInterval)?
        for speaker in speakers {
            let overlap = (segmentsBySpeaker[speaker] ?? []).reduce(0) { total, segment in
                total + max(0, min(line.end, segment.end) - max(line.start, segment.start))
            }
            if overlap > (best?.overlap ?? 0) {
                best = (speaker, overlap)
            }
        }
        return best?.speaker
    }
}
