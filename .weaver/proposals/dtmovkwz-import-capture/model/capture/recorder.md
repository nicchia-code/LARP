# Recorder

The recording control in the menu bar: it notices that a known call app has started using the microphone, offers to record the call, and starts and stops recordings. At most one proposal or one recording exists at a time, and while the permissions of one start are being checked a second start is ignored. The menu offers "Registra" outside a recording and "Ferma registrazione" during one; the menu bar icon is a microphone outline outside a recording, and a red dot with the time elapsed since the start, updated every second, during one.

## States

### Idle (initial)
Nothing is being recorded and no proposal is shown.
- `macos.CALL_APP_MIC_STARTED` → Proposing: shows the proposal "Call rilevata in" followed by the name of the call app, with a "Registra" button, in a small panel under the menu bar icon that never takes the focus. The proposal has no way to be dismissed: it stays until it is accepted or the call app stops using the microphone.
- `user.START_RECORDING` → Recording: only if the microphone permission is granted, asked to the user when not decided yet; the system audio permission is not checked. The recording is tied to no call app: it stops only by hand, and call apps that start or stop using the microphone meanwhile are ignored. If a proposal appeared while the permission was being checked, nothing is recorded and the proposal stays.
- `user.START_RECORDING` → Idle: if the microphone permission is missing; nothing is recorded and an alert names the missing permission, tells how to grant it, and offers to open its pane of System Settings.

### Proposing
The proposal to record the call is shown and waits for the user. Another call app that starts using the microphone meanwhile is ignored: there is never a second proposal.
- `user.ACCEPT_PROPOSAL` → Recording: only if the microphone and the system audio permissions are both granted, each asked to the user when not decided yet; the proposal disappears and the recording is tied to the call app of the proposal. If that call app stopped using the microphone while the permissions were being checked, the recording starts anyway, tied to no call app.
- `user.ACCEPT_PROPOSAL` → Idle: if a permission is missing; the proposal disappears, nothing is recorded and an alert names the first missing permission, the microphone before the system audio, tells how to grant it, and offers to open its pane of System Settings.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only for the call app of the proposal; the proposal disappears and nothing has been recorded.

### Recording
A recording is going on, tied to the call app whose proposal was accepted or, when started by hand, to no call app. The capture of the microphone and of the system audio is followed by the microphone and system audio Machines. Every notice of the capture that arrives outside a recording is ignored.
- `user.STOP_RECORDING` → Idle: the recording ends; every notice of the recording disappears and the elapsed time goes back to zero.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only if the recording is tied to that call app, even when other call apps still use the microphone; the recording ends on its own, as when the user stops it.
- `microphone.START_FAILED` → Idle: the recording ends on its own, as when the user stops it.
- `system-audio.START_FAILED` → Idle: the recording ends on its own, as when the user stops it.

#### Microphone on (initial)
The microphone is being recorded.
- `microphone.LOST` → Microphone lost: a lasting notice under the menu bar icon tells that the microphone is not available and that the recording goes on without the user's voice.

#### Microphone lost
The microphone could not start again after a change of audio devices; the recording goes on without the user's voice.
- `microphone.RESTORED` → Microphone on: the notice that the microphone is not available disappears.

## Events

### RECORDING_STARTED
Emitted when a recording starts, with the name of the call app it is tied to, or none for a recording started by hand.

### RECORDING_STOPPED
Emitted when the recording in progress ends, by hand, because its call app stopped using the microphone, or because its capture could not start.
