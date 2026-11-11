import Foundation

/// The `bookmark` and `note` machines: the moments the user marked and the notes the user wrote,
/// as data of a call. They are not tied to transcript lines, so they stay when the live lines of
/// a call are discarded and it is transcribed again, and go with the call when it is deleted
/// (`call.DELETED`, by the cascade of the archive). They are never sent to the assistant.
extension CallLifecycle {
    // MARK: - Bookmarks

    /// `user.ADD_BOOKMARK` on the call being recorded: at `seconds` elapsed since its start,
    /// also while the recording is paused. Does nothing when no call is being recorded.
    @discardableResult
    func addBookmarkToActiveRecording(atSeconds seconds: TimeInterval) -> Bookmark? {
        guard let call = activeRecording?.call else { return nil }
        return addBookmark(to: call, at: seconds)
    }

    /// `user.ADD_BOOKMARK` on a call: at `time` seconds, whole and never below zero. A bookmark
    /// at the same second as another one of the call is not created again; `nil` then.
    @discardableResult
    func addBookmark(to call: Call, at time: TimeInterval) -> Bookmark? {
        let second = Bookmark.normalizedTime(time)
        guard !call.bookmarks.contains(where: { $0.time == second }) else { return nil }
        let bookmark = Bookmark(time: second)
        call.bookmarks.append(bookmark)
        save()
        callChanges.emit(.exportChanged(call.id))
        return bookmark
    }

    /// `user.DELETE_BOOKMARK`: the bookmark disappears everywhere.
    func deleteBookmark(_ bookmark: Bookmark) {
        let callID = bookmark.call?.id
        context.delete(bookmark)
        save()
        if let callID { callChanges.emit(.exportChanged(callID)) }
    }

    // MARK: - Notes

    /// `user.ADD_NOTE` on the call being recorded, in the live window: at `seconds` elapsed
    /// since its start. Does nothing when no call is being recorded or the text is empty once
    /// trimmed.
    @discardableResult
    func addNoteToActiveRecording(_ text: String, atSeconds seconds: TimeInterval) -> Note? {
        guard let call = activeRecording?.call else { return nil }
        return addNote(to: call, text: text, at: seconds)
    }

    /// `user.ADD_NOTE` on a call: at `time` seconds, or without time when it was written
    /// without listening (`nil`). Does nothing when the text is empty once trimmed.
    @discardableResult
    func addNote(to call: Call, text: String, at time: TimeInterval?) -> Note? {
        guard let text = Note.normalizedText(text) else { return nil }
        let note = Note(text: text, time: time, writtenAt: now())
        call.notes.append(note)
        save()
        callChanges.emit(.exportChanged(call.id))
        return note
    }

    /// `user.EDIT_NOTE`: a new text that is not empty once trimmed replaces the text and the
    /// note keeps its time; an empty one deletes the note.
    func editNote(_ note: Note, to text: String) {
        if let text = Note.normalizedText(text) {
            note.text = text
            save()
            if let callID = note.call?.id { callChanges.emit(.exportChanged(callID)) }
        } else {
            deleteNote(note)
        }
    }

    /// `user.DELETE_NOTE`.
    func deleteNote(_ note: Note) {
        let callID = note.call?.id
        context.delete(note)
        save()
        if let callID { callChanges.emit(.exportChanged(callID)) }
    }
}
