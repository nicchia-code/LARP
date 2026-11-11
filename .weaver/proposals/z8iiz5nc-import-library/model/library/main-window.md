# Main window

The archive window: on the left a search field and the list of calls, newest first; on the right the selected call with its header, the playback controls and either its summary or its transcript.

## States

### Closed (initial)
The archive window is not shown.
- `user.OPEN_WINDOW` → Open: the app comes to the front and the window "Archivio" is shown.

### Open
The list shows the calls that match the search. The toolbar offers export (only when the selected call has transcript lines, whatever its state), refinement, restoring the original, summarizing and deletion, each enabled only when the selected call allows it; refinement, restoring and summarizing are passed to the call, and the window does not change.
- `user.CLOSE_WINDOW` → Closed: the playback stops.

#### No call selected (initial)
The detail shows "Nessuna call selezionata". With an empty archive the list shows "Nessuna registrazione"; when no call matches the search it shows that nothing was found.
- `user.SELECT_CALL` → Summary shown: when the call has a summary; its audio is loaded for playback.
- `user.SELECT_CALL` → Transcript shown: when the call has no summary; its audio is loaded for playback.

#### Call selected
The header shows the title, which can be edited unless the call is still being recorded, the date and time, the duration (not while recording), the call app and the status of the call. The playback controls are shown unless the call is being recorded. A selected call stays shown even when a new search hides it from the list.
- `user.SELECT_CALL` → Summary shown: another call with a summary; the playback of the previous call stops and the new call's audio is loaded.
- `user.SELECT_CALL` → Transcript shown: another call without a summary; the playback of the previous call stops and the new call's audio is loaded.
- `user.DESELECT_CALL` → No call selected: the audio is unloaded.
- `user.ASK_TO_DELETE` → Confirming deletion: only when the call is not being recorded.
- `user.RENAME_CALL` → Call selected: when the title is confirmed or the field loses focus, and only if it changed; the view shown stays the same.
- `user.RENAME_PARTICIPANT` → Call selected: after a click on a participant's name in the transcript and confirmation of the new name; the view shown stays the same.
- `user.EXPORT_CALL` → Call selected: only if the call has transcript lines; the system save panel offers the Markdown file with the default name, and its outcome is not reported.
- `call.DELETED` → No call selected: only if the deleted call is the one shown; the audio is unloaded.

##### Transcript shown (initial)
The transcript lines in order, each with speaker, time and text; the line being heard is highlighted and scrolled to the centre. Without lines it says "Nessuna trascrizione" for a finished call, otherwise that the transcript is not available yet.
- `user.SHOW_SUMMARY` → Summary shown

##### Summary shown
The status of the summary and, when there is one, its sections, read-only. A summary written while the call is shown does not switch the view.
- `user.SHOW_TRANSCRIPT` → Transcript shown

#### Confirming deletion
The dialog "Eliminare la call?" asks to confirm that the audio and the transcript will be deleted for good.
- `user.CANCEL_DELETION` → Call selected: the call stays as it was.
- `user.DELETE_CALL` → No call selected: the call is deleted with its audio, transcript, participants and summary; the audio is unloaded.
