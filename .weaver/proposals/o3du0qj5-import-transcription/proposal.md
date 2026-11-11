---
status: approved
kind: import
requires:
- 5zk696pr
- dtmovkwz
- lf3hvy0v
base:
  model/transcription/call-summary.md: new
  model/transcription/call.md: new
  model/transcription/feature.md: new
  requirements/data/transcription.md: new
  requirements/rules/transcription.md: new
  requirements/tech/transcription.md: new
created: 2026-11-11T12:33:57.218Z
label: Import
job: a8nt702p
---
# Import: Transcription

Importa la Feature `transcription` così come è nel codice: la Machine `call` (dalla registrazione alla trascrizione dall'audio salvato, la separazione dei partecipanti, la rifinitura con omp, la rinomina, il ripristino e l'eliminazione) e la Machine `call-summary` (la sintesi scritta da omp, accanto alla rifinitura). Il fallimento della trascrizione, che il codice non salva, è descritto come sotto-stato di Transcribing, dimenticato al riavvio. Requisiti importati: i dati di chiamate, righe con i loro originali, partecipanti e sintesi (`data`), le regole di titoli e nomi, ordine e ripresa della trascrizione, assegnazione delle voci, richiesta a omp e verifica delle risposte (`rules`), e la struttura tecnica di riconoscimento vocale, separazione delle voci e protocollo con omp (`tech`). Cartelle lette: `Sources/LARP/Call/`, `Sources/LARP/Transcription/`, `Sources/LARP/Separation/`, `Sources/LARP/Refinement/`, `Sources/LARP/Summary/`, `Sources/LARP/Assistant/`, `Sources/LARP/Model/`, con i test in `Tests/LARPTests/`.

## Doubts
- Al lancio `CallLifecycle.appLaunched` (`Sources/LARP/Call/CallLifecycle.swift`) riavvia le rifiniture e le sintesi in corso o in attesa di ripresa senza guardare gli interruttori: una rifinitura o una sintesi spenta mentre l'app era chiusa riparte lo stesso; non è chiaro se sia voluto.
- Una chiamata in Awaiting language aspetta solo la propria lingua e `transcription-language` annuncia la lingua pronta solo per quella scelta ora: se l'utente cambia lingua, la chiamata resta ferma finché la sua lingua non viene scelta di nuovo (`CallLifecycle.languageReady`).
- In `CallLifecycle.delete` il lavoro della chiamata viene fermato prima di cancellarla: se la cancellazione dall'archivio fallisce la chiamata resta nel suo stato senza lavoro in corso (per esempio una chiamata in Transcribing non viene più ritentata fino al lancio successivo) e `apply` riporta comunque Deleted.
- Se la cattura non parte, `recordingStarted` (`Sources/LARP/Call/CallLifecycle+Recording.swift`) cancella la chiamata con `try?`: se la cancellazione fallisce, la chiamata resta in Recording senza registrazione fino al lancio successivo, che la recupera come chiamata vuota.
- Una trascrizione che fallisce sempre viene ritentata ogni 60 secondi senza limite (`scheduleTranscriptionRetry` in `Sources/LARP/Call/CallLifecycle+Transcription.swift`), e l'indicazione del fallimento sparisce al riavvio perché `failedTranscriptions` è solo in memoria; non è chiaro se manchi un limite di tentativi.
- `SummaryEvent.summarizeCall.participantsTold` (`Sources/LARP/Call/CallSummaryStateMachine.swift`) non viene letto da Summarised né da Awaiting summary retry; l'errore `RefinementError.lineWithoutParticipant` è riusato dalla sintesi (`CallLifecycle+Summary.swift`): nomi ingannevoli, comportamento corretto.
