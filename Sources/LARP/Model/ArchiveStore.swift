import Foundation
import SwiftData

/// Creation of the SwiftData archive and deletion of calls.
enum ArchiveStore {
    static let schema = Schema([Call.self, TranscriptLine.self, Participant.self])

    /// Container backed by the store in `~/Library/Application Support/LARP/`.
    /// Pass `inMemory: true` for tests and previews.
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let configuration: ModelConfiguration
        if inMemory {
            configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            try FileManager.default.createDirectory(
                at: AppPaths.applicationSupportFolder,
                withIntermediateDirectories: true
            )
            configuration = ModelConfiguration(schema: schema, url: AppPaths.storeURL)
        }
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    /// Deletes a call with its lines and participants (cascade) and its
    /// `Recordings/<call id>/` folder.
    static func delete(_ call: Call, in context: ModelContext) throws {
        let folder = call.recordingsFolderURL
        if FileManager.default.fileExists(atPath: folder.path) {
            try FileManager.default.removeItem(at: folder)
        }
        context.delete(call)
        try context.save()
    }
}
