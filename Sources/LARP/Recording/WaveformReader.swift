import AVFoundation
import Accelerate
import Foundation

/// Reads the saved tracks of a call, a block at a time, and measures their peaks for the waveform.
enum WaveformReader {
    /// Frames read at once: never a whole track.
    static let blockFrames: AVAudioFrameCount = 16_384

    /// What `peaks(of:duration:)` found: the call has no audio to measure when this is `nil`.
    struct Measure: Equatable, Sendable {
        /// The seconds the bars share.
        let duration: TimeInterval
        /// The linear peak, 0 to 1, of both tracks over each bar.
        let peaks: [Float]
    }

    /// The peak of the audio of `urls` (the tracks of a call that can be read) over each of
    /// `Waveform.barCount` equal parts of `duration` seconds, or of the longest track when `duration` is
    /// not positive; the peak of a bar is the largest of the tracks. `nil` when no track can be read or
    /// all are empty. Runs off the main actor when awaited from there; stops with `CancellationError`
    /// when the task is cancelled.
    static func peaks(of urls: [URL], duration: TimeInterval, bars: Int = Waveform.barCount) async throws -> Measure? {
        var files: [AVAudioFile] = []
        for url in urls {
            if let file = try? AVAudioFile(forReading: url), file.length > 0 {
                files.append(file)
            }
        }
        guard !files.isEmpty else { return nil }
        let longest = files.map { Double($0.length) / $0.processingFormat.sampleRate }.max() ?? 0
        let span = duration > 0 ? duration : longest
        guard span > 0 else { return nil }

        var peaks = [Float](repeating: 0, count: bars)
        for file in files {
            try measure(file, span: span, into: &peaks)
        }
        return Measure(duration: span, peaks: peaks)
    }

    private static func measure(_ file: AVAudioFile, span: TimeInterval, into peaks: inout [Float]) throws {
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: blockFrames) else { return }
        let bars = peaks.count
        let framesPerBar = span * format.sampleRate / Double(bars)
        let channels = Int(format.channelCount)

        while file.framePosition < file.length {
            try Task.checkCancellation()
            let first = Int(file.framePosition)
            try file.read(into: buffer, frameCount: blockFrames)
            let count = Int(buffer.frameLength)
            guard count > 0, let data = buffer.floatChannelData else { break }

            // A block can span several bars: its frames are split at the bar boundaries.
            var offset = 0
            while offset < count {
                let bar = min(Int(Double(first + offset) / framesPerBar), bars - 1)
                let barEnd = bar == bars - 1 ? Int.max : Int((Double(bar + 1) * framesPerBar).rounded(.up))
                let length = min(count - offset, max(barEnd - (first + offset), 1))
                for channel in 0..<channels {
                    var peak: Float = 0
                    vDSP_maxmgv(data[channel] + offset, 1, &peak, vDSP_Length(length))
                    peaks[bar] = max(peaks[bar], min(peak, 1))
                }
                offset += length
            }
        }
    }
}
