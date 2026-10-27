import Foundation

/// Locations of the app data: `~/Library/Application Support/LARP/`.
enum AppPaths {
    static let folderName = "LARP"
    static let storeFileName = "LARP.store"
    static let recordingsFolderName = "Recordings"
    static let micFileName = "mic.caf"
    static let systemFileName = "system.caf"

    /// `~/Library/Application Support/LARP/`
    static var applicationSupportFolder: URL {
        URL.applicationSupportDirectory.appending(path: folderName, directoryHint: .isDirectory)
    }

    /// SwiftData store file.
    static var storeURL: URL {
        applicationSupportFolder.appending(path: storeFileName)
    }

    /// `Recordings/`
    static var recordingsFolder: URL {
        applicationSupportFolder.appending(path: recordingsFolderName, directoryHint: .isDirectory)
    }

    /// `Recordings/<call id>/`
    static func recordingsFolder(callID: UUID) -> URL {
        recordingsFolder.appending(path: callID.uuidString, directoryHint: .isDirectory)
    }

    /// Path relative to `applicationSupportFolder`: `Recordings/<call id>/<file name>`.
    static func audioPath(callID: UUID, fileName: String) -> String {
        "\(recordingsFolderName)/\(callID.uuidString)/\(fileName)"
    }
}
