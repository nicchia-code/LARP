import AVFoundation
import Foundation

/// Converts audio buffers to one target format, keeping the converter (and so the
/// sample rate conversion state) between buffers. Rebuilds it when the input format
/// changes. Not thread-safe: use from one queue or task.
final class BufferConverter {
    struct ConversionError: Error {
        let reason: String
    }

    let target: AVAudioFormat
    private var converter: AVAudioConverter?
    private var inputFormat: AVAudioFormat?

    init(target: AVAudioFormat) {
        self.target = target
    }

    func convert(_ input: AVAudioPCMBuffer) throws -> AVAudioPCMBuffer {
        if input.format == target { return input }
        if inputFormat != input.format {
            converter = AVAudioConverter(from: input.format, to: target)
            inputFormat = input.format
        }
        guard let converter else { throw ConversionError(reason: "no converter from \(input.format) to \(target)") }
        let capacity = AVAudioFrameCount((Double(input.frameLength) * target.sampleRate / input.format.sampleRate).rounded(.up)) + 64
        guard let output = AVAudioPCMBuffer(pcmFormat: target, frameCapacity: capacity) else {
            throw ConversionError(reason: "cannot allocate \(capacity) frames")
        }
        let source = InputOnce(input)
        var error: NSError?
        let status = converter.convert(to: output, error: &error) { _, inputStatus in
            guard let buffer = source.take() else {
                inputStatus.pointee = .noDataNow
                return nil
            }
            inputStatus.pointee = .haveData
            return buffer
        }
        if status == .error {
            throw error ?? ConversionError(reason: "conversion failed")
        }
        return output
    }
}

/// Hands a buffer to a converter's input block once.
private final class InputOnce: @unchecked Sendable {
    private var buffer: AVAudioPCMBuffer?
    init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    func take() -> AVAudioPCMBuffer? {
        defer { buffer = nil }
        return buffer
    }
}
