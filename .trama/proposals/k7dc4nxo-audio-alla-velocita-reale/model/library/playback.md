# Playback

Listening to the audio of the call shown in the main window, with the transcript following along.

## States

### Stopped (initial)
No audio is playing; playing starts from the beginning of the call.
- `user.PLAY` → Playing: from the beginning of the call.
- `user.SELECT_SENTENCE` → Playing: from the start of the clicked sentence.

### Playing
The audio of the call plays at the speed at which it was recorded, on the current audio output of the Mac, and the sentence being heard is highlighted in the transcript.
- `user.PAUSE` → Paused
- `user.SELECT_SENTENCE` → Playing: jumps to the start of the clicked sentence.
- `PLAYBACK_ENDED` → Stopped
- `user.SELECT_CALL` → Stopped
- `user.CLOSE_WINDOW` → Stopped
- `call.DELETED` → Stopped: only if the deleted call is the one playing.
- `macos.AUDIO_DEVICES_CHANGED` → Playing: when the audio can play on the current audio output; it goes on from the point it had reached, on the new output and at the speed at which it was recorded.
- `macos.AUDIO_DEVICES_CHANGED` → Paused: when the audio cannot play on the current audio output; it stays at the point it had reached and the user can press play again.

### Paused
The audio is paused where it was.
- `user.PLAY` → Playing: from where it was paused.
- `user.SELECT_SENTENCE` → Playing: from the start of the clicked sentence.
- `user.SELECT_CALL` → Stopped
- `user.CLOSE_WINDOW` → Stopped
- `call.DELETED` → Stopped: only if the deleted call is the one paused.

## Events

### PLAYBACK_ENDED
Emitted when the audio reaches the end of the call.
