# Microphone

The capture of the microphone during a recording, written to the microphone track (the user, "Io"). The microphone used is the one chosen in the settings when it is connected, otherwise the default microphone of the Mac; with "Predefinito di sistema" it is always the default one. It starts after the system audio, so that the system audio can serve as the reference of the echo canceller from the first moment. While the system audio is captured, the sound of the other participants that the microphone picks up from the Mac's speakers is removed from it before it is written; macOS voice processing is never used. It follows the microphone to use and the audio output as they change: at every start a new capture reads the format the microphone delivers at that moment.

## States

### Off (initial)
No microphone is being captured: no recording is going on, or its capture ended or could not start.
- `system-audio.STARTED` → Removing echo: when the microphone to use starts and an echo canceller can be made; the echo canceller learns the echo path from scratch, and a warning about the echo still shown disappears.
- `system-audio.STARTED` → Not removing echo: when the microphone to use starts but no echo canceller can be made; the microphone is recorded as captured and a notice tells the user, for 10 seconds, that echo cancellation is not available and to use headphones so as not to hear the others twice.
- `system-audio.STARTED` → Off: when no microphone can start, because there is no input device or it does not start; the capture of the recording stops and nothing is left running.
- `system-audio.UNAVAILABLE` → Not removing echo: when the microphone to use starts; only the microphone is recorded, as captured, with nothing removed from it, and a notice tells the user, for 10 seconds, that the system audio is not available and only the microphone is recorded; the notice offers to open the system audio pane of System Settings only when the reason is the missing permission.
- `system-audio.UNAVAILABLE` → Off: when no microphone can start; the capture of the recording stops and nothing is left running.

### On
The microphone is being captured and written to its track.
- `macos.AUDIO_DEVICES_CHANGED` → Removing echo: when the microphone to use, the audio output or their formats change under the running capture and the capture starts again on the microphone to use, while the system audio is captured and a new echo canceller can be made; the echo path is learned again from scratch, and a warning about the echo still shown disappears.
- `macos.AUDIO_DEVICES_CHANGED` → Not removing echo: when the capture starts again while the system audio is captured but no new echo canceller can be made; the microphone is recorded as captured and the user is told, for 10 seconds, to use headphones.
- `macos.AUDIO_DEVICES_CHANGED` → Not removing echo: when the capture starts again while the system audio is not recorded or is lost; nothing is said to the user.
- `macos.AUDIO_DEVICES_CHANGED` → Lost: when the capture cannot start again; nothing arrives from the microphone any more, and a lasting notice under the menu bar icon tells that the microphone is not available and that the recording goes on without the user's voice. From now on every change of the connected audio devices or of the microphone to use is a chance to start again.
- `user.CHOOSE_MICROPHONE` → Removing echo: only if the microphone to use changes; the capture starts again on it, the gap is filled with silence in the track, and while the system audio is captured a new echo canceller learns the echo path from scratch.
- `user.CHOOSE_MICROPHONE` → Not removing echo: only if the microphone to use changes and the capture starts again on it while the system audio is not recorded or is lost, or no echo canceller can be made; in the last case the user is told, for 10 seconds, to use headphones.
- `user.CHOOSE_MICROPHONE` → Lost: only if the microphone to use changes and the capture cannot start on it; the lasting notice that the microphone is not available is shown.
- `system-audio.LOST` → Not removing echo: the echo canceller goes away and the microphone goes on to its track as captured.
- `recorder.RECORDING_STOPPED` → Off: what has been captured goes through the echo canceller and to the track first, then the track is closed.

#### Not removing echo (initial)
The microphone goes to its track as captured, with nothing removed from it.
- `system-audio.RESTORED` → Removing echo: when a new echo canceller can be made; echo removal resumes as at the start of a recording, and a warning about the echo still shown disappears.
- `system-audio.RESTORED` → Not removing echo: when no echo canceller can be made; the user is told, for 10 seconds, to use headphones.

#### Removing echo
The sound that the system audio leaves in the microphone is removed from it before it is written.

### Lost
The microphone could not start again after a change of audio devices or of the chosen microphone; the recording goes on without the user's voice.
- `macos.AUDIO_DEVICES_CHANGED` → Removing echo: when the connected audio devices or the microphone to use change and the capture starts again, while the system audio is captured and a new echo canceller can be made; the gap is filled with silence in the track and the notice that the microphone is not available disappears.
- `macos.AUDIO_DEVICES_CHANGED` → Not removing echo: when the capture starts again while the system audio is not recorded or is lost, or no echo canceller can be made; the notice that the microphone is not available disappears, and in the last case the user is told, for 10 seconds, to use headphones.
- `macos.AUDIO_DEVICES_CHANGED` → Lost: when the capture still cannot start; the recording goes on as before and nothing is said.
- `user.CHOOSE_MICROPHONE` → Removing echo: when the capture starts on the newly chosen microphone while the system audio is captured and a new echo canceller can be made; the gap is filled with silence and the notice disappears.
- `user.CHOOSE_MICROPHONE` → Not removing echo: when the capture starts on the newly chosen microphone while the system audio is not recorded or is lost, or no echo canceller can be made; the gap is filled with silence and the notice disappears.
- `user.CHOOSE_MICROPHONE` → Lost: when the capture still cannot start.
- `system-audio.RESTORED` → Lost: a new echo canceller is already made for when the microphone comes back; when it cannot be made, the user is told, for 10 seconds, to use headphones, even though the microphone is lost.
- `recorder.RECORDING_STOPPED` → Off: the track is filled with silence up to the end of the recording, then closed; the notice that the microphone is not available disappears.

## Events

### START_FAILED
No microphone could start at the start of a recording: the recording cannot start, and the reason is told to the user.

### LOST
The microphone could not start again after a change of audio devices or of the chosen microphone.

### RESTORED
The microphone is being recorded again after it was lost.
