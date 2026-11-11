---
description: Use when implementing call titles and speaker names, the transcription queue, speaker assignment, or what is sent to omp and how its refinement and summary answers are checked.
---
# Transcription rules

## transcription
- **What omp receives**, for both the refinement and the summary: only the original lines of the call (text and speaker as transcription and separation left them, also after a refinement), sorted by start and then by end, numbered from 1, as a JSON array of objects with `number`, `speaker`, `start`, `end` and `text`. Nothing else of the call is sent: never the audio, the title, the names given by the user, the dates or the call app.
- `speaker` is "Io" or "Partecipante <number>", never "Altri" and never a name given by the user. A line of the others with no participant means no request is sent and the work fails.
- `start` and `end` are seconds from the start of the call, rounded to two decimals and written without decimals when whole.
- The prompt is a fixed Italian instruction text, a blank line, then the JSON of the lines.
- **omp lookup**: the login shell of the user (`$SHELL`, `/bin/zsh` when unset) is asked `command -v omp`; the last line of its output must be an absolute path to an executable file. A shell that does not answer within 10 s, or ends with an error, means omp is not found. The lookup runs again at every request.
- **omp start**: every request starts its own process, `omp acp --no-tools --no-session`; when that process ends at once, it is started again as `omp acp`. It works in a new empty temporary folder, deleted afterwards.
- **Time limit**: 600 s for each request, counted from the start of the process and covering its whole answer, the first handshake included. At the limit the process is ended and the request fails.
- Ending an omp process asks it to stop and kills it 2 s later if it is still running.
- The answer is the text of all the agent's message chunks of the prompt, joined. Every permission omp asks for is refused (its "reject once" option, else its "reject always" option, else cancelled); every other request of omp is answered "method not found".

## call
- **Default title**, built when shown, in the interface language: Italian "Call del <day> <month> <year>, <hh>:<mm>" for a call tied to a call app, "Registrazione del <day> <month> <year>, <hh>:<mm>" for a recording started by hand, the month being its Italian name in lower case (gennaio … dicembre); English "Call on <day> <month> <year>, <hh>:<mm>" and "Recording on <day> <month> <year>, <hh>:<mm>", the month being its English name (January … December). The day is not padded, hours (24-hour) and minutes are two digits, in the Mac's calendar.
- A title or participant name typed by the user is stored without surrounding whitespace; an empty one restores the default title or "Partecipante <number>".
- **Speaker names**, shown in the interface language: "Io" / "Me" for the microphone, "Altri" / "Others" for the others as a whole, the participant's name or "Partecipante <number>" / "Participant <number>" for a participant; a participant line without participant shows "Altri" / "Others". What omp receives and answers keeps the Italian names "Io" and "Partecipante <number>", whatever the interface language.
- **Transcription order**: one call at a time, the oldest start first; a call waiting for its retry is skipped.
- **Retry**: a failed transcription is tried again 60 s after it failed, with no limit on the number of attempts.
- Lines come only from final recognition results whose text, trimmed, is not empty. Start and end are never below zero and the end never before the start; a time that is not a number becomes 0, or the start for the end.
- The duration of a call ended by its stop is the time from its start to its stop, never negative; for a call recovered at launch it is the length of its longer readable track, or 0.

## call/Separating participants
- Only the lines that are not "Io" are separated; with none, the voices are not analysed.
- A line goes to the voice whose segments overlap it most in total time. Ties go to the voice whose first segment starts earlier, then to the voice whose identifier sorts first.
- A line no voice overlaps goes to the voice of the nearest recognised line, the distance being the gap between the two time spans (0 when they overlap); between equally near lines the first in order of start wins.
- When no line is recognised, every line goes to Partecipante 1.
- Participants are numbered from 1 in the order in which they first speak, by the start of their lines; a voice with no line gets no number.

## call/Refining transcript
- **Instructions** (Italian): correct every word recognised wrongly, in any language; do not rephrase, summarise, translate or change the style; do not merge, split, add or remove lines. A line may move to another "Partecipante <number>" already present in the lines; a "Io" line stays "Io" and no other line becomes "Io". Answer only with a JSON array, one object per line received, with `number` (the same), `text` (corrected, never empty) and `speaker`.
- **Checking the answer**: the text from the first `[` to the last `]` must decode as that array, with exactly as many items as lines sent and no number twice, every line number present.
- Each `speaker` must be "Io" or "Partecipante <n>" with n above 0, written exactly so. A "Io" line may only stay "Io"; any other line may keep its participant or take any participant appearing in the lines sent.
- Each text is trimmed and must not be empty.
- When applying, every participant named must exist in the call; otherwise nothing is changed and the refinement fails.

## call-summary
- **Language**: the summary is asked in English when the call's language is English, otherwise in Italian.
- **Instructions** (Italian): the lines come from automatic recognition and voice separation, may hold wrong words and wrong participants, to be made sense of without pointing them out; name people only "Io" and "Partecipante <number>", never guessing names; give key concepts, decisions, next steps and, as free text, what is important and fits none of them; any list and the text may be empty; give a next step's owner only when the conversation makes it clear. Answer only with a JSON object with `keyConcepts` (texts), `decisions` (texts), `nextSteps` (objects with `text` and optional `owner`) and `other` (text, may be empty).
- **Checking the answer**: the text from the first `{` to the last `}` must decode with all four fields.
- An owner must be "Io" or "Partecipante <n>" with n one of the call's participants, written exactly so; any other owner makes the whole answer invalid.
- Every item, step text and the free text are trimmed; empty items and steps with empty text are dropped.
