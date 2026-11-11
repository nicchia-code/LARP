# User

The person who owns the Mac, takes part in the calls and uses the welcome window, the menu bar popover, the proposal panel, the recording pill and live window, the global keyboard shortcuts and the main window with its library, call pages and settings.

## Events

### START_RECORDING
The user chooses "Registra" in the popover of the menu bar, or "Nuova registrazione" in the sidebar of the main window, or presses the shortcut to start or stop recording, while no proposal to record is shown, to record by hand.

### ACCEPT_PROPOSAL
The user accepts the proposal to record a call that has just started, with "Registra questa call" in the proposal panel, in the popover of the menu bar or in the banner of the library, or with the shortcut to start or stop recording.

### DISMISS_PROPOSAL
The user discards the proposal to record a call with "Non questa", in the proposal panel, in the popover or in the banner of the library.

### STOP_RECORDING
The user chooses "Ferma registrazione" in the popover, "Ferma" in the pill or in the live window, or presses the shortcut to start or stop recording during a recording.

### PAUSE_RECORDING
The user pauses the recording in progress, from the pill, the live window or the popover.

### RESUME_RECORDING
The user resumes the paused recording, from the pill, the live window or the popover.

### OPEN_LIVE_WINDOW
The user opens the live window of the recording in progress, with a click on the pill or with "Apri finestra dal vivo" in the popover.

### CLOSE_LIVE_WINDOW
The user closes the live window during a recording.

### ADD_BOOKMARK
The user marks a moment with a bookmark: during a recording from the pill or the live window, or while listening to a call from the playback bar; the shortcut to add a bookmark does the same in both cases.

### DELETE_BOOKMARK
The user deletes a bookmark of a call.

### SELECT_BOOKMARK
The user clicks a bookmark, in the bookmarks of a call or in the list of every bookmark.

### ADD_NOTE
The user writes a note, in the live window during a recording or in the notes of a call page.

### EDIT_NOTE
The user changes the text of a note of a call.

### DELETE_NOTE
The user deletes a note of a call.

### OPEN_WINDOW
The user opens the main window on the library, with "Apri archivio" in the popover of the menu bar.

### CLOSE_WINDOW
The user closes the main window.

### SHOW_ALL_CALLS
The user chooses "Tutte le call" in the sidebar of the main window.

### SHOW_BOOKMARKS_VIEW
The user chooses "Segnalibri" in the sidebar of the main window, the list of every bookmark.

### SELECT_CALL
The user opens a call from its card in the library.

### DESELECT_CALL
The user goes back from the page of a call to the library, with "‹ Archivio".

### SHOW_SUMMARY
The user switches the page of a call to its summary.

### SHOW_NOTES
The user switches the page of a call to its notes, "Le mie note".

### SHOW_BOOKMARKS
The user switches the page of a call to its bookmarks.

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

### TURN_ON_CALL_DETECTION
The user turns on "Rileva le call" in the settings.

### TURN_OFF_CALL_DETECTION
The user turns off "Rileva le call" in the settings.

### WATCH_APP
The user turns on the chip of a known call app in "App da sorvegliare".

### UNWATCH_APP
The user turns off the chip of a known call app in "App da sorvegliare".

### TURN_ON_AUTO_RECORDING
The user turns on "Registra automaticamente le call rilevate", in the settings or in the popover.

### TURN_OFF_AUTO_RECORDING
The user turns off "Registra automaticamente le call rilevate", in the settings or in the popover.

### CHOOSE_MICROPHONE
The user chooses the microphone to record, a connected input device or "Predefinito di sistema", in the settings or in the popover.

### CHANGE_SHORTCUT
The user records a new key combination for one of the two shortcuts in the settings.

### CLEAR_SHORTCUT
The user removes the key combination of one of the two shortcuts in the settings.

### ALLOW_MICROPHONE
The user chooses "Consenti" for the microphone in the welcome window.

### ALLOW_SYSTEM_AUDIO
The user chooses "Consenti" for the system audio in the welcome window.

### CONTINUE_SETUP
The user goes on from the permissions to the choices in the welcome window, with "Continua".

### FINISH_SETUP
The user ends the welcome window, with "Inizia" or by closing it.

### CHOOSE_LANGUAGE
The user chooses the transcription language, Italian or English, in the settings or in the welcome window.

### TURN_ON_REFINEMENT
The user turns on the refinement of transcripts in the settings or in the welcome window.

### TURN_OFF_REFINEMENT
The user turns off the refinement of transcripts in the settings or in the welcome window.

### TURN_ON_SUMMARY
The user turns on the summaries of calls in the settings or in the welcome window.

### TURN_OFF_SUMMARY
The user turns off the summaries of calls in the settings or in the welcome window.

### TURN_ON_LAUNCH_AT_LOGIN
The user turns on starting the app at login in the settings.

### TURN_OFF_LAUNCH_AT_LOGIN
The user turns off starting the app at login in the settings.

### ALLOW_TEAMS_ACCESS
The user chooses "Consenti" for Microsoft Teams, in the welcome window or in the settings, to let LARP read Teams through the Accessibility of macOS.

### CONNECT_CALENDAR
The user chooses "Collega" for the calendar, in the welcome window or in the settings.

### DISCONNECT_CALENDAR
The user chooses "Scollega" for the calendar in the settings.

### TURN_ON_SPEAKER_IDENTIFICATION
The user turns on "Identifica i parlanti" in the settings.

### TURN_OFF_SPEAKER_IDENTIFICATION
The user turns off "Identifica i parlanti" in the settings.

### IMPORT_AUDIO
The user chooses an audio file with "Importa file audio" in the library.

### FILTER_BY_APP
The user chooses a filter chip above the cards of the library: "Tutte", a call app, "Manuali" or "Importate".

### SHOW_FOLDER
The user chooses a folder in the sidebar of the main window.

### CREATE_FOLDER
The user makes a new folder with "+ Nuova cartella" and types its name.

### RENAME_FOLDER
The user gives a folder a new name from its context menu.

### DELETE_FOLDER
The user deletes a folder from its context menu.

### MOVE_TO_FOLDER
The user chooses a folder, or "Nessuna cartella", in "Sposta in cartella" on the page of a call.

### COPY_SUMMARY
The user chooses "Copia sintesi" on the page of a call.

### COPY_TRANSCRIPT
The user chooses "Copia trascrizione" on the page of a call.

### EDIT_LINE
The user changes the text of a transcript line on the page of a call, after "Modifica testo".

### CHANGE_SPEED
The user clicks the speed in the playback bar.

### TURN_ON_SKIP_SILENCE
The user turns on "Salta i silenzi" in the playback bar.

### TURN_OFF_SKIP_SILENCE
The user turns off "Salta i silenzi" in the playback bar.

### TOGGLE_ACTION_ITEM
The user ticks or unticks an action item of a summary, on the page of its call or in the list of every action item.

### SHOW_ACTIONS_VIEW
The user chooses "Azioni" in the sidebar of the main window, the list of every action item.

### SELECT_DECISION
The user clicks the time of a decision in the summary of the call shown.

### ASK_CALL
The user asks a question with "Chiedi" under the summary of the call shown, or "Riprova" on a question that failed.

### TRANSLATE_TRANSCRIPT
The user chooses "Traduci" under the transcript of the call shown.

### SHOW_ORIGINAL
The user chooses "Mostra originale" under the translated transcript of the call shown.

### CHOOSE_SUMMARY_LANGUAGE
The user chooses the language of the summaries in the settings: "Come la call", "Italiano" or "English".

### TURN_ON_QUESTIONS
The user turns on "Domande e traduzioni con omp" in the settings.

### TURN_OFF_QUESTIONS
The user turns off "Domande e traduzioni con omp" in the settings.

### TURN_ON_MARKDOWN_FOLDER
The user turns on "Cartella Markdown" in the settings, which asks for the folder.

### CHOOSE_MARKDOWN_FOLDER
The user chooses another folder for the Markdown files with "Cambia" in the settings.

### TURN_OFF_MARKDOWN_FOLDER
The user turns off "Cartella Markdown" in the settings.

### CHOOSE_AUDIO_RETENTION
The user chooses how long audio files are kept in the settings: "Sempre", "Per 30 giorni" or "Per 90 giorni".

### REVEAL_ARCHIVE
The user chooses "Mostra nel Finder" for the location of the archive in the settings.
