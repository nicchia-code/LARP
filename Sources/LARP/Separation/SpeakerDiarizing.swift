import FluidAudio
import Foundation

/// Tells the voices of an audio file apart. Replaceable in tests.
protocol SpeakerDiarizing: Sendable {
    /// The segments spoken by each voice in the audio file at `url`; the number
    /// of voices is detected automatically. Throws when the analysis cannot be
    /// done, for example when the models cannot be downloaded.
    func diarize(audioAt url: URL) async throws -> [SpeakerSegment]
}

/// FluidAudio's offline diarization (`OfflineDiarizerManager`, the successor of
/// `DiarizerManager` in the pinned version): voice fingerprints grouped on
/// Core ML. FluidAudio converts the file to 16 kHz mono before analysing it.
///
/// The models are downloaded on first use into `AppPaths.diarizerModelsFolder`
/// and reused afterwards.
struct FluidAudioDiarizer: SpeakerDiarizing {
    func diarize(audioAt url: URL) async throws -> [SpeakerSegment] {
        let manager = OfflineDiarizerManager()
        try await manager.prepareModels(directory: AppPaths.diarizerModelsFolder)
        let result = try await manager.process(url)
        return result.segments.map {
            SpeakerSegment(
                speaker: $0.speakerId,
                start: TimeInterval($0.startTimeSeconds),
                end: TimeInterval($0.endTimeSeconds)
            )
        }
    }
}
