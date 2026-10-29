import AVFoundation
import Foundation

/// What `MicrophoneCapture` needs from the audio engine that reads the default input
/// device; replaced in tests by fake devices.
///
/// An engine is used for one start only: `MicrophoneCapture` makes a new one at every
/// start and restart, so the format it reads is the one the microphone delivers now.
protocol MicrophoneEngine: AnyObject, Sendable {
    /// Whether macOS voice processing is on for the input: never, but tests check it.
    var isVoiceProcessingEnabled: Bool { get }

    /// The format the input delivers now.
    func inputFormat() -> AVAudioFormat

    /// Starts delivering the input, in `format`, to `deliver`, with the system uptime at
    /// which the last frame of the buffer was captured; the buffer is only valid during the
    /// call. `onConfigurationChange` is called, from any thread, when macOS changes the
    /// audio devices or their formats under the running engine
    /// (`macos.AUDIO_DEVICES_CHANGED`): the engine has stopped itself then.
    func start(
        format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
        onConfigurationChange: @escaping @Sendable () -> Void
    ) throws

    /// Stops the input. Safe to call on an engine that did not start.
    func stop()
}

/// `MicrophoneEngine` on `AVAudioEngine` and the default input device, with macOS voice
/// processing never enabled.
final class AVMicrophoneEngine: MicrophoneEngine, @unchecked Sendable {
    private let engine = AVAudioEngine()
    private var configurationObserver: NSObjectProtocol?

    var isVoiceProcessingEnabled: Bool { engine.inputNode.isVoiceProcessingEnabled }

    func inputFormat() -> AVAudioFormat {
        engine.inputNode.outputFormat(forBus: 0)
    }

    func start(
        format: AVAudioFormat, deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
        onConfigurationChange: @escaping @Sendable () -> Void
    ) throws {
        engine.inputNode.installTap(onBus: 0, bufferSize: 4096, format: format) { buffer, _ in
            deliver(buffer, ProcessInfo.processInfo.systemUptime)
        }
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { _ in
            onConfigurationChange()
        }
        engine.prepare()
        try engine.start()
    }

    func stop() {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }
}
