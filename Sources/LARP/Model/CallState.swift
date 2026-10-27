import Foundation

/// Current state of a call in its life cycle.
enum CallState: String, Codable, CaseIterable, Sendable {
    case recording
    case awaitingLanguage
    case transcribing
    case separatingParticipants
    case awaitingSeparationRetry
    case refiningTranscript
    case awaitingRefinementRetry
    case ready
}
