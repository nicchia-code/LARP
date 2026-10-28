# Recorder

The recording control in the menu bar: it notices calls, offers to record them and starts and stops recordings. Only one recording exists at a time.

## States

### Idle (initial)
Nothing is being recorded and no proposal is shown.
- `macos.CALL_APP_MIC_STARTED` → Proposing: shows the proposal to record, naming the call app.
- `user.START_RECORDING` → Recording: only if the microphone and system audio permissions are both granted; the recording is not tied to any call app and stops only by hand. When the sound of the other participants cannot be removed from the microphone, the recording starts anyway without removing it and the user is told to use headphones.
- `user.START_RECORDING` → Idle: if the microphone or the system audio permission is missing; nothing is recorded and the user is told which permission is missing and how to grant it in System Settings.

### Proposing
The proposal to record the call is shown and waits for the user.
- `user.ACCEPT_PROPOSAL` → Recording: only if the microphone and system audio permissions are both granted; the proposal disappears and the recording is tied to the call app that triggered it. When the sound of the other participants cannot be removed from the microphone, the recording starts anyway without removing it and the user is told to use headphones.
- `user.ACCEPT_PROPOSAL` → Idle: if the microphone or the system audio permission is missing; the proposal disappears, nothing is recorded and the user is told which permission is missing and how to grant it in System Settings.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only for the call app that triggered the proposal; the proposal disappears and nothing has been recorded.

### Recording
The microphone and the system audio are being recorded. The sound of the other participants that the microphone picks up from the Mac's speakers is removed from the microphone, with headphones or without, so that the microphone keeps only the user's voice and the other participants are heard and transcribed once, from the system audio.
- `user.STOP_RECORDING` → Idle: the recording ends.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only if the recording is tied to that call app; the recording ends on its own.
- `macos.AUDIO_DEVICES_CHANGED` → Recording: the recording goes on with the new microphone or audio output, and the sound of the other participants is removed from the microphone again. When that is no longer possible, the recording goes on without removing it and the user is told to use headphones.

## Events

### RECORDING_STARTED
Emitted when a recording starts; a new call is created.

### RECORDING_STOPPED
Emitted when the recording in progress ends.
