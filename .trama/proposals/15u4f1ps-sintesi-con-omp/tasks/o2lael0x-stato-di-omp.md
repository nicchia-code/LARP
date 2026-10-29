---
technical: false
refs:
  - assistant-status
  - transcript-refinement
  - requirements/tech#assistant-status
---
# Stato di omp condiviso

La verifica di omp esce da `transcript-refinement` ed entra nella nuova Machine `assistant-status`, che vale sia per la rifinitura del testo sia per la sintesi delle chiamate. Oggi la verifica vive in `TranscriptRefinementController` (Settings/TranscriptRefinementController.swift, State `off`/`checking`/`assistantReady`/`assistantMissing`, `turnOn`, `turnOff`, `appLaunched`, `openSettings`, `lookForAssistant`, `check`, `finishCheck`) e va spostata in un controller dedicato allo stato di omp, collegato in App/LARPApp.swift.

`transcript-refinement` si riduce a due State: Off (iniziale), in cui nessuna chiamata viene rifinita, né da sola né su richiesta, e On, in cui le nuove chiamate vengono rifinite da sole dopo la separazione dei partecipanti e l'utente può chiedere di rifinire qualsiasi chiamata pronta. `user.TURN_ON_REFINEMENT` porta a On; `user.TURN_OFF_REFINEMENT` porta a Off, e le chiamate in rifinitura o in attesa di nuovo tentativo tornano pronte con la trascrizione com'era. Nulla di una trascrizione lascia il Mac per la rifinitura mentre la rifinitura è spenta. Il comportamento attuale di spegnimento della rifinitura resta invariato.

`assistant-status` dice se omp è raggiungibile sul Mac, e l'app lo cerca solo mentre la rifinitura, la sintesi o entrambe sono accese:
- Not needed (iniziale): rifinitura e sintesi spente, omp non viene cercato. `user.TURN_ON_REFINEMENT` o `user.TURN_ON_SUMMARY` portano a Needed.
- Needed: `user.TURN_OFF_REFINEMENT` porta a Not needed solo se la sintesi è spenta; `user.TURN_OFF_SUMMARY` porta a Not needed solo se la rifinitura è spenta. `macos.APP_LAUNCHED` e `user.OPEN_SETTINGS` portano a Checking, cercando di nuovo omp.
  - Checking (iniziale di Needed): l'app cerca omp e gli chiede di rispondere; `assistant.REACHED` porta ad Assistant ready, `assistant.UNREACHABLE` ad Assistant missing.
  - Assistant ready: omp trovato e risponde.
  - Assistant missing: omp non trovato o non risponde; le chiamate vengono comunque mandate a rifinitura e sintesi, che falliscono e vengono ritentate più tardi.

Lo stato acceso/spento della sintesi arriva dall'interruttore `call-summaries` (altro Task); questo controller deve leggerlo per decidere fra Needed e Not needed, all'avvio e a ogni accensione/spegnimento.

Requisiti tecnici, invariati rispetto a oggi ma ora validi per verifica, rifinitura e sintesi (Assistant/Omp.swift `OmpAssistantCheck`, `Omp.open`, `Omp.withWorkingDirectory`; Assistant/OmpLocator.swift `LoginShellOmpLocator`; Assistant/ACPClient.swift `ACPClient`):
- omp viene cercato a ogni verifica, ogni rifinitura e ogni sintesi tramite la shell di login dell'utente (`$SHELL -l -c 'command -v omp'`), perché le app aperte dal Finder non ricevono il `PATH` della shell.
- omp viene avviato con `Foundation.Process` come `omp acp`, con gli strumenti integrati disattivati e senza sessione salvata quando omp accetta le opzioni (`--no-tools`, `--no-session`), in una nuova cartella temporanea vuota usata come cartella di lavoro e cancellata dopo.
- L'Agent Client Protocol (JSON-RPC 2.0, un messaggio per riga su standard input e output) è parlato direttamente dall'app, senza nuove dipendenze.
- L'app non dichiara capacità di file system né di terminale in `initialize`, rifiuta ogni `session/request_permission`, usa le credenziali già configurate in omp e non sceglie mai un modello.
- La verifica avvia omp, invia `initialize` e termina il processo: una risposta entro 10 secondi significa omp raggiunto; omp non trovato, un errore o nessuna risposta in tempo significano non raggiungibile.

Fatto quando: i test (oggi Tests/LARPTests/TranscriptRefinementTests.swift) coprono le transizioni di `assistant-status` con le due combinazioni di interruttori, e `transcript-refinement` non contiene più la verifica.
