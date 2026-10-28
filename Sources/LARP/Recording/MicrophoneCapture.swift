import AVFoundation
import Foundation

/// Captures the default input device with `AVAudioEngine` and feeds a `TrackPipeline`.
/// Follows the default device when it changes during the recording.
///
/// Voice processing is switched on for every recording, whatever the audio output
/// is, so the sound of the other participants that the microphone picks up from the
/// speakers is removed from the microphone track. When it cannot be switched on the
/// capture goes on without it.
final class MicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice: "Nessun microfono disponibile."
            }
        }
    }

    private let pipeline: TrackPipeline
    /// Called after the engine has started, at the start and after every restart
    /// caused by a change of microphone or audio output: `true` when voice
    /// processing is on (the sound of the others is removed from the microphone),
    /// `false` when the capture runs without it.
    private let echoCancellationChanged: @Sendable (Bool) -> Void
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var configurationObserver: NSObjectProtocol?
    private var isRunning = false

    init(pipeline: TrackPipeline, echoCancellationChanged: @escaping @Sendable (Bool) -> Void = { _ in }) {
        self.pipeline = pipeline
        self.echoCancellationChanged = echoCancellationChanged
    }

    func start() throws {
        let echoCancelled: Bool = try lock.withLock {
            let echoCancelled = try installTapAndStart()
            isRunning = true
            configurationObserver = NotificationCenter.default.addObserver(
                forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
            ) { [weak self] _ in
                self?.restartAfterConfigurationChange()
            }
            return echoCancelled
        }
        echoCancellationChanged(echoCancelled)
    }

    func stop() {
        lock.lock()
        defer { lock.unlock() }
        isRunning = false
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
            self.configurationObserver = nil
        }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
    }

    /// Starts the engine with voice processing on the input node, or without it when
    /// that fails. Returns whether voice processing is on.
    private func installTapAndStart() throws -> Bool {
        engine.stop()
        let input = engine.inputNode
        input.removeTap(onBus: 0)
        if Self.enableVoiceProcessing(on: input) {
            do {
                try installTapAndStartEngine()
                return true
            } catch {
                engine.stop()
                input.removeTap(onBus: 0)
            }
        }
        Self.disableVoiceProcessing(on: input)
        try installTapAndStartEngine()
        return false
    }

    /// Voice processing before the engine starts, with the lowest ducking of the other
    /// audio. The automatic gain control stays as macOS sets it.
    private static func enableVoiceProcessing(on input: AVAudioInputNode) -> Bool {
        do {
            if !input.isVoiceProcessingEnabled {
                try input.setVoiceProcessingEnabled(true)
            }
            input.voiceProcessingOtherAudioDuckingConfiguration = AVAudioVoiceProcessingOtherAudioDuckingConfiguration(
                enableAdvancedDucking: true, duckingLevel: .min)
            return true
        } catch {
            return false
        }
    }

    private static func disableVoiceProcessing(on input: AVAudioInputNode) {
        if input.isVoiceProcessingEnabled {
            try? input.setVoiceProcessingEnabled(false)
        }
    }

    /// The tap uses the format the input node reports now, read after voice
    /// processing was switched on or off: the pipeline converts it to the storage format.
    private func installTapAndStartEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInputDevice }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [pipeline] buffer, _ in
            pipeline.ingest(borrowing: buffer)
        }
        engine.prepare()
        try engine.start()
    }

    /// `macos.AUDIO_DEVICES_CHANGED`: the engine stops itself when the input device,
    /// the output device or their formats change. It restarts with voice processing
    /// switched on again.
    private func restartAfterConfigurationChange() {
        let echoCancelled: Bool? = lock.withLock {
            guard isRunning else { return nil }
            return (try? installTapAndStart()) ?? false
        }
        if let echoCancelled { echoCancellationChanged(echoCancelled) }
    }
}
