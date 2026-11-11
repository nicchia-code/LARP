# Call summaries

Whether the calls are summarised by omp. The switch works whether or not omp can be reached.

## States

### Off (initial)
The switch is off; it starts off unless it was left on.
- `user.TURN_ON_SUMMARY` → On: the choice is saved and omp starts being looked for if it was not already.

### On
The switch is on.
- `user.TURN_OFF_SUMMARY` → Off: the choice is saved; summaries being written or waiting to be retried are abandoned.
