import AVFoundation
import CoreAudio
import Foundation

/// Captures the default input device with `AVAudioEngine` and feeds a `TrackPipeline`,
/// through the `EchoRemover` when the system audio is recorded. Follows the default
/// device when it changes during the recording.
///
/// macOS voice processing is never enabled: it would lower the audio of every other
/// app and could change the level of the microphone. The sound of the others that
/// the microphone picks up from the speakers is removed by the `EchoRemover`.
///
/// When the engine cannot start again after a change of audio devices the microphone
/// is lost: the engine stays stopped and nothing arrives from it. It starts again at
/// the next change of audio devices that lets it.
final class MicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice: "Nessun microfono disponibile."
            }
        }
    }

    /// Where the microphone audio goes: the echo remover, or the track itself when the
    /// system audio is not recorded and there is nothing to remove.
    private let input: any AudioInput
    private let echoRemover: EchoRemover?
    /// Reports `CaptureEvent.echoCancellation` after the engine has started, at the
    /// start and after every restart caused by a change of microphone or audio output
    /// (`true` when the echo canceller is running, so the sound of the others is
    /// removed from the microphone, `false` when the capture runs without it), and
    /// `.microphoneLost` / `.microphoneRestored` when the microphone goes and comes back.
    private let events: @Sendable (CaptureEvent) -> Void
    private let engine = AVAudioEngine()
    private let lock = NSLock()
    private var configurationObserver: NSObjectProtocol?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var isRunning = false
    private var lost = false

    /// - Parameters:
    ///   - pipeline: the microphone's track.
    ///   - echoRemover: removes the echo of the system audio from the microphone before it
    ///     reaches `pipeline`; `nil` when the system audio is not recorded.
    init(
        pipeline: TrackPipeline, echoRemover: EchoRemover? = nil,
        events: @escaping @Sendable (CaptureEvent) -> Void = { _ in }
    ) {
        input = echoRemover?.microphone ?? pipeline
        self.echoRemover = echoRemover
        self.events = events
    }

    /// Whether macOS voice processing is on for the input node: never, but tests check it.
    var isVoiceProcessingEnabled: Bool { lock.withLock { engine.inputNode.isVoiceProcessingEnabled } }

    /// Whether the microphone is lost. It stays so after `stop()`.
    var isLost: Bool { lock.withLock { lost } }

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
        events(.echoCancellation(available: echoCancelled))
    }

    func stop() {
        let listener: AudioObjectPropertyListenerBlock? = lock.withLock {
            isRunning = false
            if let configurationObserver {
                NotificationCenter.default.removeObserver(configurationObserver)
                self.configurationObserver = nil
            }
            engine.inputNode.removeTap(onBus: 0)
            engine.stop()
            return takeDeviceListener()
        }
        Self.remove(listener)
    }

    /// Starts the engine, then the echo canceller from scratch: it adapts to the microphone
    /// and the output of now. Returns whether the sound of the others is removed from the
    /// microphone.
    private func installTapAndStart() throws -> Bool {
        engine.stop()
        engine.inputNode.removeTap(onBus: 0)
        try installTapAndStartEngine()
        return echoRemover?.reset() ?? false
    }

    /// The tap uses the format the input node reports now: the echo remover or the
    /// pipeline converts it to the storage format.
    private func installTapAndStartEngine() throws {
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInputDevice }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [target = self.input] buffer, _ in
            target.ingest(borrowing: buffer)
        }
        engine.prepare()
        try engine.start()
    }

    /// `macos.AUDIO_DEVICES_CHANGED`: the engine stops itself when the input device,
    /// the output device or their formats change. It restarts, and the echo canceller
    /// with it. When it cannot start, the microphone is lost and the error
    /// is not ignored: the recording goes on without the user's voice until a later
    /// change of audio devices lets the microphone start again.
    private func restartAfterConfigurationChange() {
        restart(onlyIfLost: false)
    }

    /// While the microphone is lost the stopped engine may not report changes any more,
    /// so a change of the default input device or of the connected audio devices counts
    /// as `macos.AUDIO_DEVICES_CHANGED` too.
    private func retryAfterDeviceChange() {
        restart(onlyIfLost: true)
    }

    private func restart(onlyIfLost: Bool) {
        enum Outcome {
            case started(echoCancelled: Bool, wasLost: Bool)
            case failed(wasLost: Bool)
        }
        var listenerToRemove: AudioObjectPropertyListenerBlock?
        let outcome: Outcome? = lock.withLock {
            guard isRunning, lost || !onlyIfLost else { return nil }
            let wasLost = lost
            do {
                let echoCancelled = try installTapAndStart()
                lost = false
                listenerToRemove = takeDeviceListener()
                return .started(echoCancelled: echoCancelled, wasLost: wasLost)
            } catch {
                engine.inputNode.removeTap(onBus: 0)
                engine.stop()
                lost = true
                addDeviceListeners()
                return .failed(wasLost: wasLost)
            }
        }
        // Removed outside the lock: a listener that is running waits for the lock.
        Self.remove(listenerToRemove)
        switch outcome {
        case .started(let echoCancelled, let wasLost):
            if wasLost { events(.microphoneRestored) }
            events(.echoCancellation(available: echoCancelled))
        case .failed(let wasLost):
            if !wasLost { events(.microphoneLost) }
        case nil:
            break
        }
    }

    // MARK: - Devices while the microphone is lost

    private static let deviceQueue = DispatchQueue(label: "com.larp.LARP.microphone.devices")

    private static let deviceAddresses = [
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain),
        AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal, mElement: kAudioObjectPropertyElementMain),
    ]

    /// Called with the lock held.
    private func addDeviceListeners() {
        guard deviceListener == nil else { return }
        let listener: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            self?.retryAfterDeviceChange()
        }
        deviceListener = listener
        for var address in Self.deviceAddresses {
            AudioObjectAddPropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, Self.deviceQueue, listener)
        }
    }

    /// Called with the lock held. The caller removes the listener with `remove(_:)`
    /// after releasing the lock.
    private func takeDeviceListener() -> AudioObjectPropertyListenerBlock? {
        defer { deviceListener = nil }
        return deviceListener
    }

    private static func remove(_ listener: AudioObjectPropertyListenerBlock?) {
        guard let listener else { return }
        for var address in deviceAddresses {
            AudioObjectRemovePropertyListenerBlock(AudioObjectID(kAudioObjectSystemObject), &address, Self.deviceQueue, listener)
        }
    }
}
