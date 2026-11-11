import AVFoundation
import Foundation
import Testing

@testable import LARP

/// Which buffer of the input list of the aggregate device is the one of the tap.
@Suite("Tap input streams")
struct TapInputStreamsTests {
    @Test("the tap's stream comes after the streams of the sub-devices, never assumed to be the first")
    func tapStreamIsFoundByItsPlace() {
        // An output without input: the tap's stream is the only one.
        #expect(TapInputStreams.index(subDeviceInputStreams: 0, inputStreams: 1) == 0)
        // A headset in its call mode adds its microphone stream.
        #expect(TapInputStreams.index(subDeviceInputStreams: 1, inputStreams: 2) == 1)
        #expect(TapInputStreams.index(subDeviceInputStreams: 2, inputStreams: 3) == 2)
        // Nothing is left for the tap, or there are no input streams at all.
        #expect(TapInputStreams.index(subDeviceInputStreams: 1, inputStreams: 1) == nil)
        #expect(TapInputStreams.index(subDeviceInputStreams: 0, inputStreams: 0) == nil)
    }

    /// An input list of mono float buffers, each filled with its own value.
    private func withList(values: [Float], frames: Int = 480, _ body: (UnsafePointer<AudioBufferList>) -> Void) {
        let list = AudioBufferList.allocate(maximumBuffers: values.count)
        var storage: [UnsafeMutablePointer<Float>] = []
        for (index, value) in values.enumerated() {
            let data = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            data.initialize(repeating: value, count: frames)
            storage.append(data)
            list[index] = AudioBuffer(
                mNumberChannels: 1, mDataByteSize: UInt32(frames * MemoryLayout<Float>.size), mData: data)
        }
        body(list.unsafePointer)
        for data in storage { data.deallocate() }
        free(list.unsafeMutablePointer)
    }

    @Test("only the buffer of the tap's stream is read, with the format of that stream")
    func readsOnlyTheTapBuffer() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16_000, channels: 1, interleaved: false))
        // The microphone of a headset first (0.25), the tap's stream second (0.75).
        withList(values: [0.25, 0.75]) { list in
            var seen: [(rate: Double, value: Float, frames: Int)] = []
            let read = TapInputStreams.withBuffer(in: list, at: 1, format: format) { buffer in
                seen.append((buffer.format.sampleRate, buffer.floatChannelData![0][0], Int(buffer.frameLength)))
            }
            #expect(read)
            #expect(seen.count == 1)
            #expect(seen.first?.rate == 16_000)
            #expect(seen.first?.value == 0.75)
            #expect(seen.first?.frames == 480)
        }
    }

    @Test("a list without the buffer of the tap's stream delivers nothing")
    func missingBufferDeliversNothing() throws {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000, channels: 1, interleaved: false))
        withList(values: [0.25]) { list in
            var called = false
            #expect(!TapInputStreams.withBuffer(in: list, at: 1, format: format) { _ in called = true })
            #expect(!called)
        }
    }
}
