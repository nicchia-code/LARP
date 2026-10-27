import AVFoundation
import Foundation

/// Captures the default input device with `AVAudioEngine` and feeds a `TrackPipeline`.
/// Follows the default device when it changes during the recording.
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
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var configurationObserver: NSObjectProtocol?
    private var isRunning = false

    init(pipeline: TrackPipeline) {
        self.pipeline = pipeline
    }

    func start() throws {
        lock.lock()
        defer { lock.unlock() }
        try installTapAndStart()
        isRunning = true
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            self?.restartAfterConfigurationChange()
        }
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

    private func installTapAndStart() throws {
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

    /// The engine stops itself when the input device or its format changes.
    private func restartAfterConfigurationChange() {
        lock.lock()
        defer { lock.unlock() }
        guard isRunning else { return }
        try? installTapAndStart()
    }
}
