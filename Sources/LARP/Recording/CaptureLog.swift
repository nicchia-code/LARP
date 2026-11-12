import AVFoundation
import Foundation
import Synchronization
import os

/// The diagnostic log of the capture: formats, durations, dropped buffers and the reasons of
/// restarts, losses and returns. Every line goes to `os.Logger` (the app's subsystem, the category
/// `capture`) and to the diagnostic log of LARP (area `capture`). It stays on the Mac and never
/// holds audio or transcript text.
///
/// Never called from an audio thread: only from the private queues.
enum CaptureLog {
    static let logger = Logger(subsystem: "com.larp.LARP", category: "capture")

    /// Why the microphone starts again.
    enum MicrophoneRestartReason: String, Sendable {
        /// The microphone to use is not the one being captured.
        case microphoneToUseChanged = "microphone to use changed"
        /// The microphone in use delivers another format (sample rate or stream format).
        case formatChanged = "microphone format changed"
        /// The microphone in use is gone.
        case microphoneGone = "microphone gone"
        /// The user chose a microphone.
        case chosenByUser = "microphone chosen by the user"
    }

    /// A line to both logs.
    private static func info(_ message: String) {
        logger.info("\(message, privacy: .public)")
        DiagnosticLog.write(area: .capture, message)
    }

    /// A format as the log tells it.
    static func describe(_ format: AVAudioFormat?) -> String {
        guard let format else { return "unknown" }
        return "\(format.sampleRate) Hz, \(format.channelCount) ch, \(format.isInterleaved ? "interleaved" : "non-interleaved")"
    }

    /// At every start and restart of the system audio.
    static func systemAudioStarted(_ formats: SystemAudioFormats) {
        info("System audio started: tap reports \(describe(formats.reported)), stream read \(describe(formats.stream))")
    }

    /// At every start and restart of the microphone.
    static func microphoneStarted(tapped format: AVAudioFormat) {
        info("Microphone started: format tapped \(describe(format))")
    }

    /// Before the microphone starts again.
    static func microphoneRestarting(_ reason: MicrophoneRestartReason) {
        info("Microphone restarts: \(reason.rawValue)")
    }

    /// A new echo canceller made because only the output (or its format) changed: the microphone
    /// goes on without a gap.
    static func echoCancellerRenewed(available: Bool) {
        info("Output changed, microphone not reopened: new echo canceller \(available ? "created" : "not available")")
    }

    static func microphoneLost() { info("Microphone lost: it could not start again") }

    static func microphoneRestored() { info("Microphone restored") }

    /// Why the system audio starts again: the values of its signature that changed, or the
    /// seconds without audio when it stalled.
    static func systemAudioRestarting(_ reason: String) {
        info("System audio restarts: \(reason)")
    }

    /// The seconds without audio that make the system audio stalled.
    static func stalledReason(seconds: TimeInterval) -> String {
        "no audio for \(String(format: "%.1f", seconds)) s"
    }

    static func systemAudioLost() { info("System audio lost: it could not start again") }

    static func systemAudioRestored() { info("System audio restored") }

    /// At the stop of a recording: what a track that was written holds, and what its source
    /// dropped.
    static func trackStopped(
        _ track: AudioTrack, stats: TrackStats, recordingSeconds: TimeInterval, drops: BufferDropCounts
    ) {
        let audio = String(format: "%.2f", stats.audioSeconds)
        let silence = String(format: "%.2f", stats.silenceSeconds)
        let recording = String(format: "%.2f", recordingSeconds)
        info(
            "Track \(track.fileName) stopped: audio \(audio) s, silence added \(silence) s, recording \(recording) s; buffers dropped: run ended or not following the output \(drops.endedRun), unreadable \(drops.unreadable), conversion failed \(drops.conversionFailed)"
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
