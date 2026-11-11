---
name: weaver-req-data-settings
description: "Use when reading or changing the stored settings: call detection and watched apps, automatic recording, microphone, language, refinement and summary switches, shortcuts, welcome window, launch at login."
---

# Data

## settings

- The settings are kept in the user defaults of the app, one value per key, across launches.
- `settings.transcriptionLanguage`: text, the locale identifier of the chosen language, `it-IT` (shown "Italiano") or `en-US` (shown "English"). Default `it-IT`; an unknown value also reads as `it-IT`.
- `settings.transcriptRefinement`: yes/no, transcript refinement switch. Default off.
- `settings.callSummaries`: yes/no, call summaries switch. Default off.
- `settings.summaryLanguage`: text, `call` ("Come la call"), `it-IT` or `en-US`. Default `call`; an unknown value reads as `call`.
- `settings.callQuestions`: yes/no, the "Domande e traduzioni con omp" switch. Default off.
- `settings.markdownFolder`: text, the path of the folder chosen for the Markdown files; absent means off.
- `settings.markdownWrittenFiles`: dictionary from the path of a Markdown folder to the list of the file names LARP wrote in it; only a file with one of these names is replaced or removed there, any other file of the folder is the user's. Absent means none.
- `settings.audioRetentionDays`: number, 30 or 90; absent means "Sempre"; any other value reads as "Sempre".
- `settings.launchAtLogin`: yes/no, a copy of the login item being on or awaiting approval, written each time its state is read. The real state is the login item kept by macOS.
- `settings.callDetection`: yes/no, the "Rileva le call" switch. Default on.
- `settings.unwatchedCallApps`: list of the names of the known call apps the user turned off, as in the table of known call apps; every other known app is watched. Default empty; a name no longer known is ignored.
- `settings.autoRecording`: yes/no, automatic recording of detected calls. Default off.
- `settings.microphone`: text, the unique identifier of the chosen input device as Core Audio reports it, with its name next to it in `settings.microphoneName` for when it is not connected; absent means "Predefinito di sistema".
- `settings.shortcutRecord` and `settings.shortcutBookmark`: the key code and modifiers of each shortcut, or "none" when removed; absent means the default, ⌥⌘R and ⌥⌘B.
- `settings.onboardingDone`: yes/no, whether the welcome window was ended. Default no.
- `settings.calendarConnected`: yes/no, whether the user connected the calendar. Default no.
- `settings.speakerIdentification`: yes/no, the "Identifica i parlanti" switch. Default on.
- `settings.teamsAccessGranted`: yes/no, whether the Accessibility permission was seen granted at least once, so that its loss after a new version can be told. Default no.
- The state of the language check, of the omp check, of the login item's approval or error, of the Accessibility permission and of the calendar access granted by macOS are kept only in memory.

## playback-options

- `playback.speed`: number, one of 0.75, 1, 1.25, 1.5 and 2. Default 1; any other value reads as 1.
- `playback.skipSilence`: yes/no. Default off.
