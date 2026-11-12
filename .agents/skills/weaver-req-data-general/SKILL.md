---
name: weaver-req-data-general
description: "Use when storing or reading anything the app keeps on disk: the archive, the audio files, the downloaded models or the settings."
---

# Data

## General

- Everything lives on the Mac, in the folder `LARP` of the user's Application Support: the SwiftData store `LARP.store`, one folder `Recordings/<call id>/` per call holding its audio files, and the folder `Models/` with the speaker separation models, downloaded on first use and reused.
- The archive holds seven kinds of records: calls, transcript lines, participants, call summaries, bookmarks, notes and folders. A call owns its lines, its participants, at most one summary, its bookmarks and its notes, and deleting a call deletes them together with its folder of audio files; a call may belong to one folder, which does not own it.
- The paths of the audio files are stored relative to the app's folder in Application Support.
- A store saved before summaries existed opens with every call without a summary.
- The settings are kept in the user defaults of the app.
- omp works in a new empty temporary folder for every request, deleted afterwards.
- The diagnostic log of LARP lives outside the folder of the app, in `~/Library/Logs/LARP/`, created when missing: one text file per day, `LARP-<yyyy-MM-dd>.log`, in UTF-8. It is always on, with no setting.
- Each line is one event: the local date and time in ISO 8601 with milliseconds, the area (`detection`, `teams`, `capture`) and the message, separated by spaces. Every line reaches the disk before the next one is written, so a crash or a frozen Mac loses none of the lines written before it. Lines are written from a private serial queue; a failure to write is ignored and never affects a recording.
- Files of the diagnostic log older than 30 days are deleted at launch and once a day while the app runs.
