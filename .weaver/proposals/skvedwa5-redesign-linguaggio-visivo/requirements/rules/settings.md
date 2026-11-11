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
- omp is looked for only while refinement, summaries or both are on.
- omp is found by asking the user's login shell (`$SHELL`, `/bin/zsh` when unset) `command -v omp` and taking the last line of its output; a shell that does not answer within 10 seconds counts as omp not found.
- omp is started as `omp acp --no-tools --no-session`; if it ends at once it is started again as `omp acp`.
- omp runs in a new empty temporary folder, deleted afterwards.
- omp has 10 seconds to answer the start of the conversation; an answer in time means reached, then omp is ended. Not found, an error or no answer in time means unreachable.
- Only the result of the latest check counts.

## launch-at-login
- The switch shows as on when the login item is on or awaiting the user's approval.
- When registering or removing fails, the error is shown as "Impossibile cambiare l'avvio all'accesso: <error>" (English: "Couldn't change opening at login: <error>") and the real state is read again.
