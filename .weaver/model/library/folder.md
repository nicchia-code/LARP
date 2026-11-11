# Folder

A folder the user made to group calls. It is created by `user.CREATE_FOLDER` with a name that is not empty once trimmed and that no other folder has, ignoring case; otherwise nothing is created. A call is in at most one folder; every call stays in "Tutte le call" whatever its folder.

## States

### Kept (initial)
The folder is listed in the sidebar and offered by "Sposta in cartella".
- `user.RENAME_FOLDER` → Kept: only for this folder, and only if the new name, trimmed, is not empty and no other folder has it; otherwise the folder keeps its name.
- `user.MOVE_TO_FOLDER` → Kept: only when this folder is chosen for a call; the call leaves its previous folder, if any, and joins this one. Choosing "Nessuna cartella" takes the call out of its folder.
- `user.DELETE_FOLDER` → Deleted: only for this folder; its calls stay in the archive without folder.

### Deleted (final)
The folder no longer exists.
