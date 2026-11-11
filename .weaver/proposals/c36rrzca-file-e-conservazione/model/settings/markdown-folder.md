# Markdown folder

Whether every ready call is kept, on its own, as a Markdown file in a folder the user chose, with the same content as the Markdown export. Each call has at most one file there, which follows it: written when the call becomes ready, written again when what the export holds changes, renamed with the call and deleted with it. Files are written on the Mac only.

## States

### Off (initial)
No file is written; the app starts here unless the folder was left on. Files written before stay where they are.
- `user.TURN_ON_MARKDOWN_FOLDER` → On: when the user chooses a folder in the system open panel; the choice is saved and every ready call is written into it at once.
- `user.TURN_ON_MARKDOWN_FOLDER` → Off: when the user cancels the open panel.

### On
Ready calls are kept as files in the folder.
- `user.CHOOSE_MARKDOWN_FOLDER` → On: when the user chooses another folder; the choice is saved, the files in the previous folder stay, and every ready call is written into the new one at once.
- `user.TURN_OFF_MARKDOWN_FOLDER` → Off: the choice is saved; the files written stay.
- `call.READY` → On: the file of the call is written, replacing the one it had.
- `call-summary.SUMMARY_WRITTEN` → On: only for a ready call; its file is written again.
- `user.RENAME_CALL` → On: only for a ready call; the file takes the new name, the one with the old name is removed.
- `user.RENAME_PARTICIPANT` → On: only for a ready call; its file is written again.
- `user.EDIT_LINE` → On: its file is written again.
- `user.RESTORE_TRANSCRIPT` → On: its file is written again.
- `user.TOGGLE_ACTION_ITEM` → On: only for a ready call; its file is written again.
- `user.ADD_NOTE` → On: only for a ready call; its file is written again.
- `user.EDIT_NOTE` → On: only for a ready call; its file is written again.
- `user.DELETE_NOTE` → On: only for a ready call; its file is written again.
- `user.ADD_BOOKMARK` → On: only for a ready call; its file is written again.
- `user.DELETE_BOOKMARK` → On: only for a ready call; its file is written again.
- `call.DELETED` → On: the file of the call is removed from the folder.
