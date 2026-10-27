import AVFoundation
import Foundation
import Testing

@testable import LARP

@Suite("AAC audio files")
struct AACFileWriterTests {
    private func audio(seconds: Double, noise: Bool = false) throws -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(seconds * AudioFormats.storageSampleRate)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: AudioFormats.storage, frameCapacity: frames))
        buffer.frameLength = frames
        for index in 0..<Int(frames) {
            buffer.floatChannelData![0][index] = noise ? Float.random(in: -0.3...0.3) : 0.3 * sinf(Float(index) * 0.1)
        }
        return buffer
    }

    private func temporaryFile() -> URL {
        FileManager.default.temporaryDirectory.appending(path: "larp-\(UUID().uuidString).caf")
    }

    @Test("a file that is never closed is readable up to the last flush")
    func readableAfterCrash() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AACFileWriter(url: url)
        defer { writer.close() }

        // Five seconds in one-second chunks: flushed after the 2nd and the 4th.
        for _ in 0..<5 { try writer.write(try audio(seconds: 1)) }

        // What a crash leaves behind: the file as it is on disk, not closed.
        let copy = temporaryFile()
        defer { try? FileManager.default.removeItem(at: copy) }
        try FileManager.default.copyItem(at: url, to: copy)

        let seconds = try #require(AudioFileDuration.seconds(of: copy))
        #expect(abs(seconds - 4) < 0.2)
    }

    @Test("a closed file holds everything that was written, as AAC mono at about 32 kbps")
    func closedFile() throws {
        let url = temporaryFile()
        defer { try? FileManager.default.removeItem(at: url) }
        let writer = try AACFileWriter(url: url)
        // Noise keeps the encoder at its target rate; a sine needs far fewer bits.
        for _ in 0..<20 { try writer.write(try audio(seconds: 1, noise: true)) }
        writer.close()

        let file = try AVAudioFile(forReading: url)
        #expect(file.fileFormat.channelCount == 1)
        #expect(file.fileFormat.settings[AVFormatIDKey] as? UInt32 == kAudioFormatMPEG4AAC)
        #expect(abs(Double(file.length) / file.processingFormat.sampleRate - 20) < 0.2)

        let bytes = try #require(FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int)
        let bitsPerSecond = Double(bytes) * 8 / 20
        #expect(bitsPerSecond > 24_000 && bitsPerSecond < 48_000, "\(bitsPerSecond) bps, \(bytes) bytes")
    }

    @Test("the duration of a missing or empty file is unknown")
    func unreadable() {
        #expect(AudioFileDuration.seconds(of: temporaryFile()) == nil)
    }
}
