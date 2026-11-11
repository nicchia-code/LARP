import AVFoundation
import Foundation
import Synchronization
import Testing

@testable import LARP

@Suite("Level meter")
struct LevelMeterTests {
    /// Feeds `windows` windows of 50 ms of constant `amplitude` and returns what the meter emitted.
    private func feed(_ meter: inout LevelMeter, amplitude: Float, windows: Int, chunkFrames: Int = 800) -> [TrackLevel] {
        var emitted: [TrackLevel] = []
        var remaining = windows * 800
        while remaining > 0 {
            let count = min(chunkFrames, remaining)
            let samples = [Float](repeating: amplitude, count: count)
            samples.withUnsafeBufferPointer { meter.consume($0) { emitted.append($0) } }
            remaining -= count
        }
        return emitted
    }

    @Test("a second of audio gives 20 values, one per 50 ms, whatever the size of the chunks")
    func twentyValuesPerSecond() {
        var meter = LevelMeter()
        let even = feed(&meter, amplitude: 0.1, windows: 20)
        var unevenMeter = LevelMeter()
        let uneven = feed(&unevenMeter, amplitude: 0.1, windows: 20, chunkFrames: 333)
        #expect(even.count == 20)
        #expect(uneven.count == 20)
    }

    @Test("the level is the peak of the 50 ms on a scale from −60 to 0 dBFS")
    func scale() {
        var meter = LevelMeter()
        let full = feed(&meter, amplitude: 1, windows: 1)
        // −20 dBFS.
        let twenty = feed(&meter, amplitude: 0.1, windows: 1)
        // −60 dBFS and silence are the bottom of the scale.
        let floor = feed(&meter, amplitude: 0.001, windows: 1)
        let silence = feed(&meter, amplitude: 0, windows: 1)
        #expect(abs(full[0].level - 1) < 0.0001)
        #expect(abs(twenty[0].level - 40.0 / 60) < 0.0001)
        #expect(floor[0].level < 0.0001)
        #expect(silence[0].level == 0)
    }

    @Test("the peak of a window is the loudest sample in it, negative ones included")
    func peak() {
        var meter = LevelMeter()
        var samples = [Float](repeating: 0, count: 800)
        samples[400] = -0.5
        var emitted: [TrackLevel] = []
        samples.withUnsafeBufferPointer { meter.consume($0) { emitted.append($0) } }
        // −6 dBFS.
        #expect(abs(emitted[0].level - (60 - 6.0206) / 60) < 0.001)
    }

    @Test("a track speaks after 200 ms above −40 dBFS")
    func startsSpeakingAfter200Milliseconds() {
        var meter = LevelMeter()
        // 0.02 is −34 dBFS.
        let levels = feed(&meter, amplitude: 0.02, windows: 5)
        #expect(levels.map(\.isSpeaking) == [false, false, false, true, true])
    }

    @Test("a track that does not stay above −40 dBFS for 200 ms does not speak")
    func shortSoundDoesNotSpeak() {
        var meter = LevelMeter()
        var levels = feed(&meter, amplitude: 0.02, windows: 3)
        levels += feed(&meter, amplitude: 0.001, windows: 1)
        levels += feed(&meter, amplitude: 0.02, windows: 3)
        #expect(levels.allSatisfy { !$0.isSpeaking })
    }

    @Test("a track stops speaking 500 ms after it fell below −40 dBFS")
    func stopsSpeakingAfter500Milliseconds() {
        var meter = LevelMeter()
        _ = feed(&meter, amplitude: 0.02, windows: 8)
        let levels = feed(&meter, amplitude: 0.001, windows: 10)
        #expect(levels.prefix(9).allSatisfy { $0.isSpeaking })
        #expect(levels.last?.isSpeaking == false)
    }

    @Test("a brief pause in speech does not stop it")
    func briefPauseKeepsSpeaking() {
        var meter = LevelMeter()
        _ = feed(&meter, amplitude: 0.02, windows: 8)
        _ = feed(&meter, amplitude: 0.001, windows: 5)
        let levels = feed(&meter, amplitude: 0.02, windows: 10)
        #expect(levels.allSatisfy { $0.isSpeaking })
    }
}

@Suite("Track pipeline levels and pause")
struct TrackPipelineLevelTests {
    private final class PeakSink: AudioBufferSink {
        private let peaks = Mutex<[Float]>([])
        var all: [Float] { peaks.withLock { $0 } }

        func consume(_ chunk: AudioChunk, track: AudioTrack) {
            let buffer = chunk.buffer
            let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
            let peak = samples.reduce(Float(0)) { max($0, abs($1)) }
            peaks.withLock { $0.append(peak) }
        }
    }

    private final class LevelCollector: Sendable {
        private let received = Mutex<[(AudioTrack, TrackLevel)]>([])
        var all: [(AudioTrack, TrackLevel)] { received.withLock { $0 } }
        func add(_ track: AudioTrack, _ level: TrackLevel) { received.withLock { $0.append((track, level)) } }
    }

    private func buffer(seconds: Double, amplitude: Float) throws -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * AudioFormats.storageSampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames))
        buffer.frameLength = frames
        buffer.floatChannelData![0].update(repeating: amplitude, count: Int(frames))
        return buffer
    }

    private func makeFolder() throws -> URL {
        let folder = FileManager.default.temporaryDirectory.appending(path: "larp-levels-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    @Test("every 50 ms of audio gives a level of its track")
    func levelsPerTrack() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let collector = LevelCollector()
        let pipeline = try TrackPipeline(track: .system, folder: folder, sink: nil, levels: { collector.add($0, $1) })

        pipeline.ingest(borrowing: try buffer(seconds: 1, amplitude: 0.1))
        await pipeline.finish()

        let received = collector.all
        #expect(received.count == 20)
        #expect(received.allSatisfy { $0.0 == .system && abs($0.1.level - 40.0 / 60) < 0.0001 })
    }

    @Test("while paused the track and the sink take silence of the same length and the levels are empty")
    func pause() async throws {
        let folder = try makeFolder()
        defer { try? FileManager.default.removeItem(at: folder) }
        let sink = PeakSink()
        let collector = LevelCollector()
        let pipeline = try TrackPipeline(track: .microphone, folder: folder, sink: sink, levels: { collector.add($0, $1) })

        pipeline.ingest(borrowing: try buffer(seconds: 1, amplitude: 0.1))
        pipeline.setPaused(true)
        pipeline.ingest(borrowing: try buffer(seconds: 1, amplitude: 0.1))
        pipeline.setPaused(false)
        pipeline.ingest(borrowing: try buffer(seconds: 1, amplitude: 0.1))
        await pipeline.finish()

        let peaks = sink.all
        #expect(peaks.count == 3)
        #expect(abs(peaks[0] - 0.1) < 0.0001)
        #expect(peaks[1] == 0)
        #expect(abs(peaks[2] - 0.1) < 0.0001)
        // The track is as long as the recording: the paused second is silence, not a gap.
        let seconds = try #require(AudioFileDuration.seconds(of: AudioTrack.microphone.fileURL(in: folder)))
        #expect(abs(seconds - 3) < 0.2)
        let levels = collector.all.map(\.1.level)
        #expect(levels.count == 60)
        #expect(levels[20..<40].allSatisfy { $0 == 0 })
        #expect(levels[0..<20].allSatisfy { $0 > 0.6 })
        #expect(levels[40..<60].allSatisfy { $0 > 0.6 })
    }
}
