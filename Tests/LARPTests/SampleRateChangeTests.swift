import AVFoundation
import Foundation
import Testing

@testable import LARP

/// Both tracks of a recording are stored at the speed at which they were heard, whatever
/// changes of sample rate the microphone and the audio output go through: the whole
/// capture (`CallAudioCapture` with the real `MicrophoneCapture` and `SystemAudioTap`) over
/// fake audio devices.
@Suite("Sample rate changes during a recording")
struct SampleRateChangeTests {
    private static let microphoneFrequency = 440.0
    private static let systemFrequency = 1_000.0
    private static let phaseSeconds = 3.0

    private func expectTone(_ samples: [Float], at frequency: Double, from start: Double, to end: Double, track: String) {
        let measured = TrackAnalysis.frequency(of: TrackAnalysis.window(samples, from: start, to: end))
        #expect(
            abs(measured - frequency) <= frequency * 0.01,
            "\(track): tone at \(measured) Hz between \(start) s and \(end) s, \(frequency) Hz expected")
    }

    private func expectDuration(_ seconds: Double, of expected: Double, track: String) {
        #expect(abs(seconds - expected) <= expected * 0.01, "\(track): \(seconds) s stored, \(expected) s expected")
    }

    @Test(
        "a tone keeps its frequency and the stored duration matches the time it was fed in both tracks, while each device changes its sample rate",
        arguments: [
            // The microphone and the output change their sample rate at different times.
            (mic: [48_000.0, 24_000, 16_000, 48_000], system: [48_000.0, 48_000, 24_000, 16_000]),
            // Bluetooth headphones: the output goes to the call mode and back, the microphone with it.
            (mic: [48_000.0, 16_000, 24_000, 48_000], system: [48_000.0, 16_000, 24_000, 48_000]),
        ] as [(mic: [Double], system: [Double])])
    func bothTracksKeepTheirSpeed(mic: [Double], system: [Double]) async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-rates-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: folder) }
        let start = ProcessInfo.processInfo.systemUptime
        let microphone = FakeMicrophoneDevice(
            tone: FakeTone(frequency: Self.microphoneFrequency, channels: 1, start: start), rate: mic[0])
        let output = FakeSystemDriver(
            tone: FakeTone(frequency: Self.systemFrequency, channels: 2, start: start), rate: system[0])
        let recorder = TrackRecorder()
        let capture = CallAudioCapture(
            // Without echo removal: the test checks the speed of the tracks, not the cleaned microphone.
            makeMicrophone: { pipeline, _, events in
                MicrophoneCapture(pipeline: pipeline, events: events, makeEngine: { microphone.makeEngine() })
            },
            makeSystem: { pipeline, _, events in
                SystemAudioTap(pipeline: pipeline, driver: output, events: events)
            })

        try await capture.start(into: folder, sink: recorder, systemAudio: .required)
        for phase in mic.indices {
            if phase > 0 {
                if mic[phase] != mic[phase - 1] {
                    microphone.changeRate(to: mic[phase])
                    await microphone.starts.wait(atLeast: 1 + (1...phase).filter { mic[$0] != mic[$0 - 1] }.count)
                }
                if system[phase] != system[phase - 1] {
                    output.changeRate(to: system[phase])
                    await output.starts.wait(atLeast: 1 + (1...phase).filter { system[$0] != system[$0 - 1] }.count)
                }
            }
            microphone.play(seconds: Self.phaseSeconds)
            output.play(seconds: Self.phaseSeconds)
        }
        await capture.stop()

        let total = Self.phaseSeconds * Double(mic.count)
        for (track, frequency, name) in [
            (AudioTrack.microphone, Self.microphoneFrequency, "microphone"), (.system, Self.systemFrequency, "system audio"),
        ] {
            let samples = recorder.samples(of: track)
            for phase in mic.indices {
                expectTone(
                    samples, at: frequency, from: Double(phase) * Self.phaseSeconds,
                    to: Double(phase + 1) * Self.phaseSeconds, track: name)
            }
            expectDuration(Double(samples.count) / AudioFormats.storageSampleRate, of: total, track: name)
            let stored = try #require(AudioFileDuration.seconds(of: track.fileURL(in: folder)))
            expectDuration(stored, of: total, track: name)
        }
    }

    @Test("a microphone that starts again after its sample rate changed reads the new rate, never the one of an earlier start")
    func microphoneReadsTheRateOfEveryStart() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-rates-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let device = FakeMicrophoneDevice(tone: FakeTone(frequency: Self.microphoneFrequency, channels: 1), rate: 48_000)
        let recorder = TrackRecorder()
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: recorder)
        let microphone = MicrophoneCapture(pipeline: pipeline, makeEngine: { device.makeEngine() })

        try microphone.start()
        device.play(seconds: 2)
        device.changeRate(to: 16_000)
        await device.starts.wait(atLeast: 2)
        device.play(seconds: 2)
        microphone.stop()
        await pipeline.finish()

        let samples = recorder.samples(of: .microphone)
        expectTone(samples, at: Self.microphoneFrequency, from: 0, to: 2, track: "microphone")
        expectTone(samples, at: Self.microphoneFrequency, from: 2, to: 4, track: "microphone")
        expectDuration(Double(samples.count) / AudioFormats.storageSampleRate, of: 4, track: "microphone")
    }

    @Test("a microphone that cannot start again after a change of its sample rate is lost, and says so once")
    func microphoneLost() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-rates-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let device = FakeMicrophoneDevice(tone: FakeTone(frequency: Self.microphoneFrequency, channels: 1), rate: 48_000)
        let events = EventLog()
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)
        let microphone = MicrophoneCapture(
            pipeline: pipeline, events: { events.append($0) }, makeEngine: { device.makeEngine() })

        try microphone.start()
        device.failToStart(true)
        device.changeRate(to: 24_000)
        await events.wait(forCount: 2)
        microphone.stop()
        await pipeline.finish()

        #expect(events.events == [.echoCancellation(available: false), .microphoneLost])
        #expect(microphone.isLost)
    }
}
