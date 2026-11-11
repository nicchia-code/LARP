# Transcript translation

The translation of the transcript of the call shown, asked with "Traduci" under the transcript and made by omp into the other language of the two, Italian or English, from the language of the call. The lines are sent in a process of their own as they are shown (refined or corrected text included), each with "Io" or "Partecipante" and its number, never the audio, the title, the names given by the user, the notes, the dates or the call app. The translation is shown in place of the text of the lines and never stored; times, speakers, bookmarks and the line being heard stay as they are. "Traduci" is available only while questions and translations with omp are on and the call is ready.

## States

### Original (initial)
The lines show their own text.
- `user.TRANSLATE_TRANSCRIPT` → Translating: the link says that the translation is being made.

### Translating
omp is translating the lines.
- `TRANSCRIPT_TRANSLATED` → Translated: every line shows its translation, and the link reads "Mostra originale".
- `TRANSLATION_FAILED` → Original: the panel says that the translation could not be made.
- `user.DESELECT_CALL` → Original: the omp process is ended at once.
- `user.OPEN_SETTINGS` → Original: the omp process is ended at once.
- `user.CLOSE_WINDOW` → Original: the omp process is ended at once.
- `user.TURN_OFF_QUESTIONS` → Original: the omp process is ended at once.
- `user.EDIT_LINE` → Original: the omp process is ended at once.
- `call.DELETED` → Original: only for the call shown; the omp process is ended.

### Translated
The lines show their translation.
- `user.SHOW_ORIGINAL` → Original: the translation is dropped.
- `user.EDIT_LINE` → Original: the translation is dropped and the line takes the text typed over its original text.
- `user.DESELECT_CALL` → Original: the translation is dropped.
- `user.OPEN_SETTINGS` → Original: the translation is dropped.
- `user.CLOSE_WINDOW` → Original: the translation is dropped.
- `call.TRANSCRIPT_REFINED` → Original: only for the call shown; the translation is dropped.
- `call.DELETED` → Original: only for the call shown.

## Events

### TRANSCRIPT_TRANSLATED
Emitted when omp has answered with a valid translation for every line sent.

### TRANSLATION_FAILED
Emitted when omp is not found, ends, answers with an error or does not answer completely within its time limit, or its answer does not match the lines sent; never when the translation was stopped.
