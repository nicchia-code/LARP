import AVFoundation
import Foundation

/// What an imported audio file became.
struct ImportedAudio: Equatable, Sendable {
    /// The length of the audio, in seconds.
    let duration: TimeInterval
    /// When the file was last modified.
    let modifiedAt: Date
}

/// Converts an audio file chosen by the user into the system audio track of a call, with the converter
/// and the writer the tracks of a recording use. The file is only read: it is never kept or changed.
enum AudioFileImporter {
    enum ImportError: LocalizedError {
        /// The file holds no audio.
        case noAudio
        /// The audio could not be converted to the format of the tracks.
        case conversion(String)

        var errorDescription: String? {
            switch self {
            case .noAudio: L10n.string("Il file non contiene audio.")
            case .conversion(let reason): L10n.format("Conversione non riuscita (%@).", reason)
            }
        }
    }

    /// Frames read from the file at once: the file is never read whole.
    static let blockFrames: AVAudioFrameCount = 16_384

    /// Reads `source` (any format AVFoundation reads: m4a, mp3, wav, aiff, caf…) and writes it to
    /// `destination` as a track, creating its folder. Runs off the main actor when awaited from there;
    /// stops with `CancellationError` when the task is cancelled. Leaves the folder as it is on failure.
    static func convert(_ source: URL, to destination: URL) async throws -> ImportedAudio {
        let file = try AVAudioFile(forReading: source)
        guard file.length > 0 else { throw ImportError.noAudio }
        let format = file.processingFormat
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: blockFrames) else {
            throw ImportError.conversion("cannot allocate \(blockFrames) frames")
        }
        try FileManager.default.createDirectory(
            at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)

        let writer = try AACFileWriter(url: destination)
        defer { writer.close() }
        let converter = BufferConverter(target: AudioFormats.storage)
        while file.framePosition < file.length {
            try Task.checkCancellation()
            try file.read(into: buffer, frameCount: blockFrames)
            guard buffer.frameLength > 0 else { break }
            do {
                try writer.write(try converter.convert(buffer))
            } catch let error as BufferConverter.ConversionError {
                throw ImportError.conversion(error.reason)
            }
        }
        guard writer.framesWritten > 0 else { throw ImportError.noAudio }

        let modifiedAt =
            (try? source.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? Date()
        return ImportedAudio(duration: Double(file.length) / format.sampleRate, modifiedAt: modifiedAt)
    }
}
