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

    var speakerKind: SpeakerKind {
        get { SpeakerKind(rawValue: speakerKindRawValue) ?? .others }
        set { speakerKindRawValue = newValue.rawValue }
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
