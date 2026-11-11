# Speaker identification

Whether Microsoft Teams and the calendar give names to the participants of calls: the names given on their own after the separation of voices, the names of the speakers in the live window, and the names offered when renaming a participant. Titles of calls and what the proposal shows do not depend on it.

## States

### On (initial)
Names are given and offered; the app starts here unless the switch was left off.
- `user.TURN_OFF_SPEAKER_IDENTIFICATION` → Off: the choice is saved; names already given stay.

### Off
No name is given on its own nor offered; the live window shows "Altri".
- `user.TURN_ON_SPEAKER_IDENTIFICATION` → On: the choice is saved; it applies to separations that end after it.
