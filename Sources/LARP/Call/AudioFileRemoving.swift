import Foundation

/// Deletes the audio files of a call for the audio retention, off the main actor.
protocol AudioFileRemoving: Sendable {
    /// Deletes the files at `urls`, and only them; a file that is not there is left out. Throws when
    /// one cannot be removed.
    @concurrent func removeFiles(at urls: [URL]) async throws
}

/// The archive's file manager.
struct ArchiveAudioRemover: AudioFileRemoving {
    @concurrent func removeFiles(at urls: [URL]) async throws {
        let fileManager = FileManager.default
        for url in urls where fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
}
