# Call summary

The summary of one recorded call, written by the assistant from the original text of its transcript: the key concepts, the decisions taken, the next steps and, in free text, what fits none of them. It is written in the transcription language of the call and runs alongside the refinement of the same call, never waiting for it.

## States

### Kept (initial)
The call exists.
- `call.DELETED` → Deleted: any summary being written stops and the summary is deleted with the call.

#### No summary (initial)
The call has no summary.
- `call.PARTICIPANTS_SEPARATED` → Summarising: only if call summaries are on and the transcript has at least one line.
- `user.SUMMARIZE_CALL` → Summarising: only if call summaries are on, the transcript has at least one line and the participants have been told apart.

#### Summarising
The original text of the call's lines, with who spoke each line and when, is sent to the assistant, never the audio, saying that it comes from an automatic transcription and may hold words recognised wrongly and lines given to the wrong participant. The transcript can be read meanwhile, and a summary written before stays until the new one replaces it.
- `SUMMARY_WRITTEN` → Summarised: the new summary replaces any earlier one.
- `SUMMARY_FAILED` → Awaiting summary retry: any earlier summary stays.
- `user.TURN_OFF_SUMMARY` → No summary: the summary stops; only if the call had no summary before.
- `user.TURN_OFF_SUMMARY` → Summarised: the summary stops and the earlier summary stays; only if the call had one.
- `macos.APP_LAUNCHED` → Summarising: the app was closed while the summary was being written, which starts again.

#### Awaiting summary retry
Writing the summary failed and will be tried again on its own; any earlier summary stays.
- `macos.NETWORK_AVAILABLE` → Summarising: tries again.
- `macos.APP_LAUNCHED` → Summarising: tries again.
- `user.SUMMARIZE_CALL` → Summarising: tries again at once.
- `user.TURN_OFF_SUMMARY` → No summary: no further attempt; only if the call had no summary before.
- `user.TURN_OFF_SUMMARY` → Summarised: no further attempt and the earlier summary stays; only if the call had one.

#### Summarised
The call has a summary, which can be read, searched and exported also when call summaries are off. It names the participants as the call shows them now: a participant renamed later appears with the new name.
- `user.SUMMARIZE_CALL` → Summarising: only if call summaries are on; the summary is written again from the original lines.

### Deleted (final)
The call and its summary no longer exist.

## Events

### SUMMARY_WRITTEN
Emitted when the assistant has answered with a valid summary and it has been saved.

### SUMMARY_FAILED
Emitted when the summary could not be written: the assistant cannot be reached, does not answer in time, or its answer is not a valid summary.
