---
refs:
  - bookmark
  - note
  - call
  - transcription
  - requirements/data#bookmark
  - requirements/data#note
  - requirements/data#General
  - user.ADD_BOOKMARK
  - user.DELETE_BOOKMARK
  - user.ADD_NOTE
  - user.EDIT_NOTE
  - user.DELETE_NOTE
---
# Segnalibri e note

Segnalibri e note diventano dati della call nell'archivio, con le loro regole di creazione, modifica ed eliminazione.

## Cosa deve valere

- **Segnalibro** (ADD_BOOKMARK, dalla pillola, dalla finestra dal vivo, dalla barra di riproduzione o con la scorciatoia): durante una registrazione, per la call registrata, al tempo trascorso in secondi interi, anche in pausa; nella pagina di una call con audio caricato in riproduzione o in pausa, al tempo raggiunto. Un segnalibro allo stesso secondo di un altro della stessa call non viene creato di nuovo. Ha solo il suo tempo, mai sotto zero. DELETE_BOOKMARK lo toglie ovunque.
- **Nota** (ADD_NOTE) con testo non vuoto una volta tolti gli spazi: nella finestra dal vivo, al tempo trascorso; nelle note della pagina di una call, al tempo raggiunto se l'audio è in riproduzione o in pausa, senza tempo altrimenti. Ordine: per tempo, quelle senza tempo dopo le altre nell'ordine in cui sono state scritte. EDIT_NOTE: testo nuovo non vuoto → la nota lo prende e tiene il suo tempo; vuoto → la nota è eliminata. DELETE_NOTE la elimina.
- Le note non vanno mai a omp: né rifinitura né sintesi le inviano.
- La Call: segnalibri e note si possono aggiungere mentre è registrata; eliminare la call (`call.DELETED`) elimina con essa segnalibri e note; segnalibri e note non sono legati alle righe della trascrizione, così restano quando le righe dal vivo sono scartate e la call viene ritrascritta.
- Dati: **Bookmark** con identificatore univoco, tempo in secondi dall'inizio della call, call di appartenenza. **Note** con identificatore univoco, testo trimmato e mai vuoto, tempo in secondi assente per una nota scritta senza ascolto, momento di scrittura (che ordina le note senza tempo), call di appartenenza. L'archivio ha sei tipi di record; una call possiede righe, partecipanti, al più una sintesi, segnalibri e note. Un archivio salvato prima dei segnalibri e delle note si apre con ogni call senza.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Dati: `Sources/LARP/Model/Call.swift`, `Sources/LARP/Model/ArchiveStore.swift` `schema`, `delete` (nessun VersionedSchema); i nuovi campi SwiftData hanno bisogno di default per aprire archivi vecchi (vedi `summaryStateRawValue`); relazioni con cancellazione a cascata come per righe e partecipanti.
- Ciclo di vita: `Sources/LARP/Call/CallLifecycle.swift` `delete(_:)`, `deleteCall`; registrazione `CallLifecycle+Recording.swift` `recordingStarted` (le righe dal vivo vengono buttate se la sessione non ha coperto tutto).
- Assicurarsi che `Sources/LARP/Refinement/RefinementRequest.swift` e `Sources/LARP/Summary/SummaryRequest.swift` non includano le note.
- Tempo trascorso: `Recorder.elapsedSeconds` in `Sources/LARP/Capture/Recorder.swift`; tempo raggiunto: `Sources/LARP/Playback/PlaybackController.swift`.
- Il lavoro del Model sta sul main actor; test in `Tests/LARPTests/` (`ArchiveStoreTests`, `CallDeletionDuringWorkTests`, fake in `CallLifecycleFakes.swift`); commenti che citano gli eventi del Model.
