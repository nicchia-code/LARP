# Main window

The window with the archive of the recorded calls: the list of calls on one side, the selected call on the other.

## States

### Closed (initial)
Only the menu bar icon is visible.
- `user.OPEN_WINDOW` → Open

### Open
The list of calls is visible, newest first, and can be narrowed with a search.
- `user.CLOSE_WINDOW` → Closed

#### No call selected (initial)
No call is shown next to the list.
- `user.SELECT_CALL` → Call selected

#### Call selected
The selected call is shown with its title, date, duration, progress and, once there is one, its transcript with who spoke each line and its summary, one at a time, as the user chooses.
- `user.SELECT_CALL` → Call selected: the newly selected call is shown.
- `user.EXPORT_CALL` → Call selected: only if the call has a transcript; the transcript, preceded by the summary when the call has one, is saved as a Markdown file where the user chooses.
- `call.DELETED` → No call selected: only if the deleted call is the one shown.
