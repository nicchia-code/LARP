import Foundation
import SwiftData

/// A line of the transcript of a call.
@Model
final class TranscriptLine {
    private var speakerKindRawValue: String
    /// Set when `speakerKind` is `.participant`.
    var participant: Participant?
    /// Start of the line, in seconds from the start of the call.
    var start: TimeInterval
    /// End of the line, in seconds from the start of the call.
    var end: TimeInterval
    var text: String
    var call: Call?

    /// Text as transcription left it; set once the call has been refined, cleared by
    /// the restore. A call is refined when its lines hold an original.
    var originalText: String?
    /// Speaker as transcription and separation left it; set together with `originalText`.
    private var originalSpeakerKindRawValue: String?
    /// Number of the participant when the original speaker is a participant. Kept as
    /// a number because the participants of a call do not change once it is refined.
    var originalParticipantNumber: Int?

    var speakerKind: SpeakerKind {
        get { SpeakerKind(rawValue: speakerKindRawValue) ?? .others }
        set { speakerKindRawValue = newValue.rawValue }
    }

    /// The speaker as transcription and separation left it, `nil` while the line has no original.
    var originalSpeakerKind: SpeakerKind? {
        get { originalSpeakerKindRawValue.flatMap { SpeakerKind(rawValue: $0) } }
        set { originalSpeakerKindRawValue = newValue?.rawValue }
    }

    init(
        speakerKind: SpeakerKind,
        participant: Participant? = nil,
        start: TimeInterval,
        end: TimeInterval,
        text: String
    ) {
        self.speakerKindRawValue = speakerKind.rawValue
        self.participant = participant
        self.start = start
        self.end = end
        self.text = text
    }
}
