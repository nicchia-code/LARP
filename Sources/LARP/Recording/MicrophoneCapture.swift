import AVFoundation
import CoreAudio
import Foundation

/// Captures the default input device with `AVAudioEngine` and feeds a `TrackPipeline`,
/// through the `EchoRemover` when the system audio is recorded. Follows the default
/// device when it changes during the recording: at every start and restart a new engine
/// is made, so the format read from its input node, the tap and the conversion to 16 kHz
/// always use the sample rate the microphone really delivers, and every buffer goes on
/// with the format it was captured with.
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
    private let makeEngine: @Sendable () -> any MicrophoneEngine
    private let lock = NSLock()
    /// The engine of the current start; `nil` before the first one.
    private var engine: (any MicrophoneEngine)?
    private var deviceListener: AudioObjectPropertyListenerBlock?
    private var isRunning = false
    private var lost = false

    /// - Parameters:
    ///   - pipeline: the microphone's track.
    ///   - echoRemover: removes the echo of the system audio from the microphone before it
    ///     reaches `pipeline`; `nil` when the system audio is not recorded.
    ///   - events: what the capture tells while the recording runs.
    ///   - makeEngine: makes the engine of each start; replaced in tests.
    init(
        pipeline: TrackPipeline, echoRemover: EchoRemover? = nil,
        events: @escaping @Sendable (CaptureEvent) -> Void = { _ in },
        makeEngine: @escaping @Sendable () -> any MicrophoneEngine = { AVMicrophoneEngine() }
    ) {
        input = echoRemover?.microphone ?? pipeline
        self.echoRemover = echoRemover
        self.makeEngine = makeEngine
        self.events = events
    }

    /// Whether macOS voice processing is on for the input node: never, but tests check it.
    var isVoiceProcessingEnabled: Bool { lock.withLock { engine?.isVoiceProcessingEnabled ?? false } }

    /// Whether the microphone is lost. It stays so after `stop()`.
    var isLost: Bool { lock.withLock { lost } }

    func start() throws {
        let echoCancelled: Bool = try lock.withLock {
            let echoCancelled = try installTapAndStart()
            isRunning = true
            return echoCancelled
        }
        events(.echoCancellation(available: echoCancelled))
    }

    func stop() {
        let listener: AudioObjectPropertyListenerBlock? = lock.withLock {
            isRunning = false
            engine?.stop()
            return takeDeviceListener()
        }
        Self.remove(listener)
    }

    /// Starts a new engine, then the echo canceller from scratch: it adapts to the
    /// microphone and the output of now. Returns whether the sound of the others is
    /// removed from the microphone. Called with the lock held.
    private func installTapAndStart() throws -> Bool {
        engine?.stop()
        let fresh = makeEngine()
        engine = fresh
        try start(fresh)
        return echoRemover?.reset() ?? false
    }

    /// The tap uses the format the input node of the new engine reports now: the echo
    /// remover or the pipeline converts every buffer from it to the storage format.
    private func start(_ engine: any MicrophoneEngine) throws {
        let format = engine.inputFormat()
        guard format.sampleRate > 0, format.channelCount > 0 else { throw CaptureError.noInputDevice }
        let id = ObjectIdentifier(engine)
        try engine.start(
            format: format,
            deliver: { [target = input] buffer, arrival in
                target.ingest(borrowing: buffer, arrival: arrival)
            },
            onConfigurationChange: { [weak self] in
                self?.restartAfterConfigurationChange(of: id)
            })
    }

    /// `macos.AUDIO_DEVICES_CHANGED`: the engine stops itself when the input device,
    /// the output device or their formats change. It restarts, and the echo canceller
    /// with it. When it cannot start, the microphone is lost and the error
    /// is not ignored: the recording goes on without the user's voice until a later
    /// change of audio devices lets the microphone start again.
    private func restartAfterConfigurationChange(of engine: ObjectIdentifier) {
        restart(onlyIfLost: false, engine: engine)
    }

    /// While the microphone is lost the stopped engine may not report changes any more,
    /// so a change of the default input device or of the connected audio devices counts
    /// as `macos.AUDIO_DEVICES_CHANGED` too.
    private func retryAfterDeviceChange() {
        restart(onlyIfLost: true, engine: nil)
    }

    /// `engine` is the engine that reported the change: a report of one that was
    /// replaced since is ignored.
    private func restart(onlyIfLost: Bool, engine reporter: ObjectIdentifier?) {
        enum Outcome {
            case started(echoCancelled: Bool, wasLost: Bool)
            case failed(wasLost: Bool)
        }
        var listenerToRemove: AudioObjectPropertyListenerBlock?
        let outcome: Outcome? = lock.withLock {
            guard isRunning, lost || !onlyIfLost else { return nil }
            if let reporter, reporter != engine.map(ObjectIdentifier.init) { return nil }
            let wasLost = lost
            do {
                let echoCancelled = try installTapAndStart()
                lost = false
                listenerToRemove = takeDeviceListener()
                return .started(echoCancelled: echoCancelled, wasLost: wasLost)
            } catch {
                engine?.stop()
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
