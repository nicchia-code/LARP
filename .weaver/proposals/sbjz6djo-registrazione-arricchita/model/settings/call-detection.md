# Call detection

Whether the app watches the call apps that start using the microphone, and which of the known call apps it watches. Every known call app is watched until the user turns it off; the choice of each app is kept also while detection is off.

## States

### On (initial)
Calls are detected; the app starts here unless detection was left off.
- `user.TURN_OFF_CALL_DETECTION` → Off: the choice is saved; a proposal shown disappears and no new proposal or automatic recording starts; a recording in progress goes on.
- `user.WATCH_APP` → On: the app is watched from now on; if it is already using the microphone it counts as started.
- `user.UNWATCH_APP` → On: the app is no longer watched; a proposal shown for it disappears, a recording in progress goes on.

### Off
Calls are not detected; only recordings by hand are possible.
- `user.TURN_ON_CALL_DETECTION` → On: the choice is saved; watched apps already using the microphone count as started.
- `user.WATCH_APP` → Off: the choice of the app is saved for when detection is on again.
- `user.UNWATCH_APP` → Off: the choice of the app is saved for when detection is on again.
