# Call

One call, from its recording or the import of an audio file to a transcript whose lines say who spoke. It is created when the recorder starts a recording, unless a call is already being recorded, or when the user imports an audio file. A recorded call takes the time of the start, the call app the recording is tied to (none for a recording started by hand) and the transcription language chosen at that moment, which stays the call's language; when the recording starts it also takes, as its meeting title, the title of the meeting Teams shows, else the title of the calendar event in progress while the calendar is connected, and, as names for its participants, the people Teams shows and the people invited to that event. An imported call takes as title the name of the file without its extension, as start the time the file was last modified, as duration the length of its audio, no call app and the transcription language chosen at that moment; its audio becomes the system audio track and it has no microphone track, so every voice in it becomes a participant and none is "Io". The title shown is the one the user gave, else the meeting title, else the default title. Once the transcript is complete, the waveform of the call is worked out once from its audio on the Mac, coloured by who speaks; calls of an earlier version get it the same way, in the background, when their audio is there.

## States

### Created (initial)
The call has just been made.
- `recorder.RECORDING_STARTED` → Recording
- `user.IMPORT_AUDIO` → Transcribing: only if the call's language is ready; the file has been converted into the system audio track of the call.
- `user.IMPORT_AUDIO` → Awaiting language: only if the call's language is not ready; the file has been converted into the system audio track of the call.

### Recording
The microphone and the system audio are saved as two separate tracks while the call goes on; a recording started by hand goes on with the microphone alone when the system audio cannot start. When the call's language is ready at the moment the recording starts, both tracks are also transcribed live: the microphone as "Io", the system audio as "Altri", and the audio captured while the live transcription is getting ready is given to it, so it covers the whole recording. A language that becomes ready later does not start the live transcription halfway, and a live transcription that cannot start leaves the recording going on without it. Every final line of the live transcription is added to the call as it comes; the text still being recognised is shown in the live window and never stored. While the recording is paused both tracks are saved with silence and the live transcription goes on over that silence. Bookmarks and notes may be added to the call while it is recorded. The call can be neither renamed nor deleted.
- `microphone.START_FAILED` → Deleted: the call created for this recording is removed with its audio folder and the user is told that the recording did not start, with the reason; DELETED is not emitted.
- `system-audio.START_FAILED` → Deleted: the call created for this recording is removed with its audio folder and the user is told that the recording did not start, with the reason; DELETED is not emitted.
- `recorder.RECORDING_STOPPED` → Separating participants: when the whole recording was transcribed live; the capture stops, the call ends at that moment and keeps its live lines.
- `recorder.RECORDING_STOPPED` → Transcribing: when part of the recording was not transcribed live, or there was no live transcription, and the call's language is ready; the call ends at that moment and its live lines are discarded.
- `recorder.RECORDING_STOPPED` → Awaiting language: when part of the recording was not transcribed live, or there was no live transcription, and the call's language is not ready; the call ends at that moment and its live lines are discarded.
- `macos.APP_LAUNCHED` → Transcribing: the app was closed or the Mac turned off during the recording; before anything else is handled, the call ends at the end of the longer of its two saved tracks (no length when neither can be read) and its lines are discarded; only if the call's language is ready.
- `macos.APP_LAUNCHED` → Awaiting language: the app was closed or the Mac turned off during the recording; the call ends at the end of the longer of its two saved tracks and its lines are discarded; only if the call's language is not ready.

### Awaiting language
The audio is kept but there is no transcript yet, because the speech model of the call's language is not installed on the Mac. The call waits for its own language, whatever language is chosen now; a launch of the app does not look at it again.
- `transcription-language.LANGUAGE_READY` → Transcribing: only if the language that became ready is the call's language.
- `user.RENAME_CALL` → Awaiting language: the call takes the new title.
- `user.DELETE_CALL` → Deleted: emits DELETED.

### Transcribing
Both tracks are transcribed from the saved audio in the call's language, at the same time, the microphone as "Io" and the system audio as "Altri", and their lines are merged in order of start; a missing or empty track gives no lines. The calls in Transcribing are transcribed one at a time, the oldest first, and every transcription starts from the beginning, discarding any partial transcript first. That a transcription failed is not stored with the call: it is forgotten when the app is closed.
- `macos.APP_LAUNCHED` → Transcribing: the app was closed during the transcription, which starts again from the beginning; a failure shown before is forgotten.
- `user.RENAME_CALL` → Transcribing: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the transcription in progress, or the wait before trying it again, stops; emits DELETED.

#### Transcribing audio (initial)
The call waits for its turn or is being transcribed.
- `TRANSCRIPTION_COMPLETED` → Separating participants: the lines are added to the call and a failure shown before is cleared.
- `TRANSCRIPTION_FAILED` → Awaiting transcription retry: the call shows that its transcription failed and will be tried again shortly.

#### Awaiting transcription retry
The call keeps showing the failure and is skipped while the other calls waiting are transcribed.
- `time.TRANSCRIPTION_RETRY_DUE` → Transcribing audio: tried again, as many times as it takes; the failure stays shown until a transcription succeeds.

### Separating participants
The transcript can already be read with "Io" and "Altri". The voices of the system audio are told apart on the Mac and every line that is not of "Io" is given to "Partecipante 1", "Partecipante 2" and so on, by voice; the participants of an earlier separation of the call are replaced. When no line is of the others, the audio is not analysed and the call has no participants. The first separation on the Mac downloads the voice models. When the separation ends, while speaker identification is on and the call holds a timeline of the speakers shown by Teams, every participant takes the name Teams marked as speaking for most of the time of its lines, when that name covers at least 70% of it; the others stay "Partecipante" and their number.
- `PARTICIPANTS_SEPARATED` → Refining transcript: only if transcript refinement is on.
- `PARTICIPANTS_SEPARATED` → Ready: only if transcript refinement is off.
- `SEPARATION_FAILED` → Awaiting separation retry: the transcript stays with "Io" and "Altri".
- `macos.APP_LAUNCHED` → Separating participants: the app was closed during the separation, which starts again.
- `user.RENAME_CALL` → Separating participants: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the separation stops; emits DELETED.

### Awaiting separation retry
The transcript can be read with "Io" and "Altri"; telling the participants apart failed and will be tried again on its own.
- `macos.NETWORK_AVAILABLE` → Separating participants: tries again.
- `macos.APP_LAUNCHED` → Separating participants: tries again.
- `user.RENAME_CALL` → Awaiting separation retry: the call takes the new title.
- `user.DELETE_CALL` → Deleted: emits DELETED.

### Refining transcript
The transcript can already be read as transcription and separation left it. The original lines of the call, with who spoke each line and when, are sent to omp in a process of its own, never the audio, the title, the names given by the user, the dates or the call app; a call refined before is sent with its original text and speakers, never with the refined ones. omp corrects the words recognised wrongly and may move lines among the participants already present. When a line of the others has no participant, nothing is sent and the refinement fails. The summary of the call, if it is being written, goes on alongside.
- `TRANSCRIPT_REFINED` → Ready: every line takes its corrected text and speaker; the text and speaker a line had before its first refinement are kept, and later refinements never overwrite them.
- `REFINEMENT_FAILED` → Awaiting refinement retry: the transcript stays as it was.
- `user.TURN_OFF_REFINEMENT` → Ready: the omp process is ended at once and the transcript stays as it was.
- `macos.APP_LAUNCHED` → Refining transcript: the app was closed during the refinement, which starts again, also when refinement was turned off meanwhile.
- `user.RENAME_CALL` → Refining transcript: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the refinement stops and its omp process is ended; emits DELETED.

### Awaiting refinement retry
The transcript can be read as transcription and separation left it; refining it failed and will be tried again on its own.
- `macos.NETWORK_AVAILABLE` → Refining transcript: tries again.
- `macos.APP_LAUNCHED` → Refining transcript: tries again, also when refinement is off.
- `user.REFINE_TRANSCRIPT` → Refining transcript: tries again at once, also when refinement is off.
- `user.TURN_OFF_REFINEMENT` → Ready: no further attempt; the transcript stays as it was.
- `user.RENAME_CALL` → Awaiting refinement retry: the call takes the new title.
- `user.DELETE_CALL` → Deleted: emits DELETED.

### Ready
The transcript is complete and every line says who spoke: "Io" or one of the participants, named "Partecipante" and their number until the user names them.
- `user.RENAME_CALL` → Ready: the call takes the new title.
- `user.RENAME_PARTICIPANT` → Ready: the participant takes the new name everywhere in this call's transcript, and only in this call; an empty name gives back "Partecipante" and the number. Participants can be renamed only here.
- `user.REFINE_TRANSCRIPT` → Refining transcript: only if transcript refinement is on; also for a call refined before.
- `user.RESTORE_TRANSCRIPT` → Ready: only if the transcript has been refined, also while refinement is off; every line gets back its original text, speaker and participant, and the kept originals are cleared, so the call counts as not refined.
- `user.EDIT_LINE` → Ready: only for a line of this call and a text that is not empty once trimmed; the line takes the new text, and when it keeps an original from a refinement its original text takes the new text too, so that a later refinement starts from it and restoring brings it back; its speaker and original speaker do not change, and a correction alone never makes the call count as refined.
- `user.DELETE_CALL` → Deleted: emits DELETED.

### Deleted (final)
The call, its audio folder, its transcript, its participants, its summary, its bookmarks and its notes no longer exist.

## Events

### TRANSCRIPTION_COMPLETED
Emitted when both tracks of the saved audio have been transcribed and their lines added to the call.

### TRANSCRIPTION_FAILED
Emitted when transcribing the saved audio of a call failed; never when the transcription was stopped because the call was deleted.

### PARTICIPANTS_SEPARATED
Emitted when every line of the others has been given to a participant, also when the call had no line of the others. The summary of the call may start writing.

### SEPARATION_FAILED
Emitted when telling the voices apart could not be done, for example because the voice models could not be downloaded.

### TRANSCRIPT_REFINED
Emitted when omp has answered with a valid correction for every line sent and the corrections have been applied to the call.

### REFINEMENT_FAILED
Emitted when refining could not be done: omp is not found, ends, answers with an error or does not answer completely within its time limit; its answer does not match the lines sent or names a participant the call does not have; or a line of the others has no participant, so nothing was sent. Never when the refinement was stopped because it was turned off, replaced or the call was deleted.

### DELETED
Emitted when a call the user chose to delete has been removed: every work running for it (transcription or its pending retry, separation, refinement, summary) has been stopped first, then the call goes from the archive with its audio folder, its bookmarks and its notes. When the archive cannot remove it, the work stays stopped, the call stays where it was and this Event is not emitted.
