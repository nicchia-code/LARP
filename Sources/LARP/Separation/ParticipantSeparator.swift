import Foundation
import SwiftData

/// The work of the **Separating participants** state of the `call` machine.
/// The state changes (`PARTICIPANTS_SEPARATED`, `SEPARATION_FAILED`) are up to
/// the caller, which reads the outcome of `separate(_:)`.
protocol ParticipantSeparating: Sendable {
    /// Gives every "Others" line of `call` to "Participant 1", "Participant 2"
    /// and so on, by voice, and saves. A line no voice is found for goes to the
    /// participant of the nearest line that has one; when no line has one, all
    /// go to "Participant 1". The lines of "Me" do not change.
    ///
    /// - Throws: any error when telling the voices apart failed (the transcript
    ///   stays with "Me" and "Others"); `CancellationError` when the task was
    ///   cancelled or the call was deleted meanwhile, in which case nothing is
    ///   changed and the failure must not be reported as `SEPARATION_FAILED`.
    @MainActor func separate(_ call: Call) async throws
}

struct ParticipantSeparator: ParticipantSeparating {
    private let diarizer: any SpeakerDiarizing

    init(diarizer: any SpeakerDiarizing = FluidAudioDiarizer()) {
        self.diarizer = diarizer
    }

    @MainActor
    func separate(_ call: Call) async throws {
        let lines = call.lines.filter { $0.speakerKind != .me }
        let spans = lines.map { LineSpan(start: $0.start, end: $0.end) }

        // Without lines of the others there is nothing to tell apart: no
        // models, no network.
        var assignment: [Int] = []
        if !lines.isEmpty {
            let segments = try await diarizer.diarize(audioAt: call.systemAudioURL)
            try Task.checkCancellation()
            assignment = ParticipantAssignment.assign(lines: spans, segments: segments)
        }

        // The call may have been deleted while the audio was analysed.
        guard let context = call.modelContext, !call.isDeleted else {
            throw CancellationError()
        }

        // A separation that starts again replaces the participants of the
        // previous one.
        for participant in Array(call.participants) {
            context.delete(participant)
        }
        call.participants.removeAll()
        var participants: [Int: Participant] = [:]
        for (line, number) in zip(lines, assignment) {
            let participant: Participant
            if let existing = participants[number] {
                participant = existing
            } else {
                participant = Participant(number: number)
                call.participants.append(participant)
                participants[number] = participant
            }
            line.speakerKind = .participant
            line.participant = participant
        }
    }
}
