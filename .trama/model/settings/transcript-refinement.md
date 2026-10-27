# Transcript refinement

Whether the transcripts of the calls are refined by the assistant, and whether the assistant can be reached on the Mac. Nothing of a transcript leaves the Mac while refinement is off.

## States

### Off (initial)
Refinement is off: no call is refined, on its own or on request.
- `user.TURN_ON_REFINEMENT` → On

### On
New calls are refined on their own after the participants are told apart, and the user can ask to refine any ready call.
- `user.TURN_OFF_REFINEMENT` → Off: calls being refined or waiting to be refined again become ready with the transcript as it was.
- `macos.APP_LAUNCHED` → Checking: looks for the assistant again.
- `user.OPEN_SETTINGS` → Checking: looks for the assistant again.

#### Checking (initial)
The app is looking for the assistant on the Mac and asking it to answer.
- `assistant.REACHED` → Assistant ready
- `assistant.UNREACHABLE` → Assistant missing

#### Assistant ready
The assistant has been found and answers.

#### Assistant missing
The assistant is not found or does not answer. Calls are still sent to refinement, which fails and is tried again later.
