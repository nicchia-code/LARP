# User

The person who owns the Mac, takes part in the calls and uses the menu bar popover, the proposal panel and the main window with its library, call pages and settings.

## Events

### START_RECORDING
The user chooses "Registra" in the popover of the menu bar, or "Nuova registrazione" in the sidebar of the main window, while no proposal to record is shown, to record by hand without a call app.

### ACCEPT_PROPOSAL
The user accepts the proposal to record a call that has just started, with "Registra questa call" in the proposal panel, in the popover of the menu bar or in the banner of the library.

### STOP_RECORDING
The user chooses "Ferma registrazione" in the popover of the menu bar.

### OPEN_WINDOW
The user opens the main window on the library, with "Apri archivio" in the popover of the menu bar.

### CLOSE_WINDOW
The user closes the main window.

### SELECT_CALL
The user opens a call from its card in the library.

### DESELECT_CALL
The user goes back from the page of a call to the library, with "‹ Archivio".

### RENAME_CALL
The user gives a call a title of their own, or clears it to get the default title back.

### RENAME_PARTICIPANT
The user gives a participant of a call a name of their own, or clears it to get the default name back.

### ASK_TO_DELETE
The user asks to delete the call shown; the app asks for confirmation.

### CANCEL_DELETION
The user cancels the deletion of a call when asked for confirmation.

### DELETE_CALL
The user confirms the deletion of a call.

### EXPORT_CALL
The user exports the call shown as a Markdown file.

### REFINE_TRANSCRIPT
The user asks to refine the transcript of the call shown.

### RESTORE_TRANSCRIPT
The user brings the transcript of the call shown back to the text and speakers it had before refinement.

### SUMMARIZE_CALL
The user asks omp to write the summary of the call shown, with "Sintetizza", or to write it again, with "Rigenera".

### PLAY
The user starts or resumes listening to the audio of the call shown.

### PAUSE
The user pauses the audio of the call shown.

### SEEK
The user moves the playback position of the call shown to another time.

### SELECT_SENTENCE
The user clicks a line of the transcript of the call shown.

### OPEN_SETTINGS
The user opens the settings, with "Impostazioni" in the popover of the menu bar or in the sidebar of the main window, or with ⌘,.

### CLOSE_SETTINGS
The user goes back from the settings to the library, with "‹ Archivio".

### CHOOSE_LANGUAGE
The user chooses the transcription language, Italian or English, in the settings.

### TURN_ON_REFINEMENT
The user turns on the refinement of transcripts in the settings.

### TURN_OFF_REFINEMENT
The user turns off the refinement of transcripts in the settings.

### TURN_ON_SUMMARY
The user turns on the summaries of calls in the settings.

### TURN_OFF_SUMMARY
The user turns off the summaries of calls in the settings.

### TURN_ON_LAUNCH_AT_LOGIN
The user turns on starting the app at login in the settings.

### TURN_OFF_LAUNCH_AT_LOGIN
The user turns off starting the app at login in the settings.
