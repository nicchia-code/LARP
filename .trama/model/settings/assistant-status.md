# Assistant status

Whether the assistant can be reached on the Mac. The app looks for it only while transcript refinement or call summaries, or both, are on.

## States

### Not needed (initial)
Refinement and summaries are both off: the app does not look for the assistant.
- `user.TURN_ON_REFINEMENT` → Needed
- `user.TURN_ON_SUMMARY` → Needed

### Needed
Refinement, summaries or both are on.
- `user.TURN_OFF_REFINEMENT` → Not needed: only if summaries are off.
- `user.TURN_OFF_SUMMARY` → Not needed: only if refinement is off.
- `macos.APP_LAUNCHED` → Checking: looks for the assistant again.
- `user.OPEN_SETTINGS` → Checking: looks for the assistant again.

#### Checking (initial)
The app is looking for the assistant on the Mac and asking it to answer.
- `assistant.REACHED` → Assistant ready
- `assistant.UNREACHABLE` → Assistant missing

#### Assistant ready
The assistant has been found and answers.

#### Assistant missing
The assistant is not found or does not answer. Calls are still sent to refinement and to summary, which fail and are tried again later.
