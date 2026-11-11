# Main window

The main window of LARP: a dark sidebar on the left and, beside it, one page at a time: the library of the recorded calls, the page of one call, or the settings. The sidebar shows the LARP mark, "Nuova registrazione" with the shortcut to start recording, "Tutte le call", "Segnalibri" and, at the bottom, "Impostazioni". "Nuova registrazione" starts a recording by hand, as "Registra" does in the popover, and is available only while nothing is proposed or recorded; the window does not change.

## States

### Closed (initial)
The main window is not shown.
- `user.OPEN_WINDOW` → Library: the app comes to the front and the window is shown on the library.
- `user.OPEN_SETTINGS` → Settings shown: the app comes to the front and the window is shown on the settings.

### Open
The window is shown on one of its pages.
- `user.CLOSE_WINDOW` → Closed: the playback stops.
- `user.OPEN_SETTINGS` → Settings shown: the page shown before is left; the audio of a call shown is unloaded.

#### Library (initial)
The pages of the archive. At the top a line with today's day and the number of calls started today, the title of the view and the search field; the search typed stays when a call is opened and the library comes back. While a proposal to record is shown, a dark banner "In onda ora" with the name of the call app, "Registra questa call" and "Non questa" sits at the top and accepts or discards the proposal.
- `user.SHOW_ALL_CALLS` → All calls
- `user.SHOW_BOOKMARKS_VIEW` → Bookmarks view

##### All calls (initial)
The title is "Tutto quello che è stato detto.". One card per call that matches the search, newest first: day and time, call app ("Manuale" for a recording started by hand), title, the first key concept of its summary or else its status, the initials of its participants, its duration (not while recording) and a chip with its status. With an empty archive the page says "Nessuna registrazione"; when no call matches the search it says that nothing was found.
- `user.SELECT_CALL` → Call shown: the page of the call opens on its summary and its audio is loaded for playback.

##### Bookmarks view
The title is "Segnalibri". The bookmarks of the calls that match the search, grouped by call, newest call first and in order of time within a call: each shows its time and the text of the transcript line at that time, if any. Without bookmarks the page says "Nessun segnalibro".
- `user.SELECT_BOOKMARK` → Call shown: the page of the call of the bookmark opens on its bookmarks, its audio is loaded and plays from the bookmark.

#### Call shown
The page of one call. At the top "‹ Archivio" on the left and, on the right, "Esporta" and a menu "…" with "Rifinisci testo", "Ripristina originale" and "Elimina", each enabled only when the call allows it; refinement and restoring are passed to the call, and the page does not change. Below, a line with the call app, the day and time and the duration (not while recording), then the title in large type, which can be edited with a click unless the call is still being recorded, and the status of the call. On the left the tabs "Sintesi", "Le mie note" and "Segnalibri". On the right the transcript panel: the lines in order, each with speaker, time and text, the line at the time of a bookmark marked "Segnalibro"; the line being heard is highlighted and kept in the middle; during a recording the lines appear as they come. Without lines it says "Nessuna trascrizione" for a finished call, otherwise that the transcript is not available yet. At the bottom, across the page, the playback bar, unless the call is being recorded, with "Segnalibro" to mark the time reached.
- `user.DESELECT_CALL` → Library: the audio is unloaded; the library comes back on the view it showed before.
- `user.ASK_TO_DELETE` → Confirming deletion: only when the call is not being recorded.
- `user.RENAME_CALL` → Call shown: when the title is confirmed or the field loses focus, and only if it changed; the tab shown stays the same.
- `user.RENAME_PARTICIPANT` → Call shown: after a click on a participant's name in the transcript and confirmation of the new name; the tab shown stays the same.
- `user.EXPORT_CALL` → Call shown: only if the call has transcript lines, whatever its state; the system save panel offers the Markdown file with the default name, and its outcome is not reported; the tab shown stays the same.
- `call.DELETED` → Library: only if the deleted call is the one shown; the audio is unloaded.

##### Summary shown (initial)
The summary: its state and, when there is one, its sections, read-only; "Sintetizza" when the call has no summary and "Rigenera" when it has one, each enabled only when the summary of the call allows it and passed to it; a summary written while the page is shown appears in place without changing the page.
- `user.SHOW_NOTES` → Notes shown
- `user.SHOW_BOOKMARKS` → Bookmarks shown

##### Notes shown
The notes of the call in order of time, each with its time when it has one, its text, which can be edited in place, and a way to delete it; a field to write a new note. Without notes it says "Nessuna nota".
- `user.SHOW_SUMMARY` → Summary shown
- `user.SHOW_BOOKMARKS` → Bookmarks shown

##### Bookmarks shown
The bookmarks of the call in order of time, each with its time, the text of the transcript line at that time, if any, and a way to delete it; a click plays the audio from it. Without bookmarks it says "Nessun segnalibro".
- `user.SHOW_SUMMARY` → Summary shown
- `user.SHOW_NOTES` → Notes shown

#### Confirming deletion
The dialog "Eliminare la call?" asks to confirm that the audio and the transcript will be deleted for good.
- `user.CANCEL_DELETION` → Call shown: the call stays as it was, on the tab shown before.
- `user.DELETE_CALL` → Library: the call is deleted with its audio, transcript, participants, summary, bookmarks and notes; the audio is unloaded; the library comes back on the view it showed before.

#### Settings shown
The page of the settings. The sidebar shows "‹ Archivio" and the names of the sections of the settings, and a click on a name brings its section into view; the page shows the sections as cards.
- `user.CLOSE_SETTINGS` → Library
