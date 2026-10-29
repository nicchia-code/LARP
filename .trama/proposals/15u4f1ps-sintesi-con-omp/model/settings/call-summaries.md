# Call summaries

Whether the calls are summarised by the assistant, independently of transcript refinement. Nothing of a transcript leaves the Mac for a summary while summaries are off.

## States

### Off (initial)
Summaries are off: no call is summarised, on its own or on request. Summaries written before can still be read, searched and exported.
- `user.TURN_ON_SUMMARY` → On

### On
New calls are summarised on their own after the participants are told apart, and the user can ask to summarise any call whose participants have been told apart.
- `user.TURN_OFF_SUMMARY` → Off: summaries being written or waiting to be tried again stop; summaries already written stay.
