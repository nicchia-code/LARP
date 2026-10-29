import Foundation
import Synchronization

/// The microphone of a recording.
protocol MicrophoneSource: Sendable {
    func start() throws
    func stop()
    /// Whether the microphone is lost: it could not start again after a change of
    /// audio devices and nothing arrives from it.
    var isLost: Bool { get }
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
    }

    private let session = Mutex<Session?>(nil)
    private let events: EventHandler
    private let makeMicrophone: @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any MicrophoneSource
    private let makeSystem: @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any SystemAudioSource

    /// `events` is called while the recording runs, from any thread. The two factories
    /// make the sources of the tracks; they are replaced in tests.
    init(
        events: @escaping EventHandler = { _ in },
        makeMicrophone: @escaping @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any MicrophoneSource = {
            MicrophoneCapture(pipeline: $0, echoRemover: $1, events: $2)
        },
        makeSystem: @escaping @Sendable (TrackPipeline, EchoRemover?, @escaping EventHandler) -> any SystemAudioSource = {
            SystemAudioTap(pipeline: $0, echoRemover: $1, events: $2)
        }
    ) {
        self.events = events
        self.makeMicrophone = makeMicrophone
        self.makeSystem = makeSystem
    }

    func start(into folder: URL, sink: (any AudioBufferSink)?, systemAudio policy: SystemAudioPolicy) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let micPipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)
        let systemPipeline = try TrackPipeline(track: .system, folder: folder, sink: sink)
        // The system audio is the reference of the echo canceller: it is made first, so
        // that the system audio feeds it from the start.
        let echoRemover = EchoRemover(output: micPipeline)
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
                echoRemover: echoRemoverInUse)
        }
        if let systemFailure {
            events(.systemAudioUnavailable(permissionMissing: (systemFailure as? SystemAudioTap.TapError)?.isPermissionDenied ?? false))
        }
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
        // A microphone that is still lost has nothing to say for the rest of the
        // recording: the track gets silence up to now.
        await current.micPipeline.finish(silenceUntil: current.microphone.isLost ? stoppedAt : nil)
        // The same for the system audio that is still lost.
        await current.systemPipeline.finish(silenceUntil: current.system.isLost ? stoppedAt : nil)
    }
}
