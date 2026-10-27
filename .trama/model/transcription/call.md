# Call

One recorded call, from its recording to a transcript whose lines say who spoke. It is created when the recorder starts a recording.

## States

### Recording (initial)
The microphone and the system audio are saved continuously as two separate tracks, so that what was recorded survives if the app is closed. When the chosen language is ready, both tracks are transcribed live in the background: the microphone as "Me", the system audio as "Others". Nothing of the transcript is shown while recording.
- `recorder.RECORDING_STOPPED` → Separating participants: when the whole recording has been transcribed live.
- `recorder.RECORDING_STOPPED` → Transcribing: when part of the recording was not transcribed live and the chosen language is ready.
- `recorder.RECORDING_STOPPED` → Awaiting language: when the chosen language is not ready.
- `macos.APP_LAUNCHED` → Transcribing: the app was closed or the Mac turned off during the recording; the call ends at the last audio saved and, when the chosen language is ready, is transcribed again from its audio.
- `macos.APP_LAUNCHED` → Awaiting language: the app was closed or the Mac turned off during the recording and the chosen language is not ready; the call ends at the last audio saved.

### Awaiting language
The audio is kept but there is no transcript yet, because the chosen language is not installed on the Mac.
- `transcription-language.LANGUAGE_READY` → Transcribing
- `user.RENAME_CALL` → Awaiting language: the call takes the new title.
- `user.DELETE_CALL` → Deleted: its audio is deleted.

### Transcribing
Both tracks are transcribed from the saved audio in the chosen language, the microphone as "Me" and the system audio as "Others".
- `TRANSCRIPTION_COMPLETED` → Separating participants
- `macos.APP_LAUNCHED` → Transcribing: the app was closed during the transcription, which starts again from the beginning.
- `user.RENAME_CALL` → Transcribing: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the transcription stops and the audio and any partial transcript are deleted.

### Separating participants
The transcript can already be read with "Me" and "Others". The system audio is analysed by voice to tell the other participants apart.
- `PARTICIPANTS_SEPARATED` → Ready: when transcript refinement is off; every "Others" line is given to "Participant 1", "Participant 2" and so on, by voice.
- `PARTICIPANTS_SEPARATED` → Refining transcript: when transcript refinement is on; every "Others" line is given to "Participant 1", "Participant 2" and so on, by voice.
- `SEPARATION_FAILED` → Awaiting separation retry: the transcript stays with "Me" and "Others".
- `macos.APP_LAUNCHED` → Separating participants: the app was closed during the separation, which starts again.
- `user.RENAME_CALL` → Separating participants: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the separation stops and the audio and transcript are deleted.

### Awaiting separation retry
The transcript can be read with "Me" and "Others"; telling the participants apart failed and will be tried again on its own.
- `macos.NETWORK_AVAILABLE` → Separating participants: tries again.
- `macos.APP_LAUNCHED` → Separating participants: tries again.
- `user.RENAME_CALL` → Awaiting separation retry: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the audio and transcript are deleted.

### Refining transcript
The transcript can already be read as transcription and separation left it. The original text of its lines, with who spoke each line and when, is sent to the assistant, never the audio, to correct the words recognised wrongly and the lines given to the wrong participant. Every refinement starts from the original lines, never from an earlier refinement.
- `TRANSCRIPT_REFINED` → Ready: every line takes the corrected text and participant; the original text and speaker of every line are kept.
- `REFINEMENT_FAILED` → Awaiting refinement retry: the transcript stays as it was.
- `user.TURN_OFF_REFINEMENT` → Ready: the refinement stops and the transcript stays as it was.
- `macos.APP_LAUNCHED` → Refining transcript: the app was closed during the refinement, which starts again.
- `user.RENAME_CALL` → Refining transcript: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the refinement stops and the audio and transcript are deleted.

### Awaiting refinement retry
The transcript can be read as transcription and separation left it; refining it failed and will be tried again on its own.
- `macos.NETWORK_AVAILABLE` → Refining transcript: tries again.
- `macos.APP_LAUNCHED` → Refining transcript: tries again.
- `user.REFINE_TRANSCRIPT` → Refining transcript: tries again at once.
- `user.TURN_OFF_REFINEMENT` → Ready: no further attempt; the transcript stays as it was.
- `user.RENAME_CALL` → Awaiting refinement retry: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the audio and transcript are deleted.

### Ready
The transcript is complete and every line says who spoke: "Me" or one of the participants.
- `user.RENAME_CALL` → Ready: the call takes the new title.
- `user.RENAME_PARTICIPANT` → Ready: the participant takes the new name everywhere in this call's transcript, and only in this call.
- `user.REFINE_TRANSCRIPT` → Refining transcript: only if transcript refinement is on; also for a call refined before, and for calls recorded before refinement existed.
- `user.RESTORE_TRANSCRIPT` → Ready: only if the transcript has been refined; every line gets back its original text and speaker, and the call is refined again only when the user asks.
- `user.DELETE_CALL` → Deleted: the audio and transcript are deleted.

### Deleted (final)
The call, its audio and its transcript no longer exist.

## Events

### TRANSCRIPTION_COMPLETED
Emitted when both tracks of the saved audio have been transcribed.

### PARTICIPANTS_SEPARATED
Emitted when every "Others" line has been given to a participant.

### SEPARATION_FAILED
Emitted when telling the participants apart could not be done, for example because the voice models could not be downloaded.

### TRANSCRIPT_REFINED
Emitted when the assistant has answered with a correction for every line sent and the corrections have been applied.

### REFINEMENT_FAILED
Emitted when refining could not be done: the assistant cannot be reached, does not answer in time, or its answer does not match the lines sent.

### DELETED
Emitted when the call has been deleted.
