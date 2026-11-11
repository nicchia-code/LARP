import AVFoundation
import Foundation

/// Captures the microphone to use with `AVAudioEngine` and feeds a `TrackPipeline`, through the
/// `EchoRemover` when the system audio is recorded.
///
/// The microphone to use is the chosen input device when it is connected, matched by its unique
/// identifier, otherwise the default input device; with no choice ("Predefinito di sistema") it
/// is always the default one. It follows it as it changes during the recording: at every start
/// and restart a new engine is made, on the microphone to use, so the format read from its input
/// node, the tap and the conversion to 16 kHz always use the sample rate the microphone really
/// delivers, and every buffer goes on with the format it was captured with.
///
/// macOS voice processing is never enabled: it would lower the audio of every other
/// app and could change the level of the microphone. The sound of the others that
/// the microphone picks up from the speakers is removed by the `EchoRemover`.
///
/// The capture restarts when the engine reports a change of audio devices, when the connected
/// devices or the default input device change and the microphone to use is no longer the one
/// being captured (so a chosen microphone that is connected again is taken again), and when the
/// user chooses another microphone (`microphoneChoiceChanged()`).
///
/// When the engine cannot start again the microphone is lost: the engine stays stopped and
/// nothing arrives from it. It starts again at the next change of the connected devices or of
/// the microphone to use that lets it.
final class MicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice: L10n.string("Nessun microfono disponibile.")
            }
        }
    }

    /// Why the capture may start again.
    private enum Trigger {
        /// The engine with this identity stopped itself because the audio devices or their formats
        /// changed under it (`macos.AUDIO_DEVICES_CHANGED`).
        case configurationChange(of: ObjectIdentifier)
        /// The connected input devices or the default input device changed.
        case devicesChanged
        /// `user.CHOOSE_MICROPHONE`.
        case choice
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
    private let inputDevices: any InputDevices
    /// The unique identifier of the chosen input device, `nil` for "Predefinito di sistema".
    private let chosenDevice: @Sendable () -> String?
    private let makeEngine: @Sendable (InputDevice?) -> any MicrophoneEngine
    private let lock = NSLock()
    /// The engine of the current start; `nil` before the first one.
    private var engine: (any MicrophoneEngine)?
    /// The unique identifier of the device the engine of the current start reads.
    private var deviceInUse: String?
    private var observation: (any InputDevicesObservation)?
    private var isRunning = false
    private var lost = false

    /// - Parameters:
    ///   - pipeline: the microphone's track.
    ///   - echoRemover: removes the echo of the system audio from the microphone before it
    ///     reaches `pipeline`; `nil` when the system audio is not recorded.
    ///   - events: what the capture tells while the recording runs.
    ///   - inputDevices: the connected input devices; replaced in tests.
    ///   - chosenDevice: the unique identifier of the chosen input device, read at every start
    ///     and restart; `nil` for "Predefinito di sistema".
    ///   - makeEngine: makes the engine of each start, given the chosen device to read, or
    ///     `nil` for the default input device; replaced in tests.
    init(
        pipeline: TrackPipeline, echoRemover: EchoRemover? = nil,
        events: @escaping @Sendable (CaptureEvent) -> Void = { _ in },
        inputDevices: any InputDevices = CoreAudioInputDevices(),
        chosenDevice: @escaping @Sendable () -> String? = { UserDefaults.standard.string(forKey: SettingsKey.microphone) },
        makeEngine: @escaping @Sendable (InputDevice?) -> any MicrophoneEngine = { AVMicrophoneEngine(device: $0) }
    ) {
        input = echoRemover?.microphone ?? pipeline
        self.echoRemover = echoRemover
        self.events = events
        self.inputDevices = inputDevices
        self.chosenDevice = chosenDevice
        self.makeEngine = makeEngine
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
        let observation = inputDevices.observeChanges { [weak self] in
            self?.restart(.devicesChanged)
        }
        lock.withLock { self.observation = observation }
        events(.echoCancellation(available: echoCancelled))
    }

    func stop() {
        let observation: (any InputDevicesObservation)? = lock.withLock {
            isRunning = false
            engine?.stop()
            defer { self.observation = nil }
            return self.observation
        }
        // Cancelled outside the lock: a listener that is running waits for it.
        observation?.cancel()
    }

    /// `user.CHOOSE_MICROPHONE`: another microphone was chosen. A running microphone starts again
    /// on the microphone to use only if that changed; a lost one tries again.
    func microphoneChoiceChanged() {
        restart(.choice)
    }

    /// Starts a new engine on the microphone to use, then the echo canceller from scratch: it
    /// adapts to the microphone and the output of now. Returns whether the sound of the others is
    /// removed from the microphone. Called with the lock held.
    private func installTapAndStart() throws -> Bool {
        engine?.stop()
        let chosenUID = chosenDevice()
        let toUse = inputDevices.microphoneToUse(chosenUID: chosenUID)
        // Only a chosen device is set on the engine; the default one is read by the engine itself.
        let fresh = makeEngine(toUse.flatMap { $0.uid == chosenUID ? $0 : nil })
        engine = fresh
        deviceInUse = toUse?.uid
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
                self?.restart(.configurationChange(of: id))
            })
        CaptureLog.microphoneStarted(tapped: format)
    }

    /// `macos.AUDIO_DEVICES_CHANGED` and `user.CHOOSE_MICROPHONE`: the capture starts again on the
    /// microphone to use. The engine that reports a change of audio devices has stopped itself; a
    /// report of one that was replaced since is ignored. When the capture cannot start again the
    /// microphone is lost and the error is not ignored: the recording goes on without the user's
    /// voice until a later change lets the microphone start again.
    private func restart(_ trigger: Trigger) {
        enum Outcome {
            case started(echoCancelled: Bool, wasLost: Bool)
            case failed(wasLost: Bool)
        }
        let outcome: Outcome? = lock.withLock {
            guard isRunning else { return nil }
            switch trigger {
            case .configurationChange(let reporter):
                if reporter != engine.map(ObjectIdentifier.init) { return nil }
            case .devicesChanged, .choice:
                // A running microphone moves only when the microphone to use changes; a lost one
                // takes every chance.
                if !lost, inputDevices.microphoneToUse(chosenUID: chosenDevice())?.uid == deviceInUse { return nil }
            }
            let wasLost = lost
            do {
                let echoCancelled = try installTapAndStart()
                lost = false
                return .started(echoCancelled: echoCancelled, wasLost: wasLost)
            } catch {
                engine?.stop()
                lost = true
                return .failed(wasLost: wasLost)
            }
        }
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
}
