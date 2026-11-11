---
description: "Use when reading or changing the stored settings: language, refinement and summary switches, launch at login."
---
# Settings data

## settings
- The settings are kept in the user defaults of the app, one value per key, across launches.
- `settings.transcriptionLanguage`: text, the locale identifier of the chosen language, `it-IT` (shown "Italiano") or `en-US` (shown "English"). Default `it-IT`; an unknown value also reads as `it-IT`.
- `settings.transcriptRefinement`: yes/no, transcript refinement switch. Default off.
- `settings.callSummaries`: yes/no, call summaries switch. Default off.
- `settings.launchAtLogin`: yes/no, a copy of the login item being on or awaiting approval, written each time its state is read. The real state is the login item kept by macOS.
- The state of the language check, of the omp check and of the login item's approval or error are kept only in memory.
