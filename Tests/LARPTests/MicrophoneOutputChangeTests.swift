import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import LARP

/// What the microphone does when the audio output changes, and when its own device changes
/// format or disappears, over fake audio devices.
@Suite("Microphone and the audio output", .serialized)
struct MicrophoneOutputChangeTests {
    private final class Rig: Sendable {
        let devices = FakeInputDevices(connected: [builtInMicrophone], defaultUID: builtInMicrophone.uid)
        let output = FakeOutputDevices()
        let device: FakeMicrophoneDevice
        let events = EventLog()
        let sink = TrackRecorder()
        let pipeline: TrackPipeline
        let echoRemover: EchoRemover?
        let microphone: MicrophoneCapture
        let folder: URL

        init(echoRemover useEchoRemover: Bool = true) throws {
            let folder = FileManager.default.temporaryDirectory.appending(path: "larp-output-\(UUID().uuidString)")
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            self.folder = folder
            let device = FakeMicrophoneDevice(tone: FakeTone(frequency: 440, channels: 1), rate: 48_000)
            self.device = device
            let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)
            self.pipeline = pipeline
            let echoRemover = useEchoRemover ? EchoRemover(output: pipeline) : nil
            self.echoRemover = echoRemover
            let events = events
            microphone = MicrophoneCapture(
                pipeline: pipeline, echoRemover: echoRemover, events: { events.append($0) }, inputDevices: devices,
                outputDevices: output, chosenDevice: { nil }, makeUnit: { _ in device.makeUnit() })
        }

        func finish() async {
            microphone.stop()
            await echoRemover?.finish()
            await pipeline.finish()
            try? FileManager.default.removeItem(at: folder)
        }
    }

    @Test("when only the output changes the microphone is not reopened and a new echo canceller is made")
    func outputChangeMakesANewEchoCanceller() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        rig.device.play(seconds: 2)
        rig.output.change()
        rig.device.play(seconds: 2)
        await rig.finish()

        #expect(rig.device.starts.value == 1)
        #expect(rig.events.events == [.echoCancellation(available: true), .echoCancellation(available: true)])
        // No gap: the track holds the four seconds heard.
        let samples = rig.sink.samples(of: .microphone)
        #expect(abs(Double(samples.count) / AudioFormats.storageSampleRate - 4) < 0.2)
        #expect(!rig.microphone.isLost)
    }

    @Test("without an echo remover a change of the output does nothing")
    func outputChangeWithoutEchoRemover() async throws {
        let rig = try Rig(echoRemover: false)
        try rig.microphone.start()
        rig.output.change()
        #expect(rig.device.starts.value == 1)
        #expect(rig.events.events == [.echoCancellation(available: false)])
        await rig.finish()
    }

    @Test("a lost microphone gets no echo canceller from a change of the output")
    func outputChangeWhileLost() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        rig.device.failToStart(true)
        rig.device.disappear()
        #expect(rig.microphone.isLost)
        let count = rig.events.events.count
        rig.output.change()
        #expect(rig.events.events.count == count)
        await rig.finish()
    }

    @Test("a change of the format of the microphone, and its disappearance, restart the capture")
    func formatChangeRestarts() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        rig.device.changeRate(to: 16_000)
        #expect(rig.device.starts.value == 2)
        rig.device.disappear()
        #expect(rig.device.starts.value == 3)
        await rig.finish()
    }

    @Test("stopping the capture stops following the output")
    func stopRemovesTheOutputObserver() async throws {
        let rig = try Rig()
        try rig.microphone.start()
        #expect(rig.output.observerCount == 1)
        await rig.finish()
        #expect(rig.output.observerCount == 0)
    }
}
