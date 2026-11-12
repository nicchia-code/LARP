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
        private let state = Mutex((started: false, stopped: false, choiceChanges: 0))

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

        /// How many times the capture told the microphone that the choice changed.
        var choiceChanges: Int { state.withLock { $0.choiceChanges } }

        func microphoneChoiceChanged() {
            state.withLock { $0.choiceChanges += 1 }
        }

        /// Starts and delivers one second of audio, and nothing since.
        func start() throws {
            if failsToStart { throw SourceFailure() }
            state.withLock { $0.started = true }
            let frames = AVAudioFrameCount(AudioFormats.storageSampleRate)
            if let buffer = AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames) {
                buffer.frameLength = frames
                buffer.floatChannelData![0].update(repeating: 0.1, count: Int(frames))
                pipeline.ingest(borrowing: buffer, arrival: ProcessInfo.processInfo.systemUptime)
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

        /// Delivers one second of audio at the start, and nothing since.
        func start() throws {
            if let failure { throw failure }
            state.withLock { $0.started = true }
            guard let pipeline = pipeline.withLock({ $0 }) else { return }
            let frames = AVAudioFrameCount(AudioFormats.storageSampleRate)
            if let buffer = AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames) {
                buffer.frameLength = frames
                buffer.floatChannelData![0].update(repeating: 0.1, count: Int(frames))
                pipeline.ingest(borrowing: buffer, arrival: ProcessInfo.processInfo.systemUptime)
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

    /// Records for `seconds`, then stops. Returns how long the recording can have lasted: at
    /// least the time slept between the calls, at most the time measured around them (on a busy
    /// machine starting and stopping take long, and only the time between them is recorded).
    private func record(_ rig: Rig, systemAudio policy: SystemAudioPolicy, seconds: Double) async throws -> ClosedRange<Double> {
        let begin = ProcessInfo.processInfo.systemUptime
        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: policy)
        try await Task.sleep(for: .seconds(seconds))
        await rig.capture.stop()
        return seconds...(ProcessInfo.processInfo.systemUptime - begin)
    }

    /// `seconds` of a track last as long as the `recording`, give or take what the encoder rounds.
    private func expectLasts(
        _ seconds: Double, as recording: ClosedRange<Double>, _ track: AudioTrack,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(
            seconds >= recording.lowerBound - 0.1 && seconds <= recording.upperBound + 0.1,
            "\(track.fileName) lasts \(seconds) s, the recording \(recording) s", sourceLocation: sourceLocation)
    }

    @Test("a microphone still lost when the recording ends gets silence in mic.caf up to the end, system.caf stays empty")
    func silenceUpToTheEndWhenTheMicrophoneIsLost() async throws {
        let rig = try rig(systemFailure: permissionDenied(), microphoneLost: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        let recording = try await record(rig, systemAudio: .optional, seconds: 1.5)

        // One second of audio, then silence up to the end.
        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: rig.folder)))
        expectLasts(seconds, as: recording, .microphone)
        #expect(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: rig.folder)) == nil)
    }

    @Test("a system audio still lost when the recording ends gets silence in system.caf up to the end")
    func silenceUpToTheEndWhenTheSystemAudioIsLost() async throws {
        let rig = try rig(systemLost: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        let recording = try await record(rig, systemAudio: .required, seconds: 1.5)

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: rig.folder)))
        expectLasts(seconds, as: recording, .system)
    }

    @Test("sources that stopped delivering audio without being lost, or still run, get tracks as long as the recording")
    func everyWrittenTrackLastsAsLongAsTheRecording() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        // Each source delivered one second of audio at the start and nothing since.
        let recording = try await record(rig, systemAudio: .required, seconds: 1.5)

        for track in [AudioTrack.microphone, .system] {
            let seconds = try #require(AudioFileDuration.seconds(of: track.fileURL(in: rig.folder)))
            expectLasts(seconds, as: recording, track)
        }
    }

    @Test("a system audio track that never started stays empty while the microphone track lasts as long as the recording")
    func neverStartedSystemTrackStaysEmpty() async throws {
        let rig = try rig(systemFailure: SourceFailure())
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        let recording = try await record(rig, systemAudio: .optional, seconds: 1.5)

        let microphone = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: rig.folder)))
        expectLasts(microphone, as: recording, .microphone)
        #expect(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: rig.folder)) == nil)
    }

    @Test("while the system audio is lost the microphone reports no echo state")
    func noEchoReportWhileTheSystemAudioIsLost() async throws {
        let rig = try rig(systemLost: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try await rig.capture.start(into: rig.folder, sink: nil, systemAudio: .required)
        await rig.capture.stop()

        #expect(rig.receivedEvents().isEmpty)
    }
}
