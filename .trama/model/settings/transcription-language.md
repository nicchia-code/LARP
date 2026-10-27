# Transcription language

The single language, Italian or English, in which every call is transcribed, and whether its speech model is installed on the Mac. A new choice applies to the recordings that start after it.

## States

### Checking (initial)
The app has not yet checked whether the speech model of the chosen language is installed.
- `macos.APP_LAUNCHED` → Ready: if the speech model of the chosen language is installed.
- `macos.APP_LAUNCHED` → Downloading: if the speech model of the chosen language is not installed; macOS starts downloading it.

### Downloading
macOS is downloading the speech model of the chosen language.
- `macos.LANGUAGE_INSTALLED` → Ready
- `macos.LANGUAGE_DOWNLOAD_FAILED` → Missing: the settings say that the language is not available yet and that the download will be retried.
- `user.CHOOSE_LANGUAGE` → Ready: if the speech model of the newly chosen language is installed.
- `user.CHOOSE_LANGUAGE` → Downloading: if the speech model of the newly chosen language is not installed; macOS starts downloading it.

### Missing
The speech model of the chosen language is not installed and its download failed.
- `macos.NETWORK_AVAILABLE` → Downloading: the download is tried again.
- `macos.APP_LAUNCHED` → Downloading: the download is tried again.
- `user.CHOOSE_LANGUAGE` → Ready: if the speech model of the newly chosen language is installed.
- `user.CHOOSE_LANGUAGE` → Downloading: if the speech model of the newly chosen language is not installed; macOS starts downloading it.

### Ready
The speech model of the chosen language is installed; recordings can be transcribed live.
- `user.CHOOSE_LANGUAGE` → Ready: if the speech model of the newly chosen language is installed.
- `user.CHOOSE_LANGUAGE` → Downloading: if the speech model of the newly chosen language is not installed; macOS starts downloading it.

## Events

### LANGUAGE_READY
Emitted when the speech model of the chosen language becomes installed.
