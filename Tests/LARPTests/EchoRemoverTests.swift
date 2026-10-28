import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import LARP

/// The echo remover between the two taps and the microphone's track, with synthetic audio in
/// the formats a Mac's devices deliver.
@Suite("Echo remover")
struct EchoRemoverTests {
    /// Keeps the samples the track receives, after the echo remover and the file.
    private final class CollectingSink: AudioBufferSink {
        private let samples = Mutex<[Float]>([])
        var received: [Float] { samples.withLock { $0 } }

        func consume(_ chunk: AudioChunk, track: AudioTrack) {
            guard let data = chunk.buffer.floatChannelData?[0] else { return }
            samples.withLock { $0.append(contentsOf: UnsafeBufferPointer(start: data, count: Int(chunk.buffer.frameLength))) }
        }
    }

    private static func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-echo-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private static func rms(_ samples: ArraySlice<Float>) -> Float {
        (samples.reduce(0) { $0 + $1 * $1 } / Float(max(samples.count, 1))).squareRoot()
    }

    /// A buffer of `format` filled with `samples` on every channel.
    private static func buffer(_ samples: ArraySlice<Float>, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(samples.count))!
        buffer.frameLength = AVAudioFrameCount(samples.count)
        for channel in 0..<Int(format.channelCount) {
            for (index, sample) in samples.enumerated() {
                buffer.floatChannelData![channel][index] = sample
            }
        }
        return buffer
    }

    @Test("without an echo canceller the microphone goes on to its track as captured")
    func passesTheMicrophoneThroughBeforeReset() async throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sink = CollectingSink()
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)
        let remover = EchoRemover(output: pipeline)

        let captured = (0..<16_000).map { Float(sin(Double($0) * 0.05)) * 0.3 }
        remover.microphone.ingest(borrowing: Self.buffer(captured[...], format: AudioFormats.storage), arrival: 1)
        await remover.finish()
        await pipeline.finish()

        #expect(sink.received == captured)
    }

    @Test("with the echo canceller the echo of the system audio is removed from the microphone track")
    func removesTheEchoOfTheReference() async throws {
        let folder = try Self.makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sink = CollectingSink()
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)
        let remover = EchoRemover(output: pipeline)
        #expect(remover.reset())

        // The system audio as the tap delivers it (stereo) and the microphone as the input node
        // delivers it (mono), both at 48 kHz, so that the echo is an exact copy of the reference:
        // the microphone hears that audio delayed and attenuated.
        let tapFormat = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false))
        let micFormat = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false))
        let seconds = 12
        var state: UInt64 = 0x9E37_79B9_7F4A_7C15
        func noise() -> Float {
            state ^= state << 13
            state ^= state >> 7
            state ^= state << 17
            return Float(Double(state >> 11) / Double(1 << 52)) - 1
        }
        func speechLike(rate: Int) -> [Float] {
            var low: Float = 0
            let samples: [Float] = (0..<rate * seconds).map { index in
                low = 0.6 * low + 0.4 * noise()
                return low * (0.55 + 0.45 * sin(2 * Float.pi * 3.1 * Float(index) / Float(rate)))
            }
            // A level like speech played at normal volume: 0.2 RMS.
            let level = Self.rms(samples[...])
            return samples.map { $0 * 0.2 / level }
        }
        let played = speechLike(rate: 48_000)
        let delay = 48_000 * 80 / 1000
        let echo: [Float] = (0..<played.count).map { $0 >= delay ? 0.4 * played[$0 - delay] : 0 }

        // 100 ms at a time, the system audio first.
        for step in 0..<seconds * 10 {
            let arrival = Double(step + 1) * 0.1
            let reference = Self.buffer(played[step * 4_800..<(step + 1) * 4_800], format: tapFormat)
            remover.reference.ingest(borrowing: reference, arrival: arrival)
            let microphone = Self.buffer(echo[step * 4_800..<(step + 1) * 4_800], format: micFormat)
            remover.microphone.ingest(borrowing: microphone, arrival: arrival)
        }
        await remover.finish()
        await pipeline.finish()

        let received = sink.received
        // The track is as long as the microphone audio, less the frame waiting at the end.
        #expect(abs(received.count - 16_000 * seconds) < 1_600)
        // From the third second on, the echo is much lower than the echo captured.
        let from = 3 * 16_000
        let before = Self.rms(echo[(3 * 48_000)...])
        let after = Self.rms(received[from...])
        let reduction: Float = 20 * log10(before / after)
        #expect(reduction >= 15, "echo reduced by \(reduction) dB")
    }
}
