# Transcript refinement

Whether the transcripts of the calls are refined by the assistant. Nothing of a transcript leaves the Mac for refinement while refinement is off.

## States

### Off (initial)
Refinement is off: no call is refined, on its own or on request.
- `user.TURN_ON_REFINEMENT` → On

### On
New calls are refined on their own after the participants are told apart, and the user can ask to refine any ready call.
- `user.TURN_OFF_REFINEMENT` → Off: calls being refined or waiting to be refined again become ready with the transcript as it was.
