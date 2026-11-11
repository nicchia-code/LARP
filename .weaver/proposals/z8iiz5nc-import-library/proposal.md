---
status: approved
kind: import
requires:
- 5zk696pr
- o3du0qj5
base:
  model/library/feature.md: new
  model/library/main-window.md: new
  model/library/playback.md: new
  requirements/rules/library.md: new
  requirements/tech/library.md: new
created: 2026-11-11T12:33:57.258Z
label: Import
job: a8nt702p
---
# Import: Library

Importata la Feature `library`: la finestra dell'archivio (Machine UI `main-window`) e l'ascolto dell'audio di una call (`playback`), con le regole di ricerca, ordine, sintesi, esportazione Markdown, formati e linea corrente (`requirements/rules`) e la struttura della riproduzione (`requirements/tech`). Fonti: `Sources/LARP/Archive/`, `Sources/LARP/Playback/`, la scena e il menu in `Sources/LARP/App/`, i controlli di `Sources/LARP/Call/CallLifecycle*.swift` e i test in `Tests/LARPTests/`.

## Doubts
- `EngineTrackPlayer.start` in `Sources/LARP/Playback/TrackPlayer.swift`: se il motore audio non parte, la riproduzione torna a Stopped come se fosse finita, senza alcun avviso.
- `PlaybackController.show` in `Sources/LARP/Playback/PlaybackController.swift`: la disponibilità dell'audio e la sua durata sono calcolate una sola volta al caricamento; file che diventano leggibili o spariscono dopo non sono ricontrollati.
- `CallDetailView` in `Sources/LARP/Archive/CallDetailView.swift`: i tempi delle linee per la linea corrente sono aggiornati solo quando cambiano il numero di linee o lo stato della call; tempi cambiati a parità di numero lascerebbero un'evidenziazione errata.
- `CallDetailView.init`: la vista (sintesi o trascrizione) è scelta solo alla selezione; una sintesi scritta mentre la call è mostrata non cambia vista (forse voluto).
- `ArchiveView.list` in `Sources/LARP/Archive/ArchiveView.swift`: una call selezionata che la ricerca nasconde resta mostrata nel dettaglio.
- `ArchiveView` `fileExporter`: l'esito del salvataggio è ignorato, gli errori di scrittura non sono mostrati.
- `ArchiveView.toolbar`: l'esportazione è possibile in qualunque stato con linee, anche durante separazione o rifinitura, quindi su una trascrizione forse incompleta.
- `MarkdownDocument.init(configuration:)` in `Sources/LARP/Archive/MarkdownDocument.swift`: la lettura del documento non è mai usata (codice morto richiesto dal protocollo).
- `EngineTrackPlayer.currentTime`: il tempo è letto solo dalla prima traccia leggibile; se è più corta dell'altra, il tempo dopo la sua fine non è stato determinato.
- `ArchiveView.onDisappear`: chiudere la finestra ferma la riproduzione ma non scarica l'audio né azzera la selezione; non è stato determinato se la selezione sopravvive alla riapertura della finestra.
- Il caricamento dell'audio a fine registrazione avviene su cambio di stato della call osservato dalla vista; modellato come reazione a `recorder.RECORDING_STOPPED`.
