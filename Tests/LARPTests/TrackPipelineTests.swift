import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import LARP

@Suite("Track pipeline")
struct TrackPipelineTests {
    private final class CollectingSink: AudioBufferSink {
        private let frames = Mutex<(count: Int, formats: [AVAudioFormat])>((0, []))
        var frameCount: Int { frames.withLock { $0.count } }
        var formats: [AVAudioFormat] { frames.withLock { $0.formats } }

        func consume(_ chunk: AudioChunk, track: AudioTrack) {
            frames.withLock {
                $0.count += Int(chunk.buffer.frameLength)
                $0.formats.append(chunk.buffer.format)
            }
        }
    }

    @Test("audio from a device format is stored as mono AAC and handed to the sink in the storage format")
    func convertsWritesAndForwards() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-track-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sink = CollectingSink()
        let pipeline = try TrackPipeline(track: .system, folder: folder, sink: sink)

        // 3 seconds of 48 kHz stereo, in tenths of a second, as a device delivers them.
        let device = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 2, interleaved: false))
        for _ in 0..<30 {
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: device, frameCapacity: 4_800))
            buffer.frameLength = 4_800
            for channel in 0..<2 {
                for index in 0..<4_800 {
                    buffer.floatChannelData![channel][index] = Float.random(in: -0.3...0.3)
                }
            }
            pipeline.ingest(borrowing: buffer)
        }
        await pipeline.finish()

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.system.fileURL(in: folder)))
        #expect(abs(seconds - 3) < 0.2)
        #expect(abs(sink.frameCount - 48_000) < 3_200)
        #expect(sink.formats.allSatisfy { $0 == AudioFormats.storage })
    }

    /// A buffer of `seconds` of constant audio in the storage format.
    private func buffer(seconds: Double) throws -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * AudioFormats.storageSampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames))
        buffer.frameLength = frames
        buffer.floatChannelData![0].update(repeating: 0.1, count: Int(frames))
        return buffer
    }

    @Test("a track that stopped receiving audio is filled with silence up to the end of the recording")
    func silenceUntilTheEnd() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-track-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let sink = CollectingSink()
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink)

        // One second of audio that ends at uptime 101: the track starts at uptime 100.
        pipeline.ingest(borrowing: try buffer(seconds: 1), arrival: 101)
        // The microphone is lost; the recording ends at uptime 104.
        await pipeline.finish(silenceUntil: 104)

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: folder)))
        #expect(abs(seconds - 4) < 0.2)
        #expect(abs(sink.frameCount - 64_000) < 3_200)
    }

    @Test("a track is not filled when the recording does not ask for it")
    func noSilenceWithoutAsking() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-track-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)

        pipeline.ingest(borrowing: try buffer(seconds: 1), arrival: 101)
        await pipeline.finish()

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: folder)))
        #expect(abs(seconds - 1) < 0.2)
    }

    @Test("a long loss is filled with silence as long as the recording")
    func longLoss() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-track-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)

        pipeline.ingest(borrowing: try buffer(seconds: 1), arrival: 101)
        await pipeline.finish(silenceUntil: 100 + 95)

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: folder)))
        #expect(abs(seconds - 95) < 0.5)
    }

    @Test("the audio that comes back after a loss lines up with the recording")
    func gapFilledWhenAudioReturns() async throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-track-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: nil)

        pipeline.ingest(borrowing: try buffer(seconds: 1), arrival: 101)
        // Lost from uptime 101 to 105, then one more second of audio.
        pipeline.ingest(borrowing: try buffer(seconds: 1), arrival: 106)
        await pipeline.finish()

        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: folder)))
        #expect(abs(seconds - 6) < 0.2)
    }
}
