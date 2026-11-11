import Foundation
import SwiftData

/// A note the user wrote on a call. It belongs to one call and is never sent to the
/// assistant; like a bookmark it is not tied to a transcript line.
@Model
final class Note {
    @Attribute(.unique) var id: UUID
    /// Trimmed and never empty.
    var text: String
    /// Seconds from the start of the call; `nil` for a note written without listening.
    var time: TimeInterval?
    /// When the note was written; orders the notes without time.
    var writtenAt: Date
    var call: Call?

    init(id: UUID = UUID(), text: String, time: TimeInterval? = nil, writtenAt: Date = .now) {
        self.id = id
        self.text = text
        self.time = time.map(Self.normalizedTime)
        self.writtenAt = writtenAt
    }

    /// `text` without surrounding whitespace, `nil` when nothing is left.
    static func normalizedText(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A time in seconds, never below zero.
    static func normalizedTime(_ time: TimeInterval) -> TimeInterval {
        time.isFinite ? max(0, time) : 0
    }
}

extension Call {
    /// The bookmarks of the call in order of time.
    var sortedBookmarks: [Bookmark] {
        bookmarks.sorted { $0.time < $1.time }
    }

    /// The notes of the call by time; those without time come after the others, in the
    /// order they were written.
    var sortedNotes: [Note] {
        notes.sorted { lhs, rhs in
            switch (lhs.time, rhs.time) {
            case (let left?, let right?): left != right ? left < right : lhs.writtenAt < rhs.writtenAt
            case (_?, nil): true
            case (nil, _?): false
            case (nil, nil): lhs.writtenAt < rhs.writtenAt
            }
        }
    }
}
