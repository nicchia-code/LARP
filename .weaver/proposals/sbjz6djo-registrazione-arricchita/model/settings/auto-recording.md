# Automatic recording

Whether a detected call is recorded on its own, without a proposal, when the microphone and the system audio permissions are already granted. When a permission is not granted yet, the proposal is shown as when this switch is off.

## States

### Off (initial)
Every detected call goes through the proposal; the app starts here unless the switch was left on.
- `user.TURN_ON_AUTO_RECORDING` → On: the choice is saved; a proposal already shown stays.

### On
Detected calls are recorded on their own.
- `user.TURN_OFF_AUTO_RECORDING` → Off: the choice is saved; a recording in progress goes on.
