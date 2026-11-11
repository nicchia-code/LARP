# Teams access

Whether LARP may read Microsoft Teams, that is whether macOS gives it the Accessibility permission. macOS does not tell when the permission is granted or taken away, so it is read again at launch, when the settings open and, after the user asked for it, every two seconds for two minutes. With the ad-hoc signature of LARP, macOS forgets the permission at every new version of the app, which then asks for it again.

## States

### Not allowed (initial)
LARP does not read Teams. The Teams row of the settings and of the welcome window offers "Consenti"; when the permission was granted to an earlier version, the popover and the settings say that it must be allowed again.
- `macos.APP_LAUNCHED` → Allowed: only if the permission is granted.
- `user.OPEN_SETTINGS` → Allowed: only if the permission is granted.
- `user.ALLOW_TEAMS_ACCESS` → Awaiting permission: macOS asks the user to allow LARP in System Settings › Privacy e sicurezza › Accessibilità, and that pane opens.

### Awaiting permission
LARP waits for the user to allow it in System Settings.
- `time.ACCESSIBILITY_CHECK_DUE` → Allowed: only if the permission is now granted.
- `time.ACCESSIBILITY_CHECK_DUE` → Awaiting permission: while the permission is still missing and less than two minutes have passed since the request.
- `time.ACCESSIBILITY_CHECK_DUE` → Not allowed: when two minutes have passed without the permission.
- `user.OPEN_SETTINGS` → Allowed: only if the permission is granted.

### Allowed
LARP reads Teams while Teams is running.
- `macos.APP_LAUNCHED` → Not allowed: only if the permission is missing, for example after a new version of LARP; emits ACCESS_LOST.
- `user.OPEN_SETTINGS` → Not allowed: only if the permission has been taken away; the reading of Teams stops and ACCESS_LOST is emitted.

## Events

### ACCESS_LOST
Emitted when Teams can no longer be read because the permission is missing.
