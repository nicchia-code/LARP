import AVFoundation
import Foundation
import Synchronization

/// A piece of Core Audio work that is running (a capture, a set of listeners) and that
/// can be stopped.
protocol SystemAudioHandle: AnyObject, Sendable {
    func stop()
}

/// The formats of a run of the capture: what the tap reports for itself and the format
/// of the tap's own stream, the one the audio is really read in (and that labels every
/// buffer).
struct SystemAudioFormats: @unchecked Sendable {
    /// `nil` when the tap does not tell it.
    let reported: AVAudioFormat?
    let stream: AVAudioFormat
}

/// A run of the capture on one output device.
protocol SystemAudioRun: SystemAudioHandle {
    var formats: SystemAudioFormats { get }
}

/// What `SystemAudioTap` needs from Core Audio; replaced in tests by fake devices.
protocol SystemAudioDriver: Sendable {
    /// Starts capturing what the Mac plays, on the current default output device. `deliver`
    /// gets every buffer labelled with the format of the tap's own stream, read once the
    /// capture runs, with the system uptime of its last frame; the buffer is only valid
    /// during the call. `onChange` is called, off the Core Audio I/O thread, when the
    /// capture no longer follows the output or the format of its stream differs from the
    /// one that labels the buffers (any `macos.AUDIO_DEVICES_CHANGED` of the system
    /// audio); the capture has to be stopped and started again then. Throws when the
    /// capture cannot start, also when the tap's stream is not found. The buffers it drops
    /// itself (of a run that ended or no longer follows the output, or that cannot be read)
    /// are counted in `drops`.
    func startCapture(
        deliver: @escaping @Sendable (AVAudioPCMBuffer, TimeInterval) -> Void,
        onChange: @escaping @Sendable () -> Void,
        drops: BufferDrops
    ) throws -> any SystemAudioRun

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
            L10n.format(
                "Impossibile catturare l'audio di sistema (%@, errore %d). "
                    + "Controllare il permesso «Registrazione audio di sistema» in Impostazioni di Sistema.",
                operation, Int32(status))
        }
    }

    /// The system audio counts as stalled when no audio at all (silence included) has
    /// arrived for this long.
    static let defaultStallTimeout: TimeInterval = 2

    /// The time of the last delivery, from the I/O thread without a lock.
    private final class Heartbeat: Sendable {
        private let last = Atomic<UInt64>(DispatchTime.now().uptimeNanoseconds)

        func beat() { last.store(DispatchTime.now().uptimeNanoseconds, ordering: .relaxed) }

        func secondsSinceLast() -> TimeInterval {
            let now = DispatchTime.now().uptimeNanoseconds
            return Double(now &- min(last.load(ordering: .relaxed), now)) / 1_000_000_000
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
    private var capture: (any SystemAudioRun)?
    private var observation: (any SystemAudioHandle)?
    private var isRunning = false
    private var watch: DispatchSourceTimer?
    /// When the last buffer was delivered, written by the I/O thread.
    private let heartbeat = Heartbeat()
    /// How long without audio counts as stalled.
    private let stallTimeout: TimeInterval

    /// - Parameters:
    ///   - pipeline: the system audio's track.
    ///   - echoRemover: gets the system audio as the reference of the echo canceller;
    ///     `nil` when nothing is removed from the microphone.
    init(
        pipeline: TrackPipeline, echoRemover: EchoRemover? = nil, driver: any SystemAudioDriver = CoreAudioSystemDriver(),
        stallTimeout: TimeInterval = SystemAudioTap.defaultStallTimeout,
        events: @escaping @Sendable (CaptureEvent) -> Void = { _ in }
    ) {
        self.pipeline = pipeline
        self.echoRemover = echoRemover
        reference = echoRemover?.reference
        self.driver = driver
        self.stallTimeout = stallTimeout
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
            disarmWatch()
            capture?.stop()
            capture = nil
            observation?.stop()
            observation = nil
        }
    }

    // MARK: - Changes of audio devices

    private func startCapture() throws -> any SystemAudioRun {
        // The wait for audio starts again at every start and restart of the capture.
        heartbeat.beat()
        let run = try driver.startCapture(
            deliver: { [pipeline, reference, heartbeat] buffer, arrival in
                heartbeat.beat()
                pipeline.ingest(borrowing: buffer, arrival: arrival)
                reference?.ingest(borrowing: buffer, arrival: arrival)
            },
            onChange: { [weak self] in self?.devicesChanged() },
            drops: pipeline.drops)
        CaptureLog.systemAudioStarted(run.formats)
        armWatch()
        return run
    }

    /// Called from Core Audio's own queues.
    private func devicesChanged() {
        guard changePending.withLock({ pending in defer { pending = true }; return !pending }) else { return }
        queue.async { [self] in restart() }
    }

    // MARK: - Audio that stops arriving

    /// Starts the wait for audio again: `time.SYSTEM_AUDIO_STALLED` fires when no buffer
    /// has been delivered for `stallTimeout`. Runs on `queue`, never on the I/O thread.
    private func armWatch() {
        disarmWatch()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.setEventHandler { [weak self] in self?.checkStall() }
        timer.schedule(deadline: .now() + stallTimeout)
        timer.resume()
        watch = timer
    }

    private func disarmWatch() {
        watch?.cancel()
        watch = nil
    }

    private func checkStall() {
        guard isRunning, capture != nil else { return }
        let silent = heartbeat.secondsSinceLast()
        guard silent >= stallTimeout else {
            watch?.schedule(deadline: .now() + (stallTimeout - silent))
            return
        }
        // Like a change of audio devices: the capture starts again from scratch, and when it
        // cannot, the system audio is lost.
        disarmWatch()
        devicesChanged()
    }

    /// `macos.AUDIO_DEVICES_CHANGED`: Captured → Captured or Captured → Lost, and
    /// Lost → Captured or Lost → Lost.
    private func restart() {
        changePending.withLock { $0 = false }
        guard isRunning else { return }
        disarmWatch()
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
