---
name: weaver-req-data-transcription
description: "Use when storing or reading calls, their transcript lines, participants or summaries, or the originals kept by refinement."
---

# Data

## call

- **Call**: unique identifier; title given by the user (absent means the default title); start time; end time (absent while recording); duration in seconds; name of the call app (absent for a recording started by hand); transcription language as a locale identifier (for example `it-IT`); state of the call; state of the summary; paths of the microphone and system audio files, relative to the app's folder; its transcript lines, its participants and at most one summary.
- The state of the call is stored as one of: recording, awaiting language, transcribing, separating participants, awaiting separation retry, refining transcript, awaiting refinement retry, ready. An unknown stored value reads as ready.
- Meeting information of a call, all optional so that a store saved before it existed opens with none: the **meeting title** (text, from Teams or the calendar); the **names for participants** (ordered list of texts without repeats, from Teams and the invited people of the calendar event); the **timeline of Teams speakers** (ordered list of spans, each with start and end in seconds from the start of the call and an optional name). They stay on the Mac and go with the call when it is deleted.
- Further fields of a call, optional so that a store saved before them opens with their default: whether it was **imported** (default no); its **folder** (absent means none; deleting the folder clears it); its **waveform**, an ordered list of 44 bars, each a level from 0 to 1 and a speaker (me, a participant number, others or silence), absent until worked out.
- Retention and Markdown fields of a call, optional: whether its **audio was removed** by the retention, with the number of days in force then (default no); the **name of its Markdown file** in the folder, absent until written.
- An imported call has no microphone file; its `Recordings/<call id>/system.caf` is the imported audio converted to the format of the tracks; the imported file itself is never kept or changed.
- The audio files of a call are `Recordings/<call id>/mic.caf` (the microphone, "Io") and `Recordings/<call id>/system.caf` (the system audio, "Altri").
- **Transcript line**: speaker kind (me, others or participant); the participant, set when the kind is participant; start and end in seconds from the start of the call; text; the call it belongs to. An unknown stored speaker kind reads as others.
- A line keeps its **originals** once the call has been refined: the text, the speaker kind and, when that speaker was a participant, the participant's number, as transcription and separation left them. They are set at the first refinement, never overwritten by later ones, and cleared by the restore. A call counts as refined when any of its lines holds an original text.
- **Participant**: number (1, 2, … within the call); name given by the user (absent means "Partecipante <number>"); the call it belongs to; its lines. Deleting a participant leaves its lines without participant. A separation that runs again deletes the participants of the call and creates them anew.
- Deleting a call deletes its lines, participants and summary with it.
- Not stored: whether a transcription failed and the pending retries of transcriptions; both are lost when the app is closed.

## call-summary

- **Call summary**: opening sentence (text, empty for a summary written before it existed); its highlighted part (text, may be empty); key concepts (ordered list of texts); decisions (ordered list, each with a text and an optional line start in seconds, taken from the line omp named when it was written); action items (ordered list, each with a text, an optional owner, an optional due as said and a done flag, not done by default); left open (ordered list of texts); free text; language as a locale identifier, the language asked; time it was written; the call it belongs to. A call holds at most one.
- A summary stored before this version opens with its next steps as action items without due and not done, its decisions without line, and no opening sentence and nothing left open.
- The owner of an action item is stored exactly as omp wrote it, "Io" or "Partecipante <number>"; names given by the user are never stored in it.
- The state of the summary is stored with the call as one of: none, writing, awaiting retry, written. A store saved before summaries existed reads every call as none, and so does an unknown value.

## bookmark

- **Bookmark**: unique identifier; time in seconds from the start of the call, never below zero; the call it belongs to. A call owns its bookmarks and deleting the call deletes them.
- A store saved before bookmarks existed opens with every call without bookmarks.

## note

- **Note**: unique identifier; text, trimmed and never empty; time in seconds from the start of the call, absent for a note written without listening; the time it was written, which orders the notes without time; the call it belongs to. A call owns its notes and deleting the call deletes them.
- A store saved before notes existed opens with every call without notes.

## folder

- **Folder**: unique identifier; name; the calls it holds. Deleting a folder leaves its calls without folder.
- A store saved before folders existed opens without folders.
