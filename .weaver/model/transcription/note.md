# Note

A note the user wrote about a call. It is created by `user.ADD_NOTE` with a text that is not empty once trimmed: in the live window, for the call being recorded, with the elapsed time; in the notes of a call page, with the time reached when the audio of the call is playing or paused, and with no time otherwise. Notes are shown in order of time, the notes without time after the others in the order they were written. Notes are never sent to omp.

## States

### Kept (initial)
The note is shown in the notes of its call, and in the live window while the call is recorded.
- `user.EDIT_NOTE` → Kept: only for this note and only if the new text, trimmed, is not empty; the note takes the new text and keeps its time.
- `user.EDIT_NOTE` → Deleted: only for this note, when the new text is empty once trimmed.
- `user.DELETE_NOTE` → Deleted: only for this note.
- `call.DELETED` → Deleted: only for the call of the note; it goes with the call.

### Deleted (final)
The note no longer exists.
