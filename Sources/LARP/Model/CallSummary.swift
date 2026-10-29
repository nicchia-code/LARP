import Foundation
import SwiftData

/// A next step of a summary, with its optional owner.
struct SummaryNextStep: Codable, Hashable, Sendable {
    var text: String
    /// "Io" or "Partecipante <number>", exactly as the assistant wrote it; `nil` when the
    /// step has no owner. Names given by the user replace it only when the summary is
    /// shown, searched or exported, never in the stored value.
    var owner: String?

    init(text: String, owner: String? = nil) {
        self.text = text
        self.owner = owner
    }
}

/// The summary of a call, as the assistant wrote it. A call holds at most one.
@Model
final class CallSummary {
    /// Key concepts, in order.
    var keyConcepts: [String]
    /// Decisions, in order.
    var decisions: [String]
    /// Next steps, in order.
    var nextSteps: [SummaryNextStep]
    /// Free text.
    var text: String
    /// Language the summary is written in, as a locale identifier (e.g. `it-IT`).
    var language: String
    /// When the summary was written.
    var writtenAt: Date
    var call: Call?

    init(
        keyConcepts: [String] = [],
        decisions: [String] = [],
        nextSteps: [SummaryNextStep] = [],
        text: String = "",
        language: String,
        writtenAt: Date = .now
    ) {
        self.keyConcepts = keyConcepts
        self.decisions = decisions
        self.nextSteps = nextSteps
        self.text = text
        self.language = language
        self.writtenAt = writtenAt
    }
}
