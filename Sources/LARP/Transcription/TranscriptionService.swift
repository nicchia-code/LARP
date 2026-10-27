import Foundation

/// A final transcription result, in the shape stored as a `TranscriptLine`. Live and
/// file transcription produce the same kind of lines.
struct TranscribedLine: Equatable, Sendable {
    /// `.me` for the microphone track, `.others` for the system audio track.
    let speaker: SpeakerKind
    /// Seconds from the start of the track, which is the start of the call.
    let start: TimeInterval
    let end: TimeInterval
    let text: String
}

/// Transcription of the two tracks of a call while it is recorded.
/// Fed with the audio by the capture, once the audio is on disk.
protocol LiveTranscriptionSession: AudioBufferSink {
    /// The final lines of both tracks as they come, in no particular order. Ends
    /// after `finish()` or `cancel()`. Meant for a single consumer.
    var lines: AsyncStream<TranscribedLine> { get }

    /// Ends the audio and waits until everything fed has been transcribed. Returns
    /// `true` when the whole recording was transcribed live, `false` when part of
    /// it was not (a track failed).
    func finish() async -> Bool

    /// Stops at once and discards what is pending.
    func cancel() async
}

/// Speech-to-text, off the main actor.
protocol TranscriptionService: Sendable {
    /// Starts the live transcription of both tracks in `language`. Throws when it
    /// cannot start: the recording then goes on without it.
    func startLiveSession(language: String) async throws -> any LiveTranscriptionSession

    /// Transcribes the saved audio file of one track. A missing or empty file gives
    /// no lines. Supports cancellation: when the calling task is cancelled the
    /// transcription stops and the call throws `CancellationError`.
    func transcribeFile(at url: URL, speaker: SpeakerKind, language: String) async throws -> [TranscribedLine]
}
