---
description: Use when changing which call apps are noticed, the permissions and limits of a recording, the audio constants of the capture or the timing of its notices.
---
# Capture rules

## recorder
- Known call apps, with the bundle identifiers that belong to them:

  | Call app | Bundle identifiers |
  |---|---|
  | Zoom | `us.zoom.xos` |
  | Microsoft Teams | `com.microsoft.teams2`, `com.microsoft.teams` |
  | FaceTime | `com.apple.FaceTime` |
  | Slack | `com.tinyspeck.slackmacgap` |
  | Discord | `com.hnc.Discord` |
  | Webex | `Cisco-Systems.Spark`, `com.webex.meetingmanager` |
  | Safari | `com.apple.Safari` |
  | Chrome | `com.google.Chrome` |
  | Edge | `com.microsoft.edgemac` |
  | Firefox | `org.mozilla.firefox`, helper `org.mozilla.plugincontainer` |
  | Arc | `company.thebrowser.Browser` |
  | Brave | `com.brave.Browser` |

- A process using the microphone belongs to a call app when its bundle identifier is one of the app's, starts with one of them followed by a dot (a helper such as `com.google.Chrome.helper`), or is one of its helper identifiers. Otherwise its parent processes are checked the same way, up to 8 levels, stopping at the first process with identifier 1 or lower. The first app of the table that matches wins.
- A call app uses the microphone while at least one of its processes does. Apps already using the microphone when the app starts watching are reported as started; several apps that start or stop together are reported in alphabetical order of their names.
- At most one proposal or one recording at a time. While the permissions of a start are being checked, another start is ignored. A discarded proposal counts as the one proposal until its call app stops using the microphone.
- A started call app gives a proposal or an automatic recording only when "Rileva le call" is on and the app is watched. Automatic recording needs both permissions already granted, read without asking; when one is not granted yet the proposal is shown instead.
- The shortcut to start or stop recording starts a recording by hand when idle or after "Non questa", accepts the proposal when one is shown, and stops the recording during one; the shortcut to add a bookmark works during a recording and while the page of a call with its audio loaded is shown and playing or paused, and does nothing otherwise.
- A recording started by hand needs the microphone permission only. Accepting a proposal needs the microphone and the system audio recording permissions; the microphone is checked first and only the first missing one is told.
- The microphone permission is asked to the user when not decided yet. The system audio permission is checked by creating and destroying a system audio tap, which makes macOS ask the first time.
- The alert of a missing permission is titled "Permesso del microfono mancante" or "Permesso di registrazione dell'audio di sistema mancante", says «LARP non può registrare senza il permesso «<name>». Aprire Impostazioni di Sistema › Privacy e sicurezza › <name> e attivare LARP, poi riprovare.» with the names "Microfono" and "Registrazione audio di sistema", and offers "Apri Impostazioni di Sistema" (the Privacy_Microphone or Privacy_AudioCapture pane) and "Annulla". In English the alert is titled "Microphone permission missing" or "System audio recording permission missing", says «LARP can't record without the «<name>» permission. Open System Settings › Privacy & Security › <name>, turn on LARP, then try again.» with the names "Microphone" and "System Audio Recording", and offers "Open System Settings" and "Cancel".
- Elapsed time of a recording: whole seconds since its start, shown as `m:ss`, and as `h:mm:ss` from one hour on; it goes back to zero when the recording ends.
- The warning that echo cancellation is not available and the notice that the system audio is not available disappear by themselves after 10 seconds; showing one again restarts its countdown. The notices that the microphone or the system audio is lost stay until they are hidden, and stack under the menu bar icon, each below the previous one.
- The elapsed time keeps counting while the recording is paused; a bookmark of the call being recorded takes the elapsed time in whole seconds.
- Levels shown during a recording ("Call", "Mic", the waveforms of the pill and the live window, who is speaking): the peak of the audio of each track over the last 50 ms, updated 20 times a second, on a scale from −60 dBFS (empty) to 0 dBFS (full); a track counts as speaking while its level stays above −40 dBFS for at least 200 ms, and stops 500 ms after it falls below. While paused every level is empty.

## capture
- Storage format of both tracks: 16 kHz mono, AAC at 32,000 bit/s per track.
- The packet table of a track is written every 2 seconds of audio written: a crash loses at most about 2 seconds.
- Missing audio of more than 1 second in a track is filled with silence; silence is written in pieces of at most 10 seconds. When a recording stops while the microphone or the system audio is lost, its track is filled with silence up to the moment of the stop.
- A track starts at the moment its first audio was captured; when no audio ever arrived, at the moment the track was created.
- Every piece of audio is written to its file before it is handed to the live transcription.
- When a track fails to be written, it stops taking audio for the rest of the recording; the failure is only logged.
- The system audio track of a recording tied to a call app is required: if it cannot start, the recording does not start. For a recording started by hand it is optional. The microphone is always required.

## microphone
- The microphone to use is the chosen input device when it is among the connected devices, matched by its unique identifier, otherwise the default input device; with "Predefinito di sistema" always the default input device.
- The echo canceller works on 16 kHz mono audio in frames of 10 ms (160 samples); audio waiting for the rest of its frame is kept until the next one.
- A microphone frame that the echo canceller cannot take goes on to the track as captured.
- A new echo canceller, which learns the echo path from scratch, is made at every start and restart of the microphone and every time the system audio comes back after being lost; it is dropped while the system audio is lost. While there is no echo canceller, the microphone goes on to its track as captured.
- The echo canceller removes only the echo: no high-pass filter, pre-amplifier, level adjustment, noise suppression or gain control, so the level of the voice is not changed.
