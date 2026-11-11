# Call questions

Whether the user may ask omp questions about a call and have its transcript translated by omp. The switch works whether or not omp can be reached.

## States

### Off (initial)
The switch is off; it starts off unless it was left on. "Chiedi qualcosa a questa call" and "Traduci" are not shown.
- `user.TURN_ON_QUESTIONS` → On: the choice is saved and omp starts being looked for if it was not already.

### On
The switch is on.
- `user.TURN_OFF_QUESTIONS` → Off: the choice is saved; a question or translation being made is stopped.
