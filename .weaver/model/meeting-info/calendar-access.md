# Calendar access

Whether LARP reads the calendar of the Mac. While it is connected and macOS grants full access to events, LARP reads, on the Mac, the event in progress when a recording starts (its title and its invited people) and the events of the rest of the day for "Prossime" in the popover.

## States

### Not connected (initial)
The calendar is not read; the app starts here unless the calendar was connected before.
- `user.CONNECT_CALENDAR` → Connected: when macOS grants full access to the events, asked to the user the first time; the choice is saved.
- `user.CONNECT_CALENDAR` → Refused: when the user refuses the access, or refused it before; the settings say that the access is refused and offer to open the calendars pane of System Settings.

### Connected
The calendar is read.
- `user.DISCONNECT_CALENDAR` → Not connected: the choice is saved; the calendar is no longer read, while the permission of macOS stays as it is.
- `macos.APP_LAUNCHED` → Refused: only if macOS no longer grants the access.
- `user.OPEN_SETTINGS` → Refused: only if macOS no longer grants the access.

### Refused
The user wants the calendar but macOS does not grant the access.
- `user.CONNECT_CALENDAR` → Refused: the calendars pane of System Settings opens.
- `macos.APP_LAUNCHED` → Connected: only if macOS now grants the access.
- `user.OPEN_SETTINGS` → Connected: only if macOS now grants the access.
- `user.DISCONNECT_CALENDAR` → Not connected: the choice is saved.
