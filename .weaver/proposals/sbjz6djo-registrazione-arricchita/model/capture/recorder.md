# Recorder

The recording control in the menu bar: it notices that a watched call app has started using the microphone, offers to record the call or records it on its own, and starts, pauses and stops recordings. At most one proposal or one recording exists at a time, and while the permissions of one start are being checked a second start is ignored. The menu bar icon is the LARP mark outside a recording, and a red dot with the time elapsed since the start, updated every second, during one. A click on the icon opens a dark popover: at the top the LARP mark with a line saying the state of the recorder, then a card that depends on the state, then the call app the recording is tied to, the choice of the microphone and the switch "Registra automaticamente le call rilevate", and at the bottom "Apri archivio", "Impostazioni" and "Esci", which quits the app. The shortcut to start or stop recording starts a recording by hand when idle, accepts the proposal when one is shown and stops the recording during one.

## States

### Idle (initial)
Nothing is being recorded and no proposal is shown. The card of the popover says that the app is ready and offers "Registra".
- `macos.CALL_APP_MIC_STARTED` → Proposing: only if call detection is on and the call app is watched, and automatic recording is off or a permission is not granted yet; shows the proposal, a dark card "In onda ora" with the name of the call app, a "Registra questa call" button and "Non questa", in a small panel under the menu bar icon that never takes the focus; the same card takes the place of the card of the popover and appears as a banner at the top of the library.
- `macos.CALL_APP_MIC_STARTED` → Recording: only if call detection is on, the call app is watched, automatic recording is on and the microphone and the system audio permissions are both already granted; no proposal is shown, no permission is asked, and the recording is tied to the call app.
- `user.START_RECORDING` → Recording: only if the microphone permission is granted, asked to the user when not decided yet; the system audio permission is not checked. The recording is tied to no call app: it stops only by hand, and call apps that start or stop using the microphone meanwhile are ignored. If a proposal appeared while the permission was being checked, nothing is recorded and the proposal stays.
- `user.START_RECORDING` → Idle: if the microphone permission is missing; nothing is recorded and an alert names the missing permission, tells how to grant it, and offers to open its pane of System Settings.

### Proposing
The proposal to record the call is shown in the panel, in the popover and in the library, and waits for the user. Another call app that starts using the microphone meanwhile is ignored: there is never a second proposal.
- `user.ACCEPT_PROPOSAL` → Recording: only if the microphone and the system audio permissions are both granted, each asked to the user when not decided yet; the proposal disappears everywhere and the recording is tied to the call app of the proposal. If that call app stopped using the microphone while the permissions were being checked, the recording starts anyway, tied to no call app.
- `user.ACCEPT_PROPOSAL` → Idle: if a permission is missing; the proposal disappears everywhere, nothing is recorded and an alert names the first missing permission, the microphone before the system audio, tells how to grant it, and offers to open its pane of System Settings.
- `user.DISMISS_PROPOSAL` → Proposal dismissed: the proposal disappears everywhere and nothing is recorded.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only for the call app of the proposal; the proposal disappears everywhere and nothing has been recorded.
- `user.TURN_OFF_CALL_DETECTION` → Idle: the proposal disappears everywhere and nothing is recorded.
- `user.UNWATCH_APP` → Idle: only for the call app of the proposal; the proposal disappears everywhere and nothing is recorded.

### Proposal dismissed
The user discarded the proposal while its call app still uses the microphone; nothing is shown and the popover looks as when idle. Another call app that starts using the microphone meanwhile is ignored.
- `user.START_RECORDING` → Recording: only if the microphone and the system audio permissions are both granted, each asked to the user when not decided yet; the recording is tied to the call app of the discarded proposal, as when the proposal is accepted.
- `user.START_RECORDING` → Idle: if a permission is missing; nothing is recorded and an alert names the first missing permission, as when the proposal is accepted.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only for the call app of the discarded proposal.
- `user.TURN_OFF_CALL_DETECTION` → Idle
- `user.UNWATCH_APP` → Idle: only for the call app of the discarded proposal.

### Recording
A recording is going on, tied to a call app or, when started by hand, to no call app. The card of the popover shows the title of the call, the time elapsed, "Pausa" or "Riprendi", "Ferma registrazione" and "Apri finestra dal vivo". The capture of the microphone and of the system audio is followed by the microphone and system audio Machines. Every notice of the capture that arrives outside a recording is ignored.
- `user.STOP_RECORDING` → Idle: the recording ends; every notice of the recording disappears and the elapsed time goes back to zero.
- `macos.CALL_APP_MIC_STOPPED` → Idle: only if the recording is tied to that call app, even when other call apps still use the microphone, and also while paused; the recording ends on its own, as when the user stops it.
- `microphone.START_FAILED` → Idle: the recording ends on its own, as when the user stops it.
- `system-audio.START_FAILED` → Idle: the recording ends on its own, as when the user stops it.

#### Going on (initial)
The microphone and the system audio are written to their tracks as they are captured.
- `user.PAUSE_RECORDING` → Paused: from now on both tracks are written with silence in place of what is captured, and the live transcription receives the same silence; the elapsed time keeps counting, and the pill, the live window and the popover say that the recording is paused.

#### Paused
The recording goes on in silence: the times of the call stay those of the clock.
- `user.RESUME_RECORDING` → Going on: the tracks take again what is captured.

## Events

### RECORDING_STARTED
Emitted when a recording starts, with the name of the call app it is tied to, or none for a recording started by hand.

### RECORDING_STOPPED
Emitted when the recording in progress ends, by hand, because its call app stopped using the microphone, or because its capture could not start.
