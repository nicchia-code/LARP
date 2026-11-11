---
refs:
- call
- requirements/data#call
- requirements/tech#call/Created
- requirements/tech#call/Ready
- user.IMPORT_AUDIO
- user.EDIT_LINE
---
# Import, forma d'onda, correzioni

Quando il lavoro è finito, una call può nascere dall'import di un file audio, ogni call pronta ha la sua forma d'onda colorata per voce e il testo delle righe di una call pronta si corregge a mano, come dice `call`.

## Import di un file audio
- "Importa file audio" nella libreria apre il pannello di apertura di sistema per i file audio; il file scelto (`user.IMPORT_AUDIO`) viene letto (qualsiasi formato che il sistema sa leggere, per esempio m4a, mp3, wav, aiff, caf) e convertito, fuori dal thread principale, con lo stesso convertitore e la stessa scrittura delle tracce di una registrazione, nella traccia dell'audio di sistema della call. Il file importato non viene mai tenuto né modificato; la call non ha traccia del microfono.
- La call nasce solo dopo che la conversione è riuscita. Se il file non si può leggere o convertire, un avviso "Impossibile importare il file" con il motivo lo dice e non nasce nessuna call.
- La call importata prende come titolo il nome del file senza estensione, come inizio l'ora di ultima modifica del file, come durata la lunghezza del suo audio, nessuna app di call, la lingua di trascrizione scelta in quel momento, ed è segnata come importata (un archivio salvato prima apre ogni call come non importata). Va in Trascrizione se la sua lingua è pronta, altrimenti in Attesa della lingua.
- Viene trascritta e separata come le altre; poiché non ha microfono, tutte le voci diventano partecipanti e nessuna è "Io".

## Forma d'onda
- Una call conserva, opzionale, la sua forma d'onda: 44 barre ordinate, ciascuna un livello da 0 a 1 e un parlante (io, un numero di partecipante, altri o silenzio), assente finché non è calcolata.
- Ogni barra è il picco di entrambe le tracce sulla sua parte della call, su una scala da −50 dBFS a 0 dBFS, e prende il parlante della riga che copre il centro del suo tempo ("Io" quando è una riga del microfono, silenzio altrimenti).
- Viene calcolata una volta quando la call diventa pronta, e di nuovo dopo una separazione che viene rifatta. Le tracce si leggono a blocchi, mai intere, fuori dal thread principale, e il risultato si salva con la call sul thread principale.
- All'avvio, le call pronte senza forma d'onda e con audio la ricevono in sottofondo, una alla volta, dalla più recente, dopo che ogni altro lavoro dell'avvio è partito.

## Correzione del testo
- Solo quando la call è pronta, "Modifica testo" sotto le righe rende il testo di ogni riga modificabile in posto, come campo senza bordo con una sottolineatura `#E4E4DC`, finché il link, che diventa "Fine", non viene scelto.
- `user.EDIT_LINE` vale solo per una riga di questa call e per un testo non vuoto una volta ripulito: la riga prende il nuovo testo e, quando conserva un originale di una rifinitura, anche il suo testo originale prende il nuovo testo, così una nuova rifinitura parte da lì e "Ripristina originale" riporta il testo corretto; parlante e parlante originale non cambiano, e una correzione da sola non fa mai contare la call come rifinita. Un testo vuoto lascia la riga com'era.

## Code notes
Commit: 58d947126f08b8c7e4128d08782a627080bde977
- Transizioni: `Sources/LARP/Call/CallStateMachine.swift` `CallStateMachine.target`, `CallEvent` (tabella pura, gli eventi portano i fatti di guardia); effetti in `CallLifecycle.swift` `apply(_:to:)`, `enter(_:call:)`.
- Coda di trascrizione: `CallLifecycle+Transcription.swift` `scheduleTranscription`; `TranscriptionService.transcribeFile(at:speaker:language:)` riusabile per l'import.
- Conversione e scrittura tracce: `Sources/LARP/Recording/TrackPipeline.swift`. Percorsi: `Sources/LARP/Model/AppPaths.swift`; file `Recordings/<id>/system.caf`, salvati relativi.
- Separazione rifatta: `CallLifecycle+Separation.swift` `finishSeparation` (punto per ricalcolare la forma d'onda); rifatta, sostituisce i partecipanti.
- Originali di rifinitura: `TranscriptLine.swift`, `CallLifecycle+Refinement.swift` `applyRefinement`, `restoreOriginals`, `Call.isRefined` (rifinita = una riga ha un testo originale).
- Nuovi campi SwiftData con default (vedi `summaryStateRawValue`); `ArchiveStore.schema`.
- Lavoro per call come `Task` in `running*[id]`; annullare non è mai un fallimento. Fake in `Tests/LARPTests/CallLifecycleFakes.swift`.
- Pannello di modifica: `Sources/LARP/Archive/TranscriptView.swift`.
