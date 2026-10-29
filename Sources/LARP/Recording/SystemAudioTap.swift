import AVFoundation
import Foundation
import Synchronization

/// A piece of Core Audio work that is running (a capture, a set of listeners) and that
/// can be stopped.
protocol SystemAudioHandle: AnyObject, Sendable {
    func stop()
}

/// What `SystemAudioTap` needs from Core Audio; replaced in tests by fake devices.
protocol SystemAudioDriver: Sendable {
    /// Starts capturing what the Mac plays, on the current default output device, and
    /// reads the format of the capture again. `deliver` gets every buffer labelled with
    /// the format in effect when it was captured, with the system uptime of its last
    /// frame; the buffer is only valid during the call. `onChange` is called, off the
    /// Core Audio I/O thread, when the capture no longer follows the output (any
    /// `macos.AUDIO_DEVICES_CHANGED` of the system audio); the capture has to be
    /// stopped and started again then.
    func startCapture(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
        onChange: @escaping @Sendable () -> Void
    ) throws -> any SystemAudioHandle

    /// While there is no capture: calls `onChange` when the default output device or the
    /// connected devices change, so that the capture can be started again.
    func observeDevices(onChange: @escaping @Sendable () -> Void) -> any SystemAudioHandle
}

/// Captures everything the Mac plays except LARP itself (through a `SystemAudioDriver`:
/// a Core Audio process tap read through a private aggregate device) and feeds a
/// `TrackPipeline`. Needs only the system audio recording permission, not the screen
/// recording one.
///
/// The capture follows the audio output of the Mac and its sample rate: on every change
/// the capture is stopped and started again on the current output, so every buffer
/// carries the format it was captured with. When it cannot start again the system audio
/// is lost: the track gets silence and the echo canceller no reference, until a later
/// change of audio devices lets the capture start again.
final class SystemAudioTap: @unchecked Sendable {
    struct TapError: LocalizedError, CustomStringConvertible {
        /// The operation that failed when the process tap could not be created, which
        /// is what the system does when the system audio recording permission is missing.
        static let createTapOperation = "create process tap"

        let operation: String
        let status: OSStatus
        /// The tap could not be created: the system audio recording permission is missing.
        var isPermissionDenied: Bool { operation == Self.createTapOperation }
        var description: String { "\(operation) failed (OSStatus \(status))" }
        var errorDescription: String? {
            "Impossibile catturare l'audio di sistema (\(operation), errore \(status)). "
                + "Controllare il permesso «Registrazione audio di sistema» in Impostazioni di Sistema."
        }
    }

    private let pipeline: TrackPipeline
    private let echoRemover: EchoRemover?
    /// Also gets the system audio, as the reference signal of the echo canceller.
    private let reference: (any AudioInput)?
    private let driver: any SystemAudioDriver
    /// Reports `CaptureEvent.systemAudioLost` / `.systemAudioRestored`, and
    /// `.echoCancellation` when the echo canceller starts again with the capture.
    private let events: @Sendable (CaptureEvent) -> Void
    /// Everything that starts or stops the capture runs here, one thing at a time.
    private let queue = DispatchQueue(label: "com.larp.LARP.systemTap.changes", qos: .userInitiated)
    private let lost = Mutex(false)
    /// Whether a change of audio devices waits to be handled: a burst of changes (a new
    /// output changes its sample rate and the tap's format too) starts the capture once.
    private let changePending = Mutex(false)

    // Confined to `queue`.
    private var capture: (any SystemAudioHandle)?
    private var observation: (any SystemAudioHandle)?
    private var isRunning = false

    /// - Parameters:
    ///   - pipeline: the system audio's track.
    ///   - echoRemover: gets the system audio as the reference of the echo canceller;
    ///     `nil` when nothing is removed from the microphone.
    init(
        pipeline: TrackPipeline, echoRemover: EchoRemover? = nil, driver: any SystemAudioDriver = CoreAudioSystemDriver(),
        events: @escaping @Sendable (CaptureEvent) -> Void = { _ in }
    ) {
        self.pipeline = pipeline
        self.echoRemover = echoRemover
        reference = echoRemover?.reference
        self.driver = driver
        self.events = events
    }

    /// Whether the system audio is lost: the capture could not start again after a
    /// change of audio devices. It stays so after `stop()`.
    var isLost: Bool { lost.withLock { $0 } }

    func start() throws {
        try queue.sync {
            // Before the capture: a change that happens while it starts is handled after.
            isRunning = true
            do {
                capture = try startCapture()
            } catch {
                isRunning = false
                throw error
            }
        }
    }

    func stop() {
        queue.sync {
            isRunning = false
            capture?.stop()
            capture = nil
            observation?.stop()
            observation = nil
        }
    }

    // MARK: - Changes of audio devices

    private func startCapture() throws -> any SystemAudioHandle {
        try driver.startCapture(
            deliver: { [pipeline, reference] buffer, arrival in
                pipeline.ingest(borrowing: buffer, arrival: arrival)
                reference?.ingest(borrowing: buffer, arrival: arrival)
            },
            onChange: { [weak self] in self?.devicesChanged() })
    }

    /// Called from Core Audio's own queues.
    private func devicesChanged() {
        guard changePending.withLock({ pending in defer { pending = true }; return !pending }) else { return }
        queue.async { [self] in restart() }
    }

    /// `macos.AUDIO_DEVICES_CHANGED`: Captured → Captured or Captured → Lost, and
    /// Lost → Captured or Lost → Lost.
    private func restart() {
        changePending.withLock { $0 = false }
        guard isRunning else { return }
        capture?.stop()
        capture = nil
        observation?.stop()
        observation = nil

        do {
            capture = try startCapture()
        } catch {
            // Core Audio tells when a device shows up or the default output changes
            // even while nothing is captured.
            observation = driver.observeDevices { [weak self] in self?.devicesChanged() }
            if !lost.withLock({ state in defer { state = true }; return state }) {
                echoRemover?.suspendReference()
                events(.systemAudioLost)
            }
            return
        }
        if lost.withLock({ state in defer { state = false }; return state }) {
            let echoCancelled = echoRemover?.resumeReference()
            events(.systemAudioRestored)
            if let echoCancelled { events(.echoCancellation(available: echoCancelled)) }
        }
    }
}
