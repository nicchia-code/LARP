---
description: Use when writing, reading or measuring the audio tracks of a recording, or changing their format or files.
---
# Audio tracks

## capture
- Every recording writes two audio tracks in the folder of its call, `Recordings/<call id>/`, created if needed: `mic.caf`, the microphone, speaker "Io" (the user), and `system.caf`, the system audio, speaker "Altri" (the other participants).
- Both files are created at the start of the recording, replacing a file with the same name; `system.caf` stays empty when a recording started by hand goes on without the system audio.
- Format of both tracks: CAF file, AAC, mono, 16 kHz, about 32 kbps, 1024 frames per packet. The audio reaches the files, and the live transcription, as 32-bit float mono at 16 kHz.
- The tracks are written while the recording runs, and the packet table of each file is written out every 2 seconds of audio, so a file cut by a crash or a power loss can still be read up to the last 2 seconds. A file is finished when the recording stops.
- Gaps in a track (a microphone or an output that changed, a lost capture) are filled with silence, so that a time in either track is the time since that track started.
- The length of a track is read back as its number of frames divided by its sample rate; a missing, unreadable or empty file has no length.
- Nothing of the recorder is stored: the state of the recorder, the proposal and the elapsed time live only while the app runs.
