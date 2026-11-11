---
description: Use when changing how the archive window plays the audio of a call.
---
# Library structure

## playback
- Built on one audio engine per shown call, with one player per readable track connected to the main mixer; all tracks are scheduled from the same time and started together at one host time, 50 ms after the start.
- The time reached is read from the first readable track.
- A change of the audio configuration of the engine is handled by reconnecting every track with the format of its file and starting again from the time reached.
- Playback runs on the main thread; the player is behind an interface so that it can be replaced in tests, and the update interval is a parameter.
