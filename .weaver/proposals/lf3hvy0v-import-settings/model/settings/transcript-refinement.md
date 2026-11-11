# Transcript refinement

Whether the transcripts of calls are refined by omp. The switch works whether or not omp can be reached.

## States

### Off (initial)
The switch is off; it starts off unless it was left on.
- `user.TURN_ON_REFINEMENT` → On: the choice is saved and omp starts being looked for if it was not already.

### On
The switch is on.
- `user.TURN_OFF_REFINEMENT` → Off: the choice is saved; refinements in progress stop and the calls waiting for refinement keep their transcript as it was.
