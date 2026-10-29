import AVFoundation
import Foundation
import Testing

@testable import LARP

/// The restart logic of the system audio capture, over fake devices that change their
/// sample rate during the recording.
@Suite("System audio tap")
struct SystemAudioTapTests {
    private static let frequency = 440.0

    private struct Rig {
        let tap: SystemAudioTap
        let driver: FakeSystemDriver
        let pipeline: TrackPipeline
        let recorder: TrackRecorder
        let events: EventLog
        let folder: URL
        /// The echo remover of the recording, with the microphone's track.
        let echoRemover: EchoRemover?
        let microphonePipeline: TrackPipeline?

        func finish() async {
            tap.stop()
            await echoRemover?.finish()
            await microphonePipeline?.finish()
            await pipeline.finish()
        }
    }

    private func rig(withEchoRemover: Bool = false) throws -> Rig {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-system-tap-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let recorder = TrackRecorder()
        let events = EventLog()
        let pipeline = try TrackPipeline(track: .system, folder: folder, sink: recorder)
        var microphonePipeline: TrackPipeline?
        var echoRemover: EchoRemover?
        if withEchoRemover {
            let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)
            microphonePipeline = pipeline
            echoRemover = EchoRemover(output: pipeline)
        }
        let driver = FakeSystemDriver(tone: FakeTone(frequency: Self.frequency, channels: 2))
        let tap = SystemAudioTap(
            pipeline: pipeline, echoRemover: echoRemover, driver: driver, events: { events.append($0) })
        return Rig(
            tap: tap, driver: driver, pipeline: pipeline, recorder: recorder, events: events, folder: folder,
            echoRemover: echoRemover,
            microphonePipeline: microphonePipeline)
    }

    /// The tone is on in `[start, end]` seconds of the track, at its frequency within 1%.
    private func expectTone(_ samples: [Float], from start: Double, to end: Double) {
        let measured = TrackAnalysis.frequency(of: TrackAnalysis.window(samples, from: start, to: end))
        #expect(abs(measured - Self.frequency) <= Self.frequency * 0.01, "tone at \(measured) Hz between \(start) s and \(end) s")
    }

    private func expectDuration(_ seconds: Double, of expected: Double) {
        #expect(abs(seconds - expected) <= expected * 0.01, "\(seconds) s stored, \(expected) s expected")
    }

    @Test("the capture follows the sample rate of the output: the tone keeps its frequency and the track its duration")
    func followsTheSampleRate() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }
        let rates = [48_000.0, 24_000, 16_000, 48_000]

        try rig.tap.start()
        for (index, rate) in rates.enumerated() {
            if index > 0 {
                // `macos.AUDIO_DEVICES_CHANGED`: Captured → Captured.
                rig.driver.changeRate(to: rate)
                await rig.driver.starts.wait(atLeast: index + 1)
            }
            rig.driver.play(seconds: 3)
        }
        await rig.finish()

        let samples = rig.recorder.samples(of: .system)
        for index in rates.indices {
            expectTone(samples, from: Double(index) * 3, to: Double(index + 1) * 3)
        }
        expectDuration(Double(samples.count) / AudioFormats.storageSampleRate, of: 12)
        let stored = try #require(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: rig.folder)))
        expectDuration(stored, of: 12)
        #expect(rig.events.events.isEmpty)
        #expect(!rig.tap.isLost)
    }

    @Test("every change of audio devices restarts the capture, even one that leaves the output as it was")
    func everyChangeRestartsTheCapture() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }

        try rig.tap.start()
        rig.driver.notify()
        await rig.driver.starts.wait(atLeast: 2)
        rig.driver.notify()
        await rig.driver.starts.wait(atLeast: 3)
        await rig.finish()

        #expect(rig.driver.starts.value == 3)
    }

    @Test("a capture that cannot start again is lost, tries again at every change and comes back with the speed of the output")
    func lostThenCaptured() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }
        let failure = SystemAudioTap.TapError(operation: "create aggregate device", status: -1)

        try rig.tap.start()
        rig.driver.play(seconds: 3)

        // Captured → Lost.
        rig.driver.fail(failure)
        rig.driver.changeRate(to: 24_000)
        await rig.events.wait(forCount: 1)
        #expect(rig.events.events == [.systemAudioLost])
        #expect(rig.tap.isLost)
        rig.driver.play(seconds: 3)

        // Lost → Lost: it tries again, nothing is told again.
        rig.driver.notify()
        await rig.driver.observations.wait(atLeast: 2)
        #expect(rig.events.events == [.systemAudioLost])
        #expect(rig.tap.isLost)

        // Lost → Captured, on an output with another sample rate.
        rig.driver.fail(nil)
        rig.driver.notify()
        await rig.events.wait(forCount: 2)
        #expect(rig.events.events == [.systemAudioLost, .systemAudioRestored])
        #expect(!rig.tap.isLost)
        rig.driver.play(seconds: 3)
        await rig.finish()

        // Tone, silence while it was lost, tone at the new rate.
        let samples = rig.recorder.samples(of: .system)
        expectTone(samples, from: 0, to: 3)
        let silence = TrackAnalysis.level(of: TrackAnalysis.window(samples, from: 3, to: 6))
        #expect(silence < 0.001, "the track holds sound while the system audio was lost")
        expectTone(samples, from: 6, to: 9)
        expectDuration(Double(samples.count) / AudioFormats.storageSampleRate, of: 9)
    }

    @Test("the echo canceller has no reference while the system audio is lost and starts again when it comes back")
    func echoRemoverFollowsTheCapture() async throws {
        let rig = try rig(withEchoRemover: true)
        defer { try? FileManager.default.removeItem(at: rig.folder) }
        let remover = try #require(rig.echoRemover)

        try rig.tap.start()
        #expect(remover.reset())

        rig.driver.fail(SystemAudioTap.TapError(operation: "create aggregate device", status: -1))
        rig.driver.changeRate(to: 24_000)
        await rig.events.wait(forCount: 1)
        // The microphone restarting while the system audio is lost does not get an echo canceller.
        #expect(!remover.reset())

        rig.driver.fail(nil)
        rig.driver.notify()
        await rig.events.wait(forCount: 3)
        #expect(rig.events.events == [.systemAudioLost, .systemAudioRestored, .echoCancellation(available: true)])
        await rig.finish()
    }

    @Test("a capture that cannot start at the start of the recording throws and is not lost")
    func startFails() async throws {
        let rig = try rig()
        defer { try? FileManager.default.removeItem(at: rig.folder) }
        rig.driver.fail(SystemAudioTap.TapError(operation: SystemAudioTap.TapError.createTapOperation, status: -1))

        #expect(throws: SystemAudioTap.TapError.self) { try rig.tap.start() }
        await rig.finish()

        #expect(!rig.tap.isLost)
        #expect(rig.driver.starts.value == 0)
        #expect(rig.events.events.isEmpty)
    }
}
