---
description: "Use when storing or reading anything the app keeps on disk: the archive, the audio files, the downloaded models or the settings."
---
# Storage

## General
- Everything lives on the Mac, in the folder `LARP` of the user's Application Support: the SwiftData store `LARP.store`, one folder `Recordings/<call id>/` per call holding its audio files, and the folder `Models/` with the speaker separation models, downloaded on first use and reused.
- The archive holds four kinds of records: calls, transcript lines, participants and call summaries. A call owns its lines, its participants and at most one summary, and deleting a call deletes them together with its folder of audio files.
- The paths of the audio files are stored relative to the app's folder in Application Support.
- A store saved before summaries existed opens with every call without a summary.
- The settings are kept in the user defaults of the app.
- omp works in a new empty temporary folder for every request, deleted afterwards.
