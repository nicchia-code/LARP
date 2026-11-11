import AVFoundation
import Foundation
import Synchronization
import os

/// The diagnostic log of the capture: formats, durations and dropped buffers, with the
/// app's subsystem and the category `capture`. It stays on the Mac and never holds audio
/// or transcript text.
enum CaptureLog {
    static let logger = Logger(subsystem: "com.larp.LARP", category: "capture")

    /// A format as the log tells it.
    static func describe(_ format: AVAudioFormat?) -> String {
        guard let format else { return "unknown" }
        return "\(format.sampleRate) Hz, \(format.channelCount) ch, \(format.isInterleaved ? "interleaved" : "non-interleaved")"
    }

    /// At every start and restart of the system audio.
    static func systemAudioStarted(_ formats: SystemAudioFormats) {
        logger.info(
            "System audio started: tap reports \(describe(formats.reported), privacy: .public), stream read \(describe(formats.stream), privacy: .public)"
        )
    }

    /// At every start and restart of the microphone.
    static func microphoneStarted(tapped format: AVAudioFormat) {
        logger.info("Microphone started: format tapped \(describe(format), privacy: .public)")
    }

    /// At the stop of a recording: what a track that was written holds, and what its source
    /// dropped.
    static func trackStopped(
        _ track: AudioTrack, stats: TrackStats, recordingSeconds: TimeInterval, drops: BufferDropCounts
    ) {
        let audio = String(format: "%.2f", stats.audioSeconds)
        let silence = String(format: "%.2f", stats.silenceSeconds)
        let recording = String(format: "%.2f", recordingSeconds)
        logger.info(
            "Track \(track.fileName, privacy: .public) stopped: audio \(audio, privacy: .public) s, silence added \(silence, privacy: .public) s, recording \(recording, privacy: .public) s; buffers dropped: run ended or not following the output \(drops.endedRun), unreadable \(drops.unreadable), conversion failed \(drops.conversionFailed)"
        )
    }
}

/// What a written track holds, in seconds.
struct TrackStats: Sendable, Equatable {
    /// The audio written as it was captured (silence that replaced it while paused included).
    var audioSeconds = 0.0
    /// The silence added for what was missing: gaps, the start and the end of the track.
    var silenceSeconds = 0.0
}

/// Why a source dropped a buffer.
enum BufferDropReason: Sendable {
    /// The run that delivered it had already ended or no longer followed the output.
    case endedRun
    /// It could not be read (a copy that could not be made, a stream that was not there).
    case unreadable
    /// Its conversion to the storage format failed.
    case conversionFailed
}

struct BufferDropCounts: Sendable, Equatable {
    var endedRun = 0
    var unreadable = 0
    var conversionFailed = 0
}

/// The buffers a source dropped, counted from any thread.
final class BufferDrops: Sendable {
    private let state = Mutex(BufferDropCounts())

    var counts: BufferDropCounts { state.withLock { $0 } }

    func record(_ reason: BufferDropReason) {
        state.withLock { counts in
            switch reason {
            case .endedRun: counts.endedRun += 1
            case .unreadable: counts.unreadable += 1
            case .conversionFailed: counts.conversionFailed += 1
            }
        }
    }
}
