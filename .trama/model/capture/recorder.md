# Recorder

The recording control in the menu bar: it notices calls, offers to record them and starts and stops recordings. Only one recording exists at a time.

## States

### Idle (initial)
Nothing is being recorded and no proposal is shown.
- `macos.CALL_APP_MIC_STARTED` → Proposing: shows the proposal to record, naming the call app.
- `user.START_RECORDING` → Recording: only if the microphone permission is granted; the app turns the microphone on by itself, whether or not a call is going on and whether or not another app is using the microphone, and the recording is not tied to any call app and stops only by hand. The system audio is recorded too when its permission is granted and its capture starts; otherwise only the microphone is recorded and the user is told that the system audio is not available, with a way to grant its permission in System Settings when that permission is missing. When the system audio is recorded and the sound of the other participants cannot be removed from the microphone, the recording starts anyway without removing it and the user is told to use headphones.
- `user.START_RECORDING` → Idle: if the microphone permission is missing; nothing is recorded and the user is told that the microphone permission is missing and how to grant it in System Settings.

### Proposing
The proposal to record the call is shown and waits for the user.
- `user.ACCEPT_PROPOSAL` → Recording: only if the microphone and system audio permissions are both granted; the proposal disappears and the recording is tied to the call app that triggered it. When the sound of the other participants cannot be removed from the microphone, the recording starts anyway without removing it and the user is told to use headphones.
- `user.ACCEPT_PROPOSAL` → Idle: if the microphone or the system audio permission is missing; the proposal disappears, nothing is recorded and the user is told which permission is missing and how to grant it in System Settings.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only for the call app that triggered the proposal; the proposal disappears and nothing has been recorded.

### Recording
The microphone and, unless it was not available when a recording was started by hand, the system audio are being recorded. While the system audio is recorded, the sound of the other participants that the microphone picks up from the Mac's speakers is removed from the microphone as it is recorded, with headphones or without, so that the microphone keeps only the user's voice and the other participants are heard and transcribed once, from the system audio. In a recording without the system audio nothing is removed from the microphone, which then keeps everything it picks up. Recording changes nothing of what the user and the other participants hear: the volume of the call app and of every other app on the Mac, and the level of the microphone the call app sends to the other participants, stay as they are without the recording.
- `user.STOP_RECORDING` → Idle: the recording ends.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only if the recording is tied to that call app; the recording ends on its own.

#### Microphone on (initial)
The microphone is being recorded.
- `macos.AUDIO_DEVICES_CHANGED` → Microphone on: when the microphone starts again; the recording goes on with the new microphone or audio output, and the sound of the other participants is removed from the microphone again. When that is no longer possible and the system audio is recorded, the recording goes on without removing it and the user is told to use headphones.
- `macos.AUDIO_DEVICES_CHANGED` → Microphone lost: when the microphone cannot be started again; the recording goes on without the user's voice, with the system audio when it is recorded and even when nothing else is being recorded, the microphone track holds silence from then on, and the user is told that the microphone is not available.

#### Microphone lost
The microphone could not be started again after a change of audio devices; the recording goes on without the user's voice and the user sees that the microphone is not available until it comes back or the recording ends.
- `macos.AUDIO_DEVICES_CHANGED` → Microphone on: when the microphone starts again; the user's voice is recorded again, the notice that the microphone is not available disappears, and the sound of the other participants is removed from the microphone as at the start of a recording.
- `macos.AUDIO_DEVICES_CHANGED` → Microphone lost: when the microphone still cannot be started; the recording goes on as before.

## Events

### RECORDING_STARTED
Emitted when a recording starts; a new call is created.

### RECORDING_STOPPED
Emitted when the recording in progress ends.
