import Foundation
import Synchronization

/// `AudioCapturing` backed by the microphone (`AVAudioEngine`) and the system audio
/// (Core Audio process tap): two tracks written to `mic.caf` and `system.caf`.
final class CallAudioCapture: AudioCapturing {
    private struct Session: Sendable {
        let microphone: MicrophoneCapture
        let system: SystemAudioTap
        let pipelines: [TrackPipeline]
    }

    private let session = Mutex<Session?>(nil)
    private let echoCancellationChanged: @Sendable (Bool) -> Void

    /// `echoCancellationChanged` is called when the microphone starts and after every
    /// restart caused by a change of microphone or audio output, with whether the
    /// sound of the others is removed from the microphone. It may run on any thread.
    init(echoCancellationChanged: @escaping @Sendable (Bool) -> Void = { _ in }) {
        self.echoCancellationChanged = echoCancellationChanged
    }

    func start(into folder: URL, sink: (any AudioBufferSink)?) async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let micPipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)
        let systemPipeline = try TrackPipeline(track: .system, folder: folder, sink: sink)
        let microphone = MicrophoneCapture(pipeline: micPipeline, echoCancellationChanged: echoCancellationChanged)
        let system = SystemAudioTap(pipeline: systemPipeline)
        do {
            try system.start()
            try microphone.start()
        } catch {
            microphone.stop()
            system.stop()
            await micPipeline.finish()
            await systemPipeline.finish()
            throw error
        }
        session.withLock { $0 = Session(microphone: microphone, system: system, pipelines: [micPipeline, systemPipeline]) }
    }

    func stop() async {
        guard let current = session.withLock({ state -> Session? in
            defer { state = nil }
            return state
        }) else { return }
        current.microphone.stop()
        current.system.stop()
        for pipeline in current.pipelines {
            await pipeline.finish()
        }
    }
}
