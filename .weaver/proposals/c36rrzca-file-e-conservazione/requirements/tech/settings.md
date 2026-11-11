---
description: "Use when changing how settings talk to macOS: speech models, login item, network watching, setting events."
---
# Settings technology

## settings
- Each Machine of the Feature is one shared instance on the main actor, observed by the settings window.
- Settings never depends on the call layer: the app entry point wires them, passing the switches and forwarding the turn-off news to the call lifecycle.
- Each outside dependency (speech models, network, omp check, omp lookup, login item) sits behind a protocol so tests can replace it.
- News between parts travels through broadcast streams: each listener gets a stream of its own and receives only news sent after it subscribed.

## transcription-language
- Installed models come from the speech transcriber's installed locales; a missing model is installed through Apple's asset inventory, asking for a progressive-transcription transcriber of that language.
- The network coming back is watched with a network path monitor on its own queue; news is sent only when the path goes from unsatisfied to satisfied, never on the first reading. The same news goes to the call lifecycle.

## launch-at-login
- The login item is the main app service of ServiceManagement.

## markdown-folder
- The folder is chosen with the system open panel; the app is not sandboxed, so its path is kept as is. Files are written atomically, off the main actor, one call at a time, in UTF-8.

## audio-retention
- The hourly check runs on a timer of the app while it is open; removing files goes through the archive's file manager, off the main actor, and the mark on the call is saved on the main actor.

## main-window
- "Mostra nel Finder" selects the folder `LARP` of Application Support with `NSWorkspace.activateFileViewerSelecting`.
