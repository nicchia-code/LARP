# System audio

The capture of the system audio during a recording: everything the Mac plays except the app itself, that is the other participants ("Altri"), written to the system audio track and handed to the echo canceller of the microphone as its reference. It follows the default audio output of the Mac and its sample rate as they change, so that the track is always stored at the speed at which the sound was heard: the audio is always read at the rate at which it really arrives once the capture is running, also when headphones switch to their call mode, at a lower rate, because their microphone has been opened. Only the system audio is read, never the microphone of a headset used as the output. It needs only the system audio recording permission, not the screen recording one.

## States

### Not captured (initial)
No system audio is being captured: no recording is going on, or the recording goes on without it.
- `recorder.RECORDING_STARTED` → Captured: when the capture starts on the current default output; the files of both tracks of the recording are created first, and the audio is read at the rate at which it really arrives.
- `recorder.RECORDING_STARTED` → Not captured: when the capture cannot start and the recording is tied to a call app; nothing is left running and the recording cannot start.
- `recorder.RECORDING_STARTED` → Not captured: when the capture cannot start and the recording was started by hand; the recording goes on with the microphone alone, the system audio track stays empty and nothing is removed from the microphone. When the reason is that the system audio could not be tapped at all, it counts as the missing permission.

### Captured
The system audio is being recorded at the speed at which it is heard.
- `macos.AUDIO_DEVICES_CHANGED` → Captured: when something the capture depends on has really changed (the default output, its sample rate or whether it is still connected, the sample rate or the devices of the capture, the format of what the Mac plays, the rate at which the audio really arrives compared with the one it is read at) and the capture starts again from scratch on the current default output; a burst of changes starts it again once, and a gap longer than one second is filled with silence in the track.
- `macos.AUDIO_DEVICES_CHANGED` → Lost: when the capture cannot start again; nothing arrives from the system audio any more, the microphone is no longer cleaned of the sound of the others, a warning about the echo still shown disappears, and a lasting notice under the menu bar icon, below the one of the microphone when both are shown, tells that the system audio is not available and that the recording goes on without the other participants. From now on every change of the default output or of the connected audio devices is a chance to start again.
- `time.SYSTEM_AUDIO_STALLED` → Captured: when the capture starts again from scratch on the current default output; nothing is said to the user, and the gap is filled with silence in the track.
- `time.SYSTEM_AUDIO_STALLED` → Lost: when the capture cannot start again; the same as when it cannot start again after a change of audio devices: the microphone is no longer cleaned of the sound of the others, a warning about the echo still shown disappears, and the lasting notice tells that the system audio is not available. From now on every change of the default output or of the connected audio devices is a chance to start again.
- `microphone.START_FAILED` → Not captured: the capture stops and the tracks are closed.
- `recorder.RECORDING_STOPPED` → Not captured: the capture stops; the track is filled with silence up to the end of the recording, also when its audio had stopped arriving, then closed.

### Lost
The capture could not start again after a change of audio devices or after its audio stopped arriving; the recording goes on with the microphone only.
- `macos.AUDIO_DEVICES_CHANGED` → Captured: when the default output or the connected audio devices change and the capture starts again; the gap is filled with silence in the track and the notice that the system audio is not available disappears.
- `macos.AUDIO_DEVICES_CHANGED` → Lost: when the capture still cannot start; the recording goes on as before and nothing is said.
- `recorder.RECORDING_STOPPED` → Not captured: the track is filled with silence up to the end of the recording, then closed.

## Events

### STARTED
The capture of the system audio has started at the start of a recording.

### START_FAILED
The system audio could not start for a recording tied to a call app: the recording cannot start, and the reason is told to the user.

### UNAVAILABLE
The system audio could not start for a recording started by hand, which goes on with the microphone alone; it tells whether the reason is the missing permission.

### LOST
The capture of the system audio could not start again after a change of audio devices or after its audio stopped arriving.

### RESTORED
The system audio is being recorded again after it was lost.
