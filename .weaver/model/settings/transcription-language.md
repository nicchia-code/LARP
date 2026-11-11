# Transcription language

The single language, Italian or English, in which calls are transcribed, and whether its speech model is installed on the Mac. A new choice applies to recordings that start after it.

## States

### Checking (initial)
The app looks whether the speech model of the chosen language is installed. Before the app has launched nothing is looked at yet.
- `macos.APP_LAUNCHED` → Checking: starts the check and starts listening for the network coming back; happens once per launch.
- `macos.LANGUAGE_INSTALLED` → Ready: emits LANGUAGE_READY for the chosen language.
- `macos.LANGUAGE_NOT_INSTALLED` → Downloading
- `user.CHOOSE_LANGUAGE` → Checking: only if the language differs from the chosen one; the new language is saved and the check in progress is abandoned, its result ignored.

### Downloading
The speech model of the chosen language is being downloaded.
- `macos.LANGUAGE_INSTALLED` → Ready: emits LANGUAGE_READY for the chosen language.
- `macos.LANGUAGE_DOWNLOAD_FAILED` → Missing
- `user.CHOOSE_LANGUAGE` → Checking: only if the language differs from the chosen one; the new language is saved and the download in progress is abandoned, its result ignored.

### Missing
The speech model could not be downloaded; it is tried again as soon as the network comes back.
- `macos.NETWORK_AVAILABLE` → Checking: the check and the download are tried again.
- `user.CHOOSE_LANGUAGE` → Checking: only if the language differs from the chosen one; the new language is saved.

### Ready
The speech model of the chosen language is installed.
- `user.CHOOSE_LANGUAGE` → Checking: only if the language differs from the chosen one; the new language is saved.

## Events

### LANGUAGE_READY
Emitted, with the language, each time the speech model of the chosen language is found installed, at launch, after a choice or after a download; calls waiting for the speech model of that language can go on.
