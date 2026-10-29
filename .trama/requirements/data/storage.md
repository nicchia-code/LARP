---
description: Use when defining or changing what is stored for a call, its audio files or the settings.
---
# Storage

## General
- Everything is stored on the Mac in `~/Library/Application Support/LARP/`: a SwiftData store and a `Recordings/<call id>/` folder per call.
- Settings (transcription language, transcript refinement, call summaries, launch at login) are stored in `UserDefaults`.

## call
- A call holds: identifier, title (optional, set by the user), start date and time, end date and time, duration, call app name (absent for manual recordings), transcription language, current state, the two audio files, the participants and the transcript lines.
- Audio is saved as two files per call, `mic.caf` and `system.caf`, AAC mono at about 32 kbps each, written in chunks as it is recorded so that a file cut by a crash is still readable up to the last chunk written.
- When a recording started by hand does not record the system audio, `system.caf` is still created and stays empty.
- While the microphone is lost during a recording, `mic.caf` is filled with silence for that time, also when the recording ends before the microphone comes back, so that it is as long as the recording and the times of its lines stay aligned with `system.caf`.
- A transcript line holds: speaker (Me, Others, or a participant), start time and end time relative to the start of the call, and text.
- Once its call has been refined, a transcript line also holds its original text and original speaker, as transcription and separation left them; restoring the transcript puts them back as text and speaker and clears them. A call is refined when its lines hold an original.
- A participant holds: number (1, 2, …) and an optional name set by the user; it belongs to one call only.
- A call holds at most one summary: its key concepts, decisions and next steps as ordered lists of texts, each next step with an optional owner ("Io" or "Partecipante <number>"), its free text, the language it is written in and when it was written. It also holds the state of its summary (none, being written, waiting to be tried again, written). Calls stored before summaries existed have no summary.
- Deleting a call deletes its record, its lines, its participants, its summary and its `Recordings/<call id>/` folder.
