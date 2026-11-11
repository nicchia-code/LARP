# Playback

Listening to the audio of the call shown in the archive window: the microphone and system audio tracks play together, and the transcript line being heard follows the time reached. The audio of a call is loaded only once it is no longer being recorded; tracks that are missing, empty or unreadable are skipped, and when none can be read the call has no audio to play and the controls say "Audio non disponibile".

## States

### Stopped (initial)
Nothing plays, the time is at the beginning and no line is highlighted; moving the position is ignored.
- `user.PLAY` → Playing: only if the call has audio to play; from the beginning.
- `user.SELECT_SENTENCE` → Playing: only if the call has audio to play; from the start of the line clicked.
- `recorder.RECORDING_STOPPED` → Stopped: when the call shown is the one just recorded, its audio is loaded.
- `user.SELECT_CALL` → Stopped: the audio of the new call is loaded in place of the previous one.

### Playing
The time reached and the line being heard are updated regularly.
- `user.PAUSE` → Paused: the time reached is kept.
- `user.SEEK` → Playing: goes on from the new time, kept within the length of the audio.
- `user.SELECT_SENTENCE` → Playing: goes on from the start of the line clicked.
- `PLAYBACK_ENDED` → Stopped: the time goes back to the beginning.
- `macos.AUDIO_DEVICES_CHANGED` → Playing: the audio goes on from the time reached on the new output.
- `macos.AUDIO_DEVICES_CHANGED` → Paused: when the audio cannot start again on the new output; the time reached is kept, without any notice.
- `macos.AUDIO_DEVICES_CHANGED` → Stopped: when the time reached was already the end of the audio.
- `user.CLOSE_WINDOW` → Stopped
- `user.SELECT_CALL` → Stopped: only for another call; its audio is loaded in place of the previous one.
- `user.DESELECT_CALL` → Stopped: the audio is unloaded.
- `user.DELETE_CALL` → Stopped: the audio is unloaded.
- `call.DELETED` → Stopped: only for the call shown; the audio is unloaded.

### Paused
The audio is held at the time reached, and the line of that time stays highlighted.
- `user.PLAY` → Playing: from the time reached.
- `user.SELECT_SENTENCE` → Playing: from the start of the line clicked.
- `user.SEEK` → Paused: the time and the highlighted line move to the new time, kept within the length of the audio.
- `user.CLOSE_WINDOW` → Stopped
- `user.SELECT_CALL` → Stopped: only for another call; its audio is loaded in place of the previous one.
- `user.DESELECT_CALL` → Stopped: the audio is unloaded.
- `user.DELETE_CALL` → Stopped: the audio is unloaded.
- `call.DELETED` → Stopped: only for the call shown; the audio is unloaded.

## Events

### PLAYBACK_ENDED
Emitted when the audio reaches its end, when nothing is left to play from the time asked, or when the audio cannot start at all.
