import Foundation
import SwiftData

/// A recorded call.
@Model
final class Call {
    @Attribute(.unique) var id: UUID
    /// Title set by the user.
    var title: String?
    var startedAt: Date
    /// Absent while the call is being recorded.
    var endedAt: Date?
    /// Length of the call, in seconds.
    var duration: TimeInterval
    /// Name of the call app; `nil` for manual recordings.
    var callAppName: String?
    /// Transcription language, as a locale identifier (e.g. `it-IT`).
    var transcriptionLanguage: String
    private var stateRawValue: String
    /// Path of the microphone audio file, relative to the LARP folder in Application Support.
    var micAudioPath: String
    /// Path of the system audio file, relative to the LARP folder in Application Support.
    var systemAudioPath: String

    @Relationship(deleteRule: .cascade, inverse: \TranscriptLine.call)
    var lines: [TranscriptLine] = []

    @Relationship(deleteRule: .cascade, inverse: \Participant.call)
    var participants: [Participant] = []

    var state: CallState {
        get { CallState(rawValue: stateRawValue) ?? .ready }
        set { stateRawValue = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        title: String? = nil,
        startedAt: Date = .now,
        endedAt: Date? = nil,
        duration: TimeInterval = 0,
        callAppName: String? = nil,
        transcriptionLanguage: String,
        state: CallState = .recording
    ) {
        self.id = id
        self.title = title
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.duration = duration
        self.callAppName = callAppName
        self.transcriptionLanguage = transcriptionLanguage
        self.stateRawValue = state.rawValue
        self.micAudioPath = AppPaths.audioPath(callID: id, fileName: AppPaths.micFileName)
        self.systemAudioPath = AppPaths.audioPath(callID: id, fileName: AppPaths.systemFileName)
    }

    /// Folder holding the audio files of this call.
    var recordingsFolderURL: URL {
        AppPaths.recordingsFolder(callID: id)
    }

    var micAudioURL: URL {
        AppPaths.applicationSupportFolder.appending(path: micAudioPath)
    }

    var systemAudioURL: URL {
        AppPaths.applicationSupportFolder.appending(path: systemAudioPath)
    }
}
