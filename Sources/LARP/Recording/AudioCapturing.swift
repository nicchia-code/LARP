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

/// Captures the microphone and the system audio of a recording into
/// `mic.caf` and `system.caf`.
protocol AudioCapturing: Sendable {
    /// Starts capturing both tracks into `folder` (created if needed). Every
    /// buffer is written to disk first and then given to `sink`, in the format
    /// `AudioFormats.storage`. Throws if either track cannot be started; nothing
    /// is left running then.
    func start(into folder: URL, sink: (any AudioBufferSink)?) async throws

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
