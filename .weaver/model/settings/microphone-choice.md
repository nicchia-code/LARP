# Microphone choice

Which microphone is recorded: the default microphone of the Mac, or an input device the user chose. The list offered holds "Predefinito di sistema" and the input devices connected now, plus the chosen one, marked as not connected, when it is missing.

## States

### System default (initial)
The default microphone of the Mac is recorded and followed as it changes; the app starts here unless a microphone was chosen before.
- `user.CHOOSE_MICROPHONE` → Chosen microphone: only for an input device; the choice is saved, and a recording in progress moves to it at once.
- `user.CHOOSE_MICROPHONE` → System default: for "Predefinito di sistema"; nothing changes.

### Chosen microphone
The chosen input device is recorded whenever it is connected; while it is not connected, the default microphone of the Mac is recorded in its place.
- `user.CHOOSE_MICROPHONE` → System default: for "Predefinito di sistema"; the choice is saved, and a recording in progress moves to the default microphone at once.
- `user.CHOOSE_MICROPHONE` → Chosen microphone: for another input device; the choice is saved, and a recording in progress moves to it at once.
