# Recording view

What shows a recording while it runs: the pill, a small dark bar that floats at the bottom of the screen above every window without taking the focus, and the live window, a dark window with the live transcript. Exactly one of the two is shown during a recording; neither is shown outside one.

## States

### Hidden (initial)
No recording is going on.
- `recorder.RECORDING_STARTED` → Shown

### Shown
A recording is going on. Both surfaces show the elapsed time with a red dot, which says "In pausa" while the recording is paused, and a waveform of what the microphone and the system audio are capturing, which stays flat while paused; both offer "Segnalibro", "Pausa" or "Riprendi" and "Ferma".
- `recorder.RECORDING_STOPPED` → Hidden: the pill or the live window disappears.

#### Pill (initial)
The pill sits at the bottom centre of the screen where the menu bar is, on every Space and beside full-screen apps.
- `user.OPEN_LIVE_WINDOW` → Live window: the pill disappears and the live window opens in front.

#### Live window
At the top the elapsed time, the title of the call, the call app (or "Manuale") and the transcription language of the call, or that there is no live transcription, and the levels of the call audio ("Call") and of the microphone ("Mic"). In the middle the live transcript: every final line with the dot of its speaker, "Io" or "Altri", its time and its text, a line at the time of a bookmark marked "Segnalibro", and at the bottom, in large type, the text being recognised at this moment with who is saying it ("sta parlando"); this text is never stored. On the right "Nella call", with "Io" and "Altri" and a mark on whoever is speaking now, from the levels of their tracks; below it "Le tue note", with the notes of this call in order of time and a field to write a new one, which takes the elapsed time.
- `user.CLOSE_LIVE_WINDOW` → Pill: the live window closes and the pill comes back.
