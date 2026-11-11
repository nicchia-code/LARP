---
name: weaver-req-tech-library
description: "Use when changing how the main window plays the audio of a call, works out waveforms or imports audio files."
---

# Technology and constraints

## playback

- Built on one audio engine per shown call, with one player per readable track connected, through one time-pitch unit shared by all tracks, to the main mixer; all tracks are scheduled from the same time and started together at one host time, 50 ms after the start.
- The speed is the rate of the time-pitch unit (`AVAudioUnitTimePitch`), which keeps the pitch of voices; the time reached is read in samples of the files, so it stays in the time of the audio at every speed.
- Skipping a silence is a seek done by the playback controller at the update tick that finds the time reached inside a silence to skip.
- The time reached is read from the first readable track.
- A change of the audio configuration of the engine is handled by reconnecting every track with the format of its file and starting again from the time reached.
- Playback runs on the main thread; the player is behind an interface so that it can be replaced in tests, and the update interval is a parameter.

## call/Ready

- The waveform of a call is worked out off the main actor by reading its tracks with `AVAudioFile` in blocks, never all at once, and saved with the call on the main actor; at launch, ready calls without waveform and with audio are worked out one at a time, the newest first, after every other work of the launch has started.

## call/Created

- An imported file is read with `AVAudioFile` (any format AVFoundation can read, for example m4a, mp3, wav, aiff, caf) and converted with the same converter and writer as the tracks of a recording, off the main actor; the call is created only once the conversion has succeeded, and a failure shows an alert "Impossibile importare il file" with the reason.
