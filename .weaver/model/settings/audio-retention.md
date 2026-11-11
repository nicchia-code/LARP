# Audio retention

How long the audio of calls is kept: always, or 30 or 90 days from the start of each call. When the time is over, the audio files of a ready call are deleted from the Mac; its transcript, summary, notes, bookmarks and waveform stay, and it can no longer be listened to.

## States

### Keep forever (initial)
Audio is kept until its call is deleted; the app starts here unless a limit was chosen.
- `user.CHOOSE_AUDIO_RETENTION` → Keep for a time: for 30 or 90 days; the choice is saved and the audio of the ready calls older than that is deleted at once.
- `user.CHOOSE_AUDIO_RETENTION` → Keep forever: for "Sempre"; nothing changes.

### Keep for a time
The audio of a ready call is deleted once the chosen number of days has passed since its start. The calls are looked at when the app launches and every hour.
- `user.CHOOSE_AUDIO_RETENTION` → Keep for a time: for the other number of days; the choice is saved and the audio of the ready calls older than that is deleted at once.
- `user.CHOOSE_AUDIO_RETENTION` → Keep forever: for "Sempre"; the choice is saved; audio already deleted does not come back.
