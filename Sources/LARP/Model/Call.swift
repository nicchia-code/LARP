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

    /// The summary of the call; a call holds at most one. Calls stored before summaries
    /// existed have none. Deleted with the call.
    @Relationship(deleteRule: .cascade, inverse: \CallSummary.call)
    var summary: CallSummary?

    /// The moments of the call the user marked. Calls stored before bookmarks existed have
    /// none. Deleted with the call.
    @Relationship(deleteRule: .cascade, inverse: \Bookmark.call)
    var bookmarks: [Bookmark] = []

    /// The notes the user wrote on the call. Calls stored before notes existed have none.
    /// Deleted with the call.
    @Relationship(deleteRule: .cascade, inverse: \Note.call)
    var notes: [Note] = []

    /// State of the summary, separate from `state`. The default value lets a store saved
    /// before summaries existed open with every call in `.none`.
    private var summaryStateRawValue: String = SummaryState.none.rawValue

    /// Whether the call was made by importing an audio file. The default value lets a store saved
    /// before imports existed open with every call as not imported.
    var isImported: Bool = false

    /// The waveform of the call, encoded; absent until it is worked out, and for a call stored before
    /// waveforms existed.
    private var waveformData: Data?

    /// The `Waveform.barCount` bars of the call, `nil` until they are worked out.
    var waveform: [WaveformBar]? {
        get { waveformData.flatMap { try? JSONDecoder().decode([WaveformBar].self, from: $0) } }
        set { waveformData = newValue.flatMap { try? JSONEncoder().encode($0) } }
    }

    /// Name of the file this call has in the Markdown folder, as LARP wrote it; absent until a
    /// file is written. It lets the file be renamed or removed with the call: a file is never
    /// touched unless it is the one named here.
    var markdownFileName: String?

    /// The days of the audio retention in force when the retention deleted the audio files of this
    /// call; absent while the call has its audio, and for a call stored before the retention existed.
    var audioRemovedAfterDays: Int?

    /// The folder the call is in; absent when it is in none, and for a call stored before folders
    /// existed. The folder does not own the call; deleting the folder clears this.
    var folder: Folder?

    /// The title of the meeting, from Teams or the calendar; absent when none was read, and for a
    /// call stored before meeting information existed. It stays on the Mac.
    var meetingTitle: String?

    /// The names the call's participants may have, from Teams and the invited people of the
    /// calendar event, in order and without repeats; absent until one is read, and for a call
    /// stored before meeting information existed.
    private var meetingParticipantNames: [String]?

    /// The timeline of Teams speakers, encoded; absent until a span is kept, and for a call stored
    /// before meeting information existed.
    private var speakerTimelineData: Data?

    /// The names for the participants of the call, in the order they were read.
    var participantNames: [String] {
        get { meetingParticipantNames ?? [] }
        set { meetingParticipantNames = newValue.isEmpty ? nil : newValue }
    }

    /// Who Teams marked as speaking, as one span per change, in order of time.
    var speakerTimeline: [SpeakerSpan] {
        get { speakerTimelineData.flatMap { try? JSONDecoder().decode([SpeakerSpan].self, from: $0) } ?? [] }
        set { speakerTimelineData = newValue.isEmpty ? nil : try? JSONEncoder().encode(newValue) }
    }

    var state: CallState {
        get { CallState(rawValue: stateRawValue) ?? .ready }
        set { stateRawValue = newValue.rawValue }
    }

    var summaryState: SummaryState {
        get { SummaryState(rawValue: summaryStateRawValue) ?? .none }
        set { summaryStateRawValue = newValue.rawValue }
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
