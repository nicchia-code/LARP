# System audio

The capture of the system audio, the sound of the other participants played by the Mac, during a recording. It follows the audio output of the Mac and its sample rate as they change, so that the system audio track is always stored at the speed at which it was heard.

## States

### Not captured (initial)
No system audio is being captured: no recording is going on, or the recording was started by hand without the system audio.
- `recorder.RECORDING_STARTED` → Captured: only if the recording captures the system audio.

### Captured
The system audio is being recorded at the speed at which it is heard, and it is used to remove the sound of the other participants from the microphone.
- `macos.AUDIO_DEVICES_CHANGED` → Captured: when the capture of the system audio starts again on the current audio output; the recording goes on with the system audio at the speed at which it is heard, with no gap longer than the time needed to start again.
- `macos.AUDIO_DEVICES_CHANGED` → Lost: when the capture of the system audio cannot be started again; the recording goes on with the microphone only, the system audio track holds silence from then on, the sound of the other participants is no longer removed from the microphone, which keeps everything it picks up, and the user is told that the system audio is not available.
- `recorder.RECORDING_STOPPED` → Not captured

### Lost
The capture of the system audio could not be started again after a change of audio devices; the recording goes on with the microphone only and the user sees that the system audio is not available until it comes back or the recording ends.
- `macos.AUDIO_DEVICES_CHANGED` → Captured: when the capture of the system audio starts again; the other participants are recorded again, the notice that the system audio is not available disappears, and the sound of the other participants is removed from the microphone as at the start of a recording.
- `macos.AUDIO_DEVICES_CHANGED` → Lost: when the capture of the system audio still cannot be started; the recording goes on as before.
- `recorder.RECORDING_STOPPED` → Not captured: the notice that the system audio is not available disappears.
