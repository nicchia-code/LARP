import AVFoundation
import Foundation

/// Captures the microphone to use directly from its input device with Core Audio, input only
/// (`HALMicrophoneUnit`), and feeds a `TrackPipeline`, through the `EchoRemover` when the system
/// audio is recorded.
///
/// The microphone to use is the chosen input device when it is connected, matched by its unique
/// identifier, otherwise the default input device; with no choice ("Predefinito di sistema") it
/// is always the default one. At every start and restart a new unit is made, on the microphone to
/// use, so the format read from the input side of the device, and the conversion to 16 kHz, always
/// use the sample rate the microphone really delivers, and every buffer goes on with the format it
/// was captured with.
///
/// macOS voice processing is never enabled: it would lower the audio of every other
/// app and could change the level of the microphone. The sound of the others that
/// the microphone picks up from the speakers is removed by the `EchoRemover`.
///
/// The microphone is reopened only when the microphone to use changes (the connected devices or
/// the default input device change, so a chosen microphone that is connected again is taken again,
/// or the user chooses another one: `microphoneChoiceChanged()`), when its format changes, or when
/// it disappears. A change of the default output or of its format never reopens it: it only makes
/// a new echo canceller, so the microphone goes on without a gap.
///
/// When the unit cannot start again the microphone is lost: the unit stays stopped and nothing
/// arrives from it. It starts again at the next change of the connected devices or of the
/// microphone to use that lets it.
final class MicrophoneCapture: @unchecked Sendable {
    enum CaptureError: LocalizedError {
        case noInputDevice

        var errorDescription: String? {
            switch self {
            case .noInputDevice: L10n.string("Nessun microfono disponibile.")
            }
        }
    }

    /// Why the capture may start again, or what changes under it.
    private enum Trigger {
        /// The unit with this identity reports that its microphone changed its format or is gone
        /// (`macos.AUDIO_DEVICES_CHANGED`).
        case unitChanged(of: ObjectIdentifier, MicrophoneUnitChange)
        /// The connected input devices or the default input device changed.
        case devicesChanged
        /// `user.CHOOSE_MICROPHONE`.
        case choice
    }

    /// Where the microphone audio goes: the echo remover, or the track itself when the
    /// system audio is not recorded and there is nothing to remove.
    private let input: any AudioInput
    private let echoRemover: EchoRemover?
    /// Reports `CaptureEvent.echoCancellation` after the unit has started, at the
    /// start and after every restart, and after every change of the output alone
    /// (`true` when the echo canceller is running, so the sound of the others is
    /// removed from the microphone, `false` when the capture runs without it), and
    /// `.microphoneLost` / `.microphoneRestored` when the microphone goes and comes back.
    private let events: @Sendable (CaptureEvent) -> Void
    private let inputDevices: any InputDevices
    private let outputDevices: any OutputDevices
    /// The unique identifier of the chosen input device, `nil` for "Predefinito di sistema".
    private let chosenDevice: @Sendable () -> String?
    private let makeUnit: @Sendable (InputDevice?) -> any MicrophoneUnit
    private let lock = NSLock()
    /// The unit of the current start; `nil` before the first one.
    private var unit: (any MicrophoneUnit)?
    /// The unique identifier of the device the unit of the current start reads.
    private var deviceInUse: String?
    private var devicesObservation: (any InputDevicesObservation)?
    private var outputObservation: (any InputDevicesObservation)?
    /// The listeners on the device the unit reads.
    private var unitObservation: (any InputDevicesObservation)?
    /// Observations to cancel once the lock is released: a listener that is running waits for it.
    private var retired: [any InputDevicesObservation] = []
    private var isRunning = false
    private var lost = false

    /// - Parameters:
    ///   - pipeline: the microphone's track.
    ///   - echoRemover: removes the echo of the system audio from the microphone before it
    ///     reaches `pipeline`; `nil` when the system audio is not recorded.
    ///   - events: what the capture tells while the recording runs.
    ///   - inputDevices: the connected input devices; replaced in tests.
    ///   - outputDevices: the default output; replaced in tests.
    ///   - chosenDevice: the unique identifier of the chosen input device, read at every start
    ///     and restart; `nil` for "Predefinito di sistema".
    ///   - makeUnit: makes the unit of each start, given the chosen device to read, or
    ///     `nil` for the default input device; replaced in tests.
    init(
        pipeline: TrackPipeline, echoRemover: EchoRemover? = nil,
        events: @escaping @Sendable (CaptureEvent) -> Void = { _ in },
        inputDevices: any InputDevices = CoreAudioInputDevices(),
        outputDevices: any OutputDevices = CoreAudioOutputDevices(),
        chosenDevice: @escaping @Sendable () -> String? = { UserDefaults.standard.string(forKey: SettingsKey.microphone) },
        makeUnit: @escaping @Sendable (InputDevice?) -> any MicrophoneUnit = { HALMicrophoneUnit(device: $0) }
    ) {
        input = echoRemover?.microphone ?? pipeline
        self.echoRemover = echoRemover
        self.events = events
        self.inputDevices = inputDevices
        self.outputDevices = outputDevices
        self.chosenDevice = chosenDevice
        self.makeUnit = makeUnit
    }

    /// Whether macOS voice processing is on for the input: never, but tests check it.
    var isVoiceProcessingEnabled: Bool { lock.withLock { unit?.isVoiceProcessingEnabled ?? false } }

    /// Whether the microphone is lost. It stays so after `stop()`.
    var isLost: Bool { lock.withLock { lost } }

    func start() throws {
        let startResult = withLockThenCancel {
            Result {
                let started = try installAndStart()
                isRunning = true
                return started
            }
        }
        let started = try startResult.get()
        let devices = inputDevices.observeChanges { [weak self] in
            self?.restart(.devicesChanged)
        }
        let output = outputDevices.observeChanges { [weak self] in
            self?.outputChanged()
        }
        lock.withLock {
            devicesObservation = devices
            outputObservation = output
        }
        CaptureLog.microphoneStarted(tapped: started.format)
        events(.echoCancellation(available: started.echoCancelled))
    }

    func stop() {
        withLockThenCancel {
            isRunning = false
            unit?.stop()
            if let unitObservation { retired.append(unitObservation) }
            unitObservation = nil
            if let devicesObservation { retired.append(devicesObservation) }
            devicesObservation = nil
            if let outputObservation { retired.append(outputObservation) }
            outputObservation = nil
        }
    }

    /// `user.CHOOSE_MICROPHONE`: another microphone was chosen. A running microphone starts again
    /// on the microphone to use only if that changed; a lost one tries again.
    func microphoneChoiceChanged() {
        restart(.choice)
    }

    /// Runs `body` with the lock held, then cancels the observations it retired, outside the lock.
    private func withLockThenCancel<T>(_ body: () -> T) -> T {
        let (result, cancelled): (T, [any InputDevicesObservation]) = lock.withLock {
            let result = body()
            defer { retired = [] }
            return (result, retired)
        }
        for observation in cancelled { observation.cancel() }
        return result
    }

    /// What a start of the unit tells once the lock is released.
    private struct Started {
        let format: AVAudioFormat
        let echoCancelled: Bool
    }

    /// Starts a new unit on the microphone to use, then the echo canceller from scratch: it
    /// adapts to the microphone and the output of now. Called with the lock held.
    private func installAndStart() throws -> Started {
        unit?.stop()
        if let unitObservation { retired.append(unitObservation) }
        unitObservation = nil
        let chosenUID = chosenDevice()
        let toUse = inputDevices.microphoneToUse(chosenUID: chosenUID)
        // Only a chosen device is set on the unit; the default one is read by the unit itself.
        let fresh = makeUnit(toUse.flatMap { $0.uid == chosenUID ? $0 : nil })
        unit = fresh
        deviceInUse = toUse?.uid
        // The format of the input side of the device of now: the echo remover or the pipeline
        // converts every buffer from it to the storage format.
        guard let format = fresh.inputFormat(), format.sampleRate > 0, format.channelCount > 0 else {
            throw CaptureError.noInputDevice
        }
        try fresh.start(
            format: format,
            deliver: { [target = input] buffer, arrival in
                target.ingest(borrowing: buffer, arrival: arrival)
            })
        let id = ObjectIdentifier(fresh)
        unitObservation = fresh.observeChanges { [weak self] change in
            self?.restart(.unitChanged(of: id, change))
        }
        return Started(format: format, echoCancelled: echoRemover?.reset() ?? false)
    }

    /// The default output or its sample rate changed: the microphone is not reopened and its
    /// capture goes on without a gap, only the echo canceller is made again, because the echo
    /// path learned belongs to the output of before. Does nothing without an echo remover, or
    /// while the microphone is lost (it gets a new canceller when it comes back).
    private func outputChanged() {
        guard let echoRemover else { return }
        let echoCancelled: Bool? = lock.withLock {
            guard isRunning, !lost else { return nil }
            return echoRemover.reset()
        }
        guard let echoCancelled else { return }
        CaptureLog.echoCancellerRenewed(available: echoCancelled)
        events(.echoCancellation(available: echoCancelled))
    }

    /// `macos.AUDIO_DEVICES_CHANGED` and `user.CHOOSE_MICROPHONE`: the capture starts again on the
    /// microphone to use. A report of a unit that was replaced since is ignored. When the capture
    /// cannot start again the microphone is lost and the error is not ignored: the recording goes
    /// on without the user's voice until a later change lets the microphone start again.
    private func restart(_ trigger: Trigger) {
        enum Outcome {
            case started(Started, wasLost: Bool)
            case failed(wasLost: Bool)
        }
        var reason = CaptureLog.MicrophoneRestartReason.microphoneToUseChanged
        let outcome: Outcome? = withLockThenCancel {
            guard isRunning else { return nil }
            switch trigger {
            case .unitChanged(let reporter, let change):
                if reporter != unit.map(ObjectIdentifier.init) { return nil }
                reason = change == .gone ? .microphoneGone : .formatChanged
            case .devicesChanged, .choice:
                // A running microphone moves only when the microphone to use changes; a lost one
                // takes every chance.
                let toUse = inputDevices.microphoneToUse(chosenUID: chosenDevice())?.uid
                if !lost, toUse == deviceInUse { return nil }
                if case .choice = trigger {
                    reason = .chosenByUser
                } else if !lost, let deviceInUse, !inputDevices.connected().contains(where: { $0.uid == deviceInUse }) {
                    reason = .microphoneGone
                }
            }
            let wasLost = lost
            do {
                let started = try installAndStart()
                lost = false
                return .started(started, wasLost: wasLost)
            } catch {
                unit?.stop()
                lost = true
                return .failed(wasLost: wasLost)
            }
        }
        guard let outcome else { return }
        CaptureLog.microphoneRestarting(reason)
        switch outcome {
        case .started(let started, let wasLost):
            CaptureLog.microphoneStarted(tapped: started.format)
            if wasLost {
                CaptureLog.microphoneRestored()
                events(.microphoneRestored)
            }
            events(.echoCancellation(available: started.echoCancelled))
        case .failed(let wasLost):
            if !wasLost {
                CaptureLog.microphoneLost()
                events(.microphoneLost)
            }
        }
    }
}
