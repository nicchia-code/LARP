import Foundation
import SwiftData

/// A decision of a summary.
struct SummaryDecision: Codable, Hashable, Sendable {
    var text: String
    /// Start, in seconds from the start of the call, of the line the assistant named when it
    /// wrote the summary; `nil` when it named none or not one of the lines sent.
    var lineStart: Double?

    init(text: String, lineStart: Double? = nil) {
        self.text = text
        self.lineStart = lineStart
    }
}

/// An action item of a summary: what to do, who does it and by when, as said in the call.
struct SummaryActionItem: Codable, Hashable, Sendable {
    var text: String
    /// "Io" or "Partecipante <number>", exactly as the assistant wrote it; `nil` when the
    /// action has no owner. Names given by the user replace it only when the summary is
    /// shown, searched or exported, never in the stored value.
    var owner: String?
    /// The due as said in the call (for example "venerdì"), never a computed date; `nil` when
    /// none was said.
    var due: String?
    /// Whether the user ticked the action as done.
    var isDone: Bool

    init(text: String, owner: String? = nil, due: String? = nil, isDone: Bool = false) {
        self.text = text
        self.owner = owner
        self.due = due
        self.isDone = isDone
    }
}

/// The "next step" of a summary written before action items existed. Only read, to open such a
/// summary: it stays in the store under its own name so that an archive saved before opens.
struct SummaryNextStep: Codable, Hashable, Sendable {
    var text: String
    var owner: String?

    init(text: String, owner: String? = nil) {
        self.text = text
        self.owner = owner
    }
}

/// The summary of a call, as the assistant wrote it. A call holds at most one.
@Model
final class CallSummary {
    /// The opening sentence; empty for a summary written before it existed.
    var opening: String = ""
    /// The key part of the opening sentence; empty when none.
    var openingHighlight: String = ""
    /// Key concepts, in order.
    var keyConcepts: [String]
    /// What was left open, in order. Empty for a summary written before it existed.
    var openQuestions: [String] = []
    /// Free text.
    var text: String
    /// Language the summary is asked in, as a locale identifier (e.g. `it-IT`).
    var language: String
    /// When the summary was written.
    var writtenAt: Date
    var call: Call?

    /// The decisions of a summary written before decisions had a line: texts only. Read through
    /// `decisions`; never written again.
    private var decisions: [String]
    /// The next steps of a summary written before action items existed. Read through
    /// `actionItems`; never written again.
    private var nextSteps: [SummaryNextStep]
    /// The decisions and the action items as stored now. While empty on a summary written
    /// before, `decisions` and `actionItems` read it from the two properties above.
    private var storedDecisions: [SummaryDecision] = []
    private var storedActionItems: [SummaryActionItem] = []

    /// Decisions, in order. A summary written before decisions had a line opens with them
    /// without line.
    var decisionItems: [SummaryDecision] {
        get { storedDecisions.isEmpty ? decisions.map { SummaryDecision(text: $0) } : storedDecisions }
        set {
            storedDecisions = newValue
            decisions = []
        }
    }

    /// Action items, in order. A summary written before them opens with its next steps as
    /// actions without due and not done.
    var actionItems: [SummaryActionItem] {
        get {
            storedActionItems.isEmpty
                ? nextSteps.map { SummaryActionItem(text: $0.text, owner: $0.owner) } : storedActionItems
        }
        set {
            storedActionItems = newValue
            nextSteps = []
        }
    }

    init(
        opening: String = "",
        openingHighlight: String = "",
        keyConcepts: [String] = [],
        decisionItems: [SummaryDecision] = [],
        actionItems: [SummaryActionItem] = [],
        openQuestions: [String] = [],
        text: String = "",
        language: String,
        writtenAt: Date = .now
    ) {
        self.opening = opening
        self.openingHighlight = openingHighlight
        self.keyConcepts = keyConcepts
        self.openQuestions = openQuestions
        self.text = text
        self.language = language
        self.writtenAt = writtenAt
        self.decisions = []
        self.nextSteps = []
        self.storedDecisions = decisionItems
        self.storedActionItems = actionItems
    }
}
