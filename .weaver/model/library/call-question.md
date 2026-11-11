# Call question

The questions the user asks omp about the call shown, with "Chiedi qualcosa a questa call" under its summary, and their answers. Each question is sent to omp, in a process of its own, with the lines of the call as they are shown (refined or corrected text included), each with "Io" or "Partecipante" and its number and its time, never the audio, the title, the names given by the user, the notes, the dates or the call app. Questions and answers are listed in order under the field while the page of the call stays open and are never stored. The field is available only while questions and translations with omp are on and the call has transcript lines.

## States

### Ready to ask (initial)
The field takes a question.
- `user.ASK_CALL` → Answering: only for a question that is not empty once trimmed; the question is added to the list with a line saying that omp is answering, and the field waits.
- `user.DESELECT_CALL` → Ready to ask: the list is emptied.
- `user.OPEN_SETTINGS` → Ready to ask: the list is emptied.
- `user.CLOSE_WINDOW` → Ready to ask: the list is emptied.
- `call.DELETED` → Ready to ask: only for the call shown; the list is emptied.

### Answering
omp is working on the last question; the field cannot take another one.
- `QUESTION_ANSWERED` → Ready to ask: the answer appears under its question, with the participants' current names in place of "Partecipante" and their number.
- `QUESTION_FAILED` → Ready to ask: the question shows that omp could not answer, with "Riprova", which asks it again.
- `user.DESELECT_CALL` → Ready to ask: the omp process is ended at once and the list is emptied.
- `user.OPEN_SETTINGS` → Ready to ask: the omp process is ended at once and the list is emptied.
- `user.CLOSE_WINDOW` → Ready to ask: the omp process is ended at once and the list is emptied.
- `user.TURN_OFF_QUESTIONS` → Ready to ask: the omp process is ended at once; the question shows that it was stopped.
- `call.DELETED` → Ready to ask: only for the call shown; the omp process is ended and the list is emptied.

## Events

### QUESTION_ANSWERED
Emitted when omp has answered the question with a text that is not empty.

### QUESTION_FAILED
Emitted when omp is not found, ends, answers with an error or with nothing, or does not answer completely within its time limit; never when the question was stopped.
