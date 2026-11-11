import Foundation
import Synchronization

/// The microphone of a recording.
protocol MicrophoneSource: Sendable {
    func start() throws
    func stop()
    /// Whether the microphone is lost: it could not start again after a change of
    /// audio devices and nothing arrives from it.
    var isLost: Bool { get }

    /// `user.CHOOSE_MICROPHONE`: starts again on the microphone to use if it changed, or tries
    /// again when lost.
    func microphoneChoiceChanged()
}

/// The system audio of a recording.
protocol SystemAudioSource: Sendable {
    func start() throws
    func stop()
    /// Whether the system audio is lost: it could not start again after a change of
    /// audio devices and nothing arrives from it.
    var isLost: Bool { get }
}

extension MicrophoneCapture: MicrophoneSource {}
extension SystemAudioTap: SystemAudioSource {}

/// `AudioCapturing` backed by the microphone (`AVAudioEngine`) and the system audio
/// (Core Audio process tap): two tracks written to `mic.caf` and `system.caf`.
final class CallAudioCapture: AudioCapturing {
    typealias EventHandler = @Sendable (CaptureEvent) -> Void

    private struct Session: Sendable {
        let microphone: any MicrophoneSource
        let system: any SystemAudioSource
        let micPipeline: TrackPipeline
        let systemPipeline: TrackPipeline
        let echoRemover: EchoRemover?
        /// Whether the system audio started: its track is only filled up to the end when it did.
        let recordsSystemAudio: Bool
        /// The system uptime at which the recording started.
        let startedAt: TimeInterval
    }

    private let session = Mutex<Session?>(nil)
    private let events: EventHandler
    private let levels: (@Sendable (AudioTrack, TrackLevel) -> Void)?
    private let makeMicrophone: @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any MicrophoneSource
    private let makeSystem: @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any SystemAudioSource

    /// `events` is called while the recording runs, from any thread. `levels` gets the level of
    /// every track every 50 ms, from the private queue of the track. The two factories
    /// make the sources of the tracks; they are replaced in tests.
    init(
        events: @escaping EventHandler = { _ in },
        levels: (@Sendable (AudioTrack, TrackLevel) -> Void)? = nil,
        makeMicrophone: @escaping @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any MicrophoneSource = {
            MicrophoneCapture(pipeline: $0, echoRemover: $1, events: $2)
        },
        makeSystem: @escaping @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any SystemAudioSource = {
            SystemAudioTap(pipeline: $0, echoRemover: $1, events: $2)
        }
    ) {
        self.events = events
        self.levels = levels
        self.makeMicrophone = makeMicrophone
        self.makeSystem = makeSystem
    }

    func start(into folder: URL, sink: (any AudioBufferSink)?, systemAudio policy: SystemAudioPolicy) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        // Both tracks start now, when their files are created: a time in either of them is the
        // time since the recording started.
        let startedAt = ProcessInfo.processInfo.systemUptime
        let micPipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink, levels: levels, startUptime: startedAt)
        let systemPipeline = try TrackPipeline(track: .system, folder: folder, sink: sink, levels: levels, startUptime: startedAt)
        // The system audio is the reference of the echo canceller: it is made first, so
        // that the system audio feeds it from the start.
        let echoRemover = EchoRemover(output: micPipeline, referenceDrops: systemPipeline.drops)
        let system = makeSystem(systemPipeline, echoRemover, events)

        // Without the system audio (only possible when it is optional) there is no
        // reference and nothing to remove from the microphone: the microphone is
        // recorded as captured and `system.caf` stays empty.
        var systemFailure: (any Error)?
        do {
            try system.start()
        } catch {
            system.stop()
            guard policy == .optional else {
                await micPipeline.finish()
                await systemPipeline.finish()
                throw error
            }
            systemFailure = error
        }
        let recordsSystemAudio = systemFailure == nil
        let echoRemoverInUse = recordsSystemAudio ? echoRemover : nil

        let events = events
        let microphone = makeMicrophone(micPipeline, echoRemoverInUse) { event in
            // Nothing is removed from the microphone without the system audio, or while it is lost.
            if case .echoCancellation = event, !recordsSystemAudio || system.isLost { return }
            events(event)
        }
        do {
            try microphone.start()
        } catch {
            microphone.stop()
            system.stop()
            await echoRemover.finish()
            await micPipeline.finish()
            await systemPipeline.finish()
            throw error
        }
        session.withLock {
            $0 = Session(
                microphone: microphone, system: system, micPipeline: micPipeline, systemPipeline: systemPipeline,
                echoRemover: echoRemoverInUse, recordsSystemAudio: recordsSystemAudio, startedAt: startedAt)
        }
        if let systemFailure {
            events(.systemAudioUnavailable(permissionMissing: (systemFailure as? SystemAudioTap.TapError)?.isPermissionDenied ?? false))
        }
    }

    func setPaused(_ paused: Bool) {
        guard let current = session.withLock({ $0 }) else { return }
        current.micPipeline.setPaused(paused)
        current.systemPipeline.setPaused(paused)
    }

    func microphoneChoiceChanged() {
        session.withLock { $0 }?.microphone.microphoneChoiceChanged()
    }

    func stop() async {
        guard let current = session.withLock({ state -> Session? in
            defer { state = nil }
            return state
        }) else { return }
        let stoppedAt = ProcessInfo.processInfo.systemUptime
        current.microphone.stop()
        current.system.stop()
        // What the echo remover still holds goes to the track first.
        await current.echoRemover?.finish()
        // Every track that was written is filled with silence up to the end of the recording,
        // whether its source is lost, stopped delivering audio or is still running; a system
        // audio track that never started stays empty.
        let micStats = await current.micPipeline.finish(silenceUntil: stoppedAt)
        let systemStats = await current.systemPipeline.finish(silenceUntil: current.recordsSystemAudio ? stoppedAt : nil)
        let recordingSeconds = stoppedAt - current.startedAt
        CaptureLog.trackStopped(
            .microphone, stats: micStats, recordingSeconds: recordingSeconds, drops: current.micPipeline.drops.counts)
        if current.recordsSystemAudio {
            CaptureLog.trackStopped(
                .system, stats: systemStats, recordingSeconds: recordingSeconds, drops: current.systemPipeline.drops.counts)
        }
    }
}
