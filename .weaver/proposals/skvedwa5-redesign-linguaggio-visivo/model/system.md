# LARP

A macOS menu bar app for Apple silicon Macs that records the user's calls and transcribes them on the Mac. It notices when a known call app starts using the microphone and offers to record; the user can also record by hand. It records the microphone (the user's voice, with the sound of the others removed) and the system audio (the other participants) as two tracks, transcribes them in Italian or English with the user's voice as "Io" and everybody else as "Altri", then tells the other participants apart by their voices.

When the user turns them on, two optional features send the text of the transcript, never the audio, to omp, an assistant program the user installs and configures on the Mac: the refinement of the transcript, and a summary of each call with its key concepts, decisions and next steps. Both are off by default and independent of each other.

A click on the menu bar icon opens a small dark popover with the state of the recorder and the way to record, to open the archive and the settings. The main window has a dark sidebar and shows one page at a time: the library of the recorded calls as a grid of cards, which the user searches; the page of one call, with its summary beside its transcript and the audio that plays following the transcript, where the user renames the call and its participants, exports the call as Markdown and deletes it; and the settings, with the transcription language, the two omp switches with whether omp can be reached, and starting at login.

Audio always stays on the Mac; the app has no cloud service, account or telemetry of its own. The interface follows one visual language throughout, and is in Italian when the Mac is in Italian, in English otherwise.
