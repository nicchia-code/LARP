# Launch at login

Whether the app starts when the user logs in to the Mac. It always shows the real state of the app's login item, read again when the app launches and every time the settings window opens.

## States

### Off (initial)
The app does not start at login.
- `macos.APP_LAUNCHED` → On: only if the login item is on.
- `macos.APP_LAUNCHED` → Awaiting approval: only if the login item waits for the user's approval in System Settings.
- `user.OPEN_SETTINGS` → On: only if the login item has been turned on outside the app.
- `user.OPEN_SETTINGS` → Awaiting approval: only if the login item now waits for approval.
- `user.TURN_ON_LAUNCH_AT_LOGIN` → On: the login item is registered and macOS turns it on.
- `user.TURN_ON_LAUNCH_AT_LOGIN` → Awaiting approval: the login item is registered and macOS asks the user to approve it in System Settings; the window says where to approve it.
- `user.TURN_ON_LAUNCH_AT_LOGIN` → Off: when the registration fails; the window shows the error.

### On
The app starts at login.
- `user.OPEN_SETTINGS` → Off: only if the login item has been turned off outside the app.
- `user.TURN_OFF_LAUNCH_AT_LOGIN` → Off: the login item is removed.
- `user.TURN_OFF_LAUNCH_AT_LOGIN` → On: when the removal fails; the window shows the error.

### Awaiting approval
The login item is registered but the user has not approved it yet; the switch shows as on.
- `user.OPEN_SETTINGS` → On: only if the user has approved it in System Settings.
- `user.OPEN_SETTINGS` → Off: only if the login item has been removed outside the app.
- `user.TURN_OFF_LAUNCH_AT_LOGIN` → Off: the login item is removed.
- `user.TURN_OFF_LAUNCH_AT_LOGIN` → Awaiting approval: when the removal fails; the window shows the error.
