# Call summary

The summary of one recorded call, written by omp from the original lines of its transcript: the key concepts, the decisions taken, the next steps with who has to do them when that is clear, and in free text what fits none of them. It is written in the transcription language of the call, by an omp process of its own that runs alongside the refinement of the same call and never waits for it. Its state is kept with the call, apart from the call's own state.

## States

### Kept (initial)
The call exists.
- `call.DELETED` → Deleted: a summary being written has already been stopped; the summary goes with the call.

#### No summary (initial)
The call has no summary. A call stored before summaries existed is here.
- `call.PARTICIPANTS_SEPARATED` → Summarising: only if call summaries are on and the transcript has at least one line.
- `user.SUMMARIZE_CALL` → Summarising: only if call summaries are on, the transcript has at least one line and the participants have been told apart, which means the call is Ready, Refining transcript or Awaiting refinement retry.

#### Summarising
The original lines of the call, with who spoke each line and when, are sent to omp, never the audio, the title, the names given by the user, the dates or the call app, saying that they come from an automatic recognition and separation and may hold words recognised wrongly and lines given to the wrong participant. When a line of the others has no participant, nothing is sent and the summary fails. A summary written before stays until the new one replaces it.
- `SUMMARY_WRITTEN` → Summarised: the new summary replaces the earlier one in the same save.
- `SUMMARY_FAILED` → Awaiting summary retry: the earlier summary, if any, stays.
- `user.TURN_OFF_SUMMARY` → No summary: the omp process is ended at once; only if the call had no summary before.
- `user.TURN_OFF_SUMMARY` → Summarised: the omp process is ended at once and the earlier summary stays; only if the call had one.
- `macos.APP_LAUNCHED` → Summarising: the app was closed while the summary was being written, which starts again, also when call summaries were turned off meanwhile.

#### Awaiting summary retry
Writing the summary failed and will be tried again on its own; the earlier summary, if any, stays.
- `macos.NETWORK_AVAILABLE` → Summarising: tries again.
- `macos.APP_LAUNCHED` → Summarising: tries again, also when call summaries are off.
- `user.SUMMARIZE_CALL` → Summarising: tries again at once; only if the transcript has at least one line, also when call summaries are off.
- `user.TURN_OFF_SUMMARY` → No summary: no further attempt; only if the call had no summary before.
- `user.TURN_OFF_SUMMARY` → Summarised: no further attempt and the earlier summary stays; only if the call had one.

#### Summarised
The call holds its summary, which stays also when call summaries are turned off.
- `user.SUMMARIZE_CALL` → Summarising: only if call summaries are on and the transcript has at least one line; the summary is written again from the original lines.

### Deleted (final)
The call and its summary no longer exist.

## Events

### SUMMARY_WRITTEN
Emitted when omp has answered with a valid summary and it has been saved with the call, with its language and the time it was written.

### SUMMARY_FAILED
Emitted when the summary could not be written: omp is not found, ends, answers with an error or does not answer completely within its time limit; its answer is not a valid summary; or a line of the others has no participant, so nothing was sent. Never when the summary was stopped because it was turned off, replaced or the call was deleted.
