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
- `CAPTURE_FAILED` → Deleted: the recording could not start; the call, which has nothing recorded, is deleted and the user is not told.

### Awaiting language
The audio is kept but there is no transcript yet, because the chosen language is not installed on the Mac.
- `transcription-language.LANGUAGE_READY` → Transcribing
- `user.RENAME_CALL` → Awaiting language: the call takes the new title.
- `user.DELETE_CALL` → Deleted: its audio is deleted.

### Transcribing
Both tracks are transcribed from the saved audio in the chosen language, the microphone as "Me" and the system audio as "Others".
- `TRANSCRIPTION_COMPLETED` → Separating participants
- `macos.APP_LAUNCHED` → Transcribing: the app was closed during the transcription, which starts again from the beginning.
- `TRANSCRIPTION_FAILED` → Transcribing: the transcription of the saved audio did not succeed; the call stays as it is and the transcription starts again from the beginning at the next launch of the app, without telling the user.
- `user.RENAME_CALL` → Transcribing: the call takes the new title.
- `user.DELETE_CALL` → Deleted: the transcription stops and the audio and any partial transcript are deleted.

### Separating participants
The transcript can already be read with "Me" and "Others". The system audio is analysed by voice to tell the other participants apart.
- `PARTICIPANTS_SEPARATED` → Ready: every "Others" line is given to "Participant 1", "Participant 2" and so on, by voice.
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

### Ready
The transcript is complete and every line says who spoke: "Me" or one of the participants.
- `user.RENAME_CALL` → Ready: the call takes the new title.
- `user.RENAME_PARTICIPANT` → Ready: the participant takes the new name everywhere in this call's transcript, and only in this call.
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

### DELETED
Emitted when the call has been deleted.

### CAPTURE_FAILED
Emitted when the capture of the microphone or of the system audio could not start after the recording was started, for example because a permission was revoked.

### TRANSCRIPTION_FAILED
Emitted when the transcription of the saved audio could not be completed.
