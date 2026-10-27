import Foundation

/// Who speaks a transcript line: the user (`me`, microphone track), the other
/// parties as a whole (`others`, system track) or a separated participant.
enum SpeakerKind: String, Codable, CaseIterable, Sendable {
    case me
    case others
    case participant
}
