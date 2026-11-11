# Playback options

The speed of playback and whether silences are skipped, the same for every call and kept across launches. The speed goes, one click after the other, through 1×, 1,25×, 1,5×, 2× and 0,75×, then 1× again; the pitch of voices does not change with it.

## States

### Not skipping (initial)
Playback goes through every moment of the audio; the app starts here unless skipping was left on.
- `user.CHANGE_SPEED` → Not skipping: the next speed is saved and applies at once, also to audio playing.
- `user.TURN_ON_SKIP_SILENCE` → Skipping: the choice is saved.

### Skipping
While playing, every stretch of the audio without transcript lines longer than 2 seconds is jumped over, from the end of the line before it to the start of the next line; the time reached shows the jump.
- `user.CHANGE_SPEED` → Skipping: the next speed is saved and applies at once, also to audio playing.
- `user.TURN_OFF_SKIP_SILENCE` → Not skipping: the choice is saved.
