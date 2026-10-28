import AVFoundation
import Foundation

/// The two tracks of a call.
enum AudioTrack: CaseIterable, Sendable {
    /// The microphone: the user ("Io").
    case microphone
    /// The system audio: the other parties ("Altri").
    case system

    var speaker: SpeakerKind {
        switch self {
        case .microphone: .me
        case .system: .others
        }
    }

    var fileName: String {
        switch self {
        case .microphone: AppPaths.micFileName
        case .system: AppPaths.systemFileName
        }
    }

    /// The audio file of this track in the call's recordings folder.
    func fileURL(in folder: URL) -> URL {
        folder.appending(path: fileName)
    }

    /// The audio file of this track for `call`.
    func fileURL(of call: Call) -> URL {
        fileURL(in: call.recordingsFolderURL)
    }
}

/// An audio buffer handed from the capture to a consumer. The capture never
/// touches the buffer again, so it can cross isolation boundaries.
struct AudioChunk: @unchecked Sendable {
    let buffer: AVAudioPCMBuffer
}

/// Receives the audio of a recording after it has been written to disk.
/// `consume` is called from the capture's own queue and must return quickly.
protocol AudioBufferSink: Sendable {
    func consume(_ chunk: AudioChunk, track: AudioTrack)
}

/// Whether a recording needs the system audio.
enum SystemAudioPolicy: Sendable {
    /// The recording does not start without the system audio (accepting a proposal).
    case required
    /// Without the system audio (its permission is missing or its capture does not
    /// start) only the microphone is recorded (a recording started by hand).
    case optional
}

/// What the capture tells the recorder while a recording runs. May be reported from
/// any thread.
enum CaptureEvent: Equatable, Sendable {
    /// A recording with an optional system audio records only the microphone.
    /// `permissionMissing` tells that the system audio permission is the reason.
    case systemAudioUnavailable(permissionMissing: Bool)
    /// The microphone started or restarted while the system audio is recorded: whether
    /// the sound of the others is removed from it.
    case echoCancellation(available: Bool)
    /// The microphone could not start again after a change of audio devices: the
    /// recording goes on without the user's voice.
    case microphoneLost
    /// The microphone is being recorded again after it was lost.
    case microphoneRestored
}

/// Captures the microphone and the system audio of a recording into
/// `mic.caf` and `system.caf`.
protocol AudioCapturing: Sendable {
    /// Starts capturing both tracks into `folder` (created if needed). Every
    /// buffer is written to disk first and then given to `sink`, in the format
    /// `AudioFormats.storage`. Throws if the microphone cannot be started, or the
    /// system audio when `systemAudio` is `.required`; nothing is left running then.
    /// With `.optional` and no system audio, only the microphone is captured and
    /// `system.caf` stays empty.
    func start(into folder: URL, sink: (any AudioBufferSink)?, systemAudio: SystemAudioPolicy) async throws

    /// Stops capturing and closes the files. Returns after everything captured
    /// has been written and given to the sink.
    func stop() async
}

/// Audio formats of the app.
enum AudioFormats {
    /// Sample rate of the stored audio and of the audio given to sinks.
    static let storageSampleRate: Double = 16_000
    /// Bit rate of the AAC audio files, per track.
    static let storageBitRate = 32_000

    /// Mono 32-bit float at `storageSampleRate`: what the capture produces.
    static var storage: AVAudioFormat {
        AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: storageSampleRate, channels: 1, interleaved: false)!
    }
}
