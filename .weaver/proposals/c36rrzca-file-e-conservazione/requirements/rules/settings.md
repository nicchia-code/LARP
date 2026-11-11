---
description: Use when changing the omp check, the language choice or the launch-at-login switch.
---
# Settings rules

## transcription-language
- Only two languages: Italian (`it-IT`) and English (`en-US`).
- A speech model counts as installed when its language matches, by BCP-47 identifier, one of the installed languages of the speech recogniser; a download that ends with the model still missing counts as failed.
- The chosen language applies to recordings that start after the choice; a call keeps the language it started with.
- Only the latest check or download counts; results of earlier ones are ignored.

## assistant-status
- omp is looked for only while refinement, summaries, questions and translations, or more of them are on.
- omp is found by asking the user's login shell (`$SHELL`, `/bin/zsh` when unset) `command -v omp` and taking the last line of its output; a shell that does not answer within 10 seconds counts as omp not found.
- omp is started as `omp acp --no-tools --no-session`; if it ends at once it is started again as `omp acp`.
- omp runs in a new empty temporary folder, deleted afterwards.
- omp has 10 seconds to answer the start of the conversation; an answer in time means reached, then omp is ended. Not found, an error or no answer in time means unreachable.
- Only the result of the latest check counts.

## launch-at-login
- The switch shows as on when the login item is on or awaiting the user's approval.
- When registering or removing fails, the error is shown as "Impossibile cambiare l'avvio all'accesso: <error>" (English: "Couldn't change opening at login: <error>") and the real state is read again.

## markdown-folder
- The file of a call is named like the default export file name with `.md` added; when another call of the folder already uses that name, ` (2)`, ` (3)` and so on is added before `.md`. The name each call used is kept so that it can be renamed or removed; a file is never removed or renamed unless it was written by LARP for that call.
- Its content is the Markdown export of the call, in the interface language at the moment of writing.
- A call counts as ready for the folder only when it is in Ready; a call in any other state is written when it becomes ready.
- When a file cannot be written, it is tried again at the next change of that call; the settings show "Impossibile scrivere nella cartella" under the row until a write succeeds.

## audio-retention
- Choices: "Sempre", "Per 30 giorni", "Per 90 giorni". A day is 24 hours, counted from the start of the call.
- The check runs at launch, after every other launch work has started, then every hour while the app runs, and at once after a new choice; it removes only the two audio files of the call, never its folder's other content, and only for ready calls whose summary is not being written; a call skipped is checked again at the next run.
- A call whose audio was removed has no waveform change, cannot be played or bookmarked while listening, and is marked so that the playback bar says "Audio eliminato dopo <n> giorni" with the number of days of the retention in force when it was removed.
