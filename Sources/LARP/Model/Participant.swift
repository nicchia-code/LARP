import Foundation
import SwiftData

/// A participant of a call, told apart by speaker separation. Belongs to one call only.
@Model
final class Participant {
    /// 1, 2, … within the call.
    var number: Int
    /// Name set by the user.
    var name: String?
    var call: Call?

    @Relationship(deleteRule: .nullify, inverse: \TranscriptLine.participant)
    var lines: [TranscriptLine] = []

    init(number: Int, name: String? = nil) {
        self.number = number
        self.name = name
    }
}
