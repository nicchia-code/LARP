import AVFoundation
import Foundation
import Testing

@testable import LARP

@Suite("Buffer converter")
struct BufferConverterTests {
    /// A buffer of a sine wave in every channel, `seconds` long.
    private func buffer(format: AVAudioFormat, seconds: Double) throws -> AVAudioPCMBuffer {
        let frames = AVAudioFrameCount(format.sampleRate * seconds)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames))
        buffer.frameLength = frames
        for channel in 0..<Int(format.channelCount) {
            for index in 0..<Int(frames) {
                buffer.floatChannelData![channel][index] = 0.5 * sin(2 * .pi * 440 * Float(index) / Float(format.sampleRate))
            }
        }
        return buffer
    }

    /// The formats the input node can report once voice processing is on: any sample
    /// rate and any number of channels.
    @Test(
        "any sample rate and channel count the microphone reports becomes storage format",
        arguments: [
            (16_000.0, 1), (24_000.0, 1), (44_100.0, 1), (48_000.0, 1),
            (24_000.0, 2), (48_000.0, 2), (44_100.0, 3), (48_000.0, 5), (24_000.0, 9),
        ] as [(Double, Int)])
    func convertsToStorage(sampleRate: Double, channels: Int) throws {
        let layout = try #require(AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_DiscreteInOrder | UInt32(channels)))
        let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, interleaved: false, channelLayout: layout)
        let converter = BufferConverter(target: AudioFormats.storage)
        var frames = 0
        for _ in 0..<10 {
            let output = try converter.convert(buffer(format: format, seconds: 0.1))
            #expect(output.format == AudioFormats.storage)
            frames += Int(output.frameLength)
        }
        // One second of audio, minus what the sample rate converter still holds back.
        #expect(abs(frames - 16_000) < 1_600)
    }

    /// One converter that gets buffers of different sample rates, as the microphone or the
    /// system audio deliver them when their device changes its rate: every buffer is converted
    /// from the format it carries, so each stretch keeps its duration.
    @Test("a converter that gets buffers of changing sample rates keeps the duration of every stretch")
    func followsTheFormatOfEveryBuffer() throws {
        let converter = BufferConverter(target: AudioFormats.storage)
        for rate in [48_000.0, 24_000, 16_000, 44_100, 48_000] {
            let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: rate, channels: 1, interleaved: false))
            var frames = 0
            for _ in 0..<20 {
                frames += Int(try converter.convert(buffer(format: format, seconds: 0.1)).frameLength)
            }
            // Two seconds, minus what the sample rate converter holds back.
            #expect(abs(frames - 32_000) < 1_600, "\(rate) Hz gave \(frames) frames")
        }
    }
}
