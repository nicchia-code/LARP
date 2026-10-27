import AVFoundation
import Foundation

enum AudioFileDuration {
    /// Seconds of audio in the file at `url`, up to the last chunk written when the
    /// file was cut by a crash. `nil` when the file is missing or unreadable.
    static func seconds(of url: URL) -> TimeInterval? {
        guard let file = try? AVAudioFile(forReading: url), file.length > 0 else { return nil }
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
