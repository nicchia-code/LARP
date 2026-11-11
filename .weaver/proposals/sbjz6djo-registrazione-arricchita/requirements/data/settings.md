---
description: "Use when reading or changing the stored settings: call detection and watched apps, automatic recording, microphone, language, refinement and summary switches, shortcuts, welcome window, launch at login."
---
# Settings data

## settings
- The settings are kept in the user defaults of the app, one value per key, across launches.
- `settings.transcriptionLanguage`: text, the locale identifier of the chosen language, `it-IT` (shown "Italiano") or `en-US` (shown "English"). Default `it-IT`; an unknown value also reads as `it-IT`.
- `settings.transcriptRefinement`: yes/no, transcript refinement switch. Default off.
- `settings.callSummaries`: yes/no, call summaries switch. Default off.
- `settings.launchAtLogin`: yes/no, a copy of the login item being on or awaiting approval, written each time its state is read. The real state is the login item kept by macOS.
- `settings.callDetection`: yes/no, the "Rileva le call" switch. Default on.
- `settings.unwatchedCallApps`: list of the names of the known call apps the user turned off, as in the table of known call apps; every other known app is watched. Default empty; a name no longer known is ignored.
- `settings.autoRecording`: yes/no, automatic recording of detected calls. Default off.
- `settings.microphone`: text, the unique identifier of the chosen input device as Core Audio reports it, with its name next to it in `settings.microphoneName` for when it is not connected; absent means "Predefinito di sistema".
- `settings.shortcutRecord` and `settings.shortcutBookmark`: the key code and modifiers of each shortcut, or "none" when removed; absent means the default, ⌥⌘R and ⌥⌘B.
- `settings.onboardingDone`: yes/no, whether the welcome window was ended. Default no.
- The state of the language check, of the omp check and of the login item's approval or error are kept only in memory.
