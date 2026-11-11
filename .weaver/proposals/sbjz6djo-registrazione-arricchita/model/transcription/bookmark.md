# Bookmark

A moment of a call that the user marked. It is created by `user.ADD_BOOKMARK`: during a recording, for the call being recorded, at the elapsed time, also while paused; on the page of a call whose audio is loaded and playing or paused, at the time reached. A bookmark at the same second as another one of the same call is not created again. It belongs to its call and has only its time.

## States

### Kept (initial)
The bookmark is shown in the bookmarks of its call, in the list of every bookmark and as a mark on the transcript line of its time, in the live window too while the call is recorded.
- `user.DELETE_BOOKMARK` → Deleted: only for this bookmark; it disappears everywhere.
- `call.DELETED` → Deleted: only for the call of the bookmark; it goes with the call.

### Deleted (final)
The bookmark no longer exists.
