import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import LARP

@Suite("Call audio capture")
struct CallAudioCaptureTests {
    private struct SourceFailure: Error {}

    /// A microphone that starts (or not) and reports `startEvents` when it does.
    private final class FakeMicrophone: MicrophoneSource {
        private let failsToStart: Bool
        private let startEvents: [CaptureEvent]
        private let emit: @Sendable (CaptureEvent) -> Void
        private let pipeline: TrackPipeline
        private let lost: Bool
        private let state = Mutex((started: false, stopped: false))

        init(
            pipeline: TrackPipeline, failsToStart: Bool, lost: Bool, startEvents: [CaptureEvent],
            emit: @escaping @Sendable (CaptureEvent) -> Void
        ) {
            self.pipeline = pipeline
            self.failsToStart = failsToStart
            self.lost = lost
            self.startEvents = startEvents
            self.emit = emit
        }

        var isStopped: Bool { state.withLock { $0.stopped } }
        var isLost: Bool { lost }

        /// Starts and delivers one second of audio that arrived two seconds ago.
        func start() throws {
            if failsToStart { throw SourceFailure() }
            state.withLock { $0.started = true }
            let frames = AVAudioFrameCount(AudioFormats.storageSampleRate)
            if let buffer = AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames) {
                buffer.frameLength = frames
                buffer.floatChannelData![0].update(repeating: 0.1, count: Int(frames))
                pipeline.ingest(borrowing: buffer, arrival: ProcessInfo.processInfo.systemUptime - 2)
            }
            for event in startEvents { emit(event) }
        }

        func stop() { state.withLock { $0.stopped = true } }
    }

    private final class FakeSystem: SystemAudioSource {
        private let failure: (any Error)?
        private let lost: Bool
        private let state = Mutex((started: false, stopped: false))

        init(failure: (any Error)?, lost: Bool = false) {
            self.failure = failure
            self.lost = lost
        }

        var isLost: Bool { lost }
        var isStarted: Bool { state.withLock { $0.started } }
        var isStopped: Bool { state.withLock { $0.stopped } }

        /// The system audio's track, set when the capture makes this source.
        let pipeline = Mutex<TrackPipeline?>(nil)

        /// A source that is lost has delivered one second of audio that arrived two seconds
        /// ago, and nothing since.
        func start() throws {
            if let failure { throw failure }
            state.withLock { $0.started = true }
            guard lost, let pipeline = pipeline.withLock({ $0 }) else { return }
            let frames = AVAudioFrameCount(AudioFormats.storageSampleRate)
            if let buffer = AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames) {
                buffer.frameLength = frames
                buffer.floatChannelData![0].update(repeating: 0.1, count: Int(frames))
                pipeline.ingest(borrowing: buffer, arrival: ProcessInfo.processInfo.systemUptime - 2)
            }
        }

        func stop() { state.withLock { $0.stopped = true } }
    }

    private final class Box<Value: Sendable>: Sendable {
        private let value: Mutex<Value>
        init(_ value: Value) { self.value = Mutex(value) }
        func withLock<R>(_ body: (inout Value) -> sending R) -> sending R { value.withLock { body(&$0) } }
    }

    private struct Rig {
        let capture: CallAudioCapture
        let events: Box<[CaptureEvent]>
        let system: FakeSystem
        let microphone: Box<FakeMicrophone?>
        /// Whether each microphone made got an echo remover.
        let echoRemoverGiven: Box<[Bool]>
        let folder: URL

        func receivedEvents() -> [CaptureEvent] { events.withLock { $0 } }
    }

    /// A capture over fake sources. The microphone reports `echoCancellation(false)`
    /// when it starts, as one that cannot remove the sound of the others.
    private func rig(
        systemFailure: (any Error)? = nil, microphoneFails: Bool = false, microphoneLost: Bool = false,
        systemLost: Bool = false
    ) throws -> Rig {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-capture-\(UUID().uuidString)")
        let events = Box<[CaptureEvent]>([])
        let system = FakeSystem(failure: systemFailure, lost: systemLost)
        let microphone = Box<FakeMicrophone?>(nil)
        let echoRemoverGiven = Box<[Bool]>([])
        let capture = CallAudioCapture(
            events: { event in events.withLock { $0.append(event) } },
            makeMicrophone: { pipeline, echoRemover, emit in
                echoRemoverGiven.withLock { $0.append(echoRemover != nil) }
                let fake = FakeMicrophone(
                    pipeline: pipeline, failsToStart: microphoneFails, lost: microphoneLost,
                    startEvents: [.echoCancellation(available: false)], emit: emit)
                microphone.withLock { $0 = fake }
                return fake
            },
            makeSystem: { pipeline, _, _ in
                system.pipeline.withLock { $0 = pipeline }
                return system
            })
        return Rig(
            capture: capture, events: events, system: system, microphone: microphone,
            echoRemoverGiven: echoRemoverGiven, folder: folder)
    }

    private func permissionDenied() -> SystemAudioTap.TapError {
        SystemAudioTap.TapError(operation: SystemAudioTap.TapError.createTapOperation, status: -1)
    }

    @Test("with the system audio the echo report of the microphone goes through and system.caf is created")
    func systemAudioRecorded() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .required)
        await rig.capture.stop()

        #expect(rig.system.isStarted)
        #expect(rig.receivedEvents() == [.echoCancellation(available: false)])
        #expect(FileManager.default.fileExists(atPath: AudioTrack.system.fileURL(in: rig.folder).path))
    }

    @Test("the microphone gets the echo remover only when the system audio is recorded")
    func echoRemoverOnlyWithSystemAudio() async throws {
        let withSystem = try rig()
        let withoutSystem = try rig(systemFailure: SourceFailure())
        defer {
            try? FileManager.default.removeItem(at: withSystem.folder)
            try? FileManager.default.removeItem(at: withoutSystem.folder)
        }

        try await withSystem.capture.start(into: withSystem.folder, sink: nil, systemAudio: .optional)
        await withSystem.capture.stop()
        try await withoutSystem.capture.start(into: withoutSystem.folder, sink: nil, systemAudio: .optional)
        await withoutSystem.capture.stop()

        #expect(withSystem.echoRemoverGiven.withLock { $0 } == [true])
        #expect(withoutSystem.echoRemoverGiven.withLock { $0 } == [false])
    }

    @Test("a required system audio that does not start stops the recording and leaves nothing running")
    func requiredSystemAudioFails() async throws {
        let rig = try rig(systemFailure: permissionDenied())
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        await #expect(throws: SystemAudioTap.TapError.self) {
            try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .required)
        }

        #expect(rig.system.isStopped)
        #expect(rig.microphone.withLock { $0 } == nil)
        #expect(rig.receivedEvents().isEmpty)
    }

    @Test("an optional system audio without permission records the microphone only and says why")
    func optionalWithoutPermission() async throws {
        let rig = try rig(systemFailure: permissionDenied())
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .optional)
        await rig.capture.stop()

        #expect(rig.receivedEvents() == [.systemAudioUnavailable(permissionMissing: true)])
        #expect(rig.microphone.withLock { $0 }?.isStopped == true)
    }

    @Test("an optional system audio whose tap or aggregate device does not start records the microphone only, without the permission button")
    func optionalWithTapFailure() async throws {
        let rig = try rig(systemFailure: SystemAudioTap.TapError(operation: "create aggregate device", status: -1))
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .optional)
        await rig.capture.stop()

        #expect(rig.receivedEvents() == [.systemAudioUnavailable(permissionMissing: false)])
    }

    @Test("without the system audio no echo warning is reported, even when the microphone cannot remove the echo")
    func noEchoReportWithoutSystemAudio() async throws {
        let rig = try rig(systemFailure: SourceFailure())
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .optional)
        await rig.capture.stop()

        #expect(!rig.receivedEvents().contains(.echoCancellation(available: false)))
        #expect(!rig.receivedEvents().contains(.echoCancellation(available: true)))
    }

    @Test("system.caf is created and stays empty when the system audio is not recorded")
    func systemFileStaysEmpty() async throws {
        let rig = try rig(systemFailure: permissionDenied())
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .optional)
        await rig.capture.stop()

        let url = AudioTrack.system.fileURL(in: rig.folder)
        #expect(FileManager.default.fileExists(atPath: url.path))
        #expect(AudioFileDuration.seconds(of: url) == nil)
    }

    @Test("a microphone that cannot start fails the start, whatever the system audio policy")
    func microphoneFails() async throws {
        let rig = try rig(microphoneFails: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        await #expect(throws: SourceFailure.self) {
            try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .optional)
        }

        #expect(rig.system.isStopped)
        #expect(rig.receivedEvents().isEmpty)
    }

    @Test("a microphone still lost when the recording ends gets silence in mic.caf up to the end, system.caf stays as it is")
    func silenceUpToTheEndWhenTheMicrophoneIsLost() async throws {
        let rig = try rig(systemFailure: permissionDenied(), microphoneLost: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .optional)
        await rig.capture.stop()

        // One second of audio, then silence up to the end: the track started 3 seconds ago at least.
        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: rig.folder)))
        #expect(seconds >= 2.9)
        #expect(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: rig.folder)) == nil)
    }

    @Test("a system audio still lost when the recording ends gets silence in system.caf up to the end")
    func silenceUpToTheEndWhenTheSystemAudioIsLost() async throws {
        let rig = try rig(systemLost: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .required)
        await rig.capture.stop()

        // One second of audio, then silence up to the end: the track started 3 seconds ago at least.
        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: rig.folder)))
        #expect(seconds >= 2.9)
    }

    @Test("while the system audio is lost the microphone reports no echo state")
    func noEchoReportWhileTheSystemAudioIsLost() async throws {
        let rig = try rig(systemLost: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .required)
        await rig.capture.stop()

        #expect(rig.receivedEvents().isEmpty)
    }

    @Test("a microphone that is not lost is not padded when the recording ends")
    func noSilenceWhenTheMicrophoneIsOn() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .required)
        await rig.capture.stop()

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: rig.folder)))
        #expect(abs(seconds - 1) < 0.2)
    }
}
