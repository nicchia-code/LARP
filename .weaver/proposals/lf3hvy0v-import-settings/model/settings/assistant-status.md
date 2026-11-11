# Assistant status

Whether omp can be reached on the Mac. omp is looked for only while transcript refinement, call summaries or both are on; the result is only shown in the settings window and blocks nothing.

## States

### Not needed (initial)
Both switches are off; omp is not looked for. The app starts here when both switches were left off.
- `user.TURN_ON_REFINEMENT` → Needed: omp is looked for.
- `user.TURN_ON_SUMMARY` → Needed: omp is looked for.

### Needed
At least one switch is on. The app starts here, in Checking, when a switch was left on, but omp is only looked for once the app has launched.
- `macos.APP_LAUNCHED` → Checking: omp is looked for again.
- `user.OPEN_SETTINGS` → Checking: omp is looked for again, abandoning a check in progress.
- `user.TURN_OFF_REFINEMENT` → Not needed: only if summaries are off too; the check in progress is abandoned, its result ignored.
- `user.TURN_OFF_SUMMARY` → Not needed: only if refinement is off too; the check in progress is abandoned, its result ignored.

#### Checking (initial)
omp is searched for and asked to answer. Only the result of the latest check counts.
- `assistant.REACHED` → Assistant ready
- `assistant.UNREACHABLE` → Assistant missing

#### Assistant ready
omp answered in time. Turning on the other switch does not look for omp again.

#### Assistant missing
omp was not found, failed or did not answer in time. Turning on the other switch or the network coming back does not look for omp again.
